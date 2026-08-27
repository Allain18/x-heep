// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// DMA-fed pixel stream display test.
//
// There is no real camera hooked up yet, and deliberately no frame buffer in
// the HDMI peripheral either: the final design is meant to stream camera
// pixels through the PIXEL register window (see hdmi_pixel_stream.sv), most
// likely via DMA. This app stands in for the camera with a fixed 40x30 test
// image (white border, green marker block near the top-left corner,
// gradient fill) and pushes it into that same window using the DMA, so the
// DMA-to-HDMI path gets exercised now and the camera can slot in later
// without changing how the picture reaches the screen.
//
// hdmi_pixel_stream.sv holds only a shallow FIFO, not a full frame: the
// picture would start showing stale pixels within one frame if pushed only
// once, so this app keeps re-launching the same DMA transfer forever. Each
// transfer stalls on the window's backpressure until hdmi_pixel_stream.sv
// has drained room for more, which happens to pace the loop to roughly the
// HDMI frame rate without an explicit vsync wait.

#include <stdint.h>
#include <stdio.h>

#include "dma.h"
#include "hdmi_regs.h"
#include "hdmi_structs.h"
#include "x-heep.h"

#ifndef HDMI_IS_INCLUDED
#error ("This app does NOT work as the HDMI peripheral is not included")
#endif

#define HDMI_PATTERN_STREAM 4

#define IMG_COLS 40
#define IMG_ROWS 30
#define IMG_PIXELS (IMG_COLS * IMG_ROWS)

// One 0x00RRGGBB word per pixel: matches what hdmi_pixel_stream.sv expects
// through the PIXEL window, and the layout the COLOR register already uses.
static uint32_t array_small_image[IMG_PIXELS] __attribute__((aligned(4)));

static void fill_test_image(void) {
  for (unsigned row = 0; row < IMG_ROWS; row++) {
    for (unsigned col = 0; col < IMG_COLS; col++) {
      uint8_t r, g, b;
      int border = (row == 0) || (row == IMG_ROWS - 1) || (col == 0) ||
                   (col == IMG_COLS - 1);
      int marker = (row >= 2) && (row < 6) && (col >= 2) && (col < 6);

      if (border) {
        r = g = b = 0xFF;
      } else if (marker) {
        r = 0x00;
        g = 0xFF;
        b = 0x00;
      } else {
        r = col * (256 / IMG_COLS);
        g = row * (256 / IMG_ROWS);
        b = 0x80;
      }

      array_small_image[row * IMG_COLS + col] =
          ((uint32_t)r << 16) | ((uint32_t)g << 8) | b;
    }
  }
}

int main(void) {
  printf("=== HDMI DMA pixel stream test ===\n");
  printf("40x30 test image, re-pushed through DMA every frame\n");

  fill_test_image();

  hdmi_peri->CTRL = (1 << HDMI_CTRL_EN_BIT) |
                    (HDMI_PATTERN_STREAM << HDMI_CTRL_PATTERN_OFFSET);

  dma_init(NULL);

  static dma_target_t tgt_src = {
      .ptr       = (uint8_t *)array_small_image,
      .inc_d1_du = 1,
      .trig      = DMA_TRIG_MEMORY,
      .type      = DMA_DATA_TYPE_WORD,
  };
  static dma_target_t tgt_dst = {
      .ptr       = (uint8_t *)&hdmi_peri->PIXEL,
      .inc_d1_du = 0,  // fixed address: every word pushes into the same FIFO
      .trig      = DMA_TRIG_MEMORY,
  };
  static dma_trans_t trans = {
      .src        = &tgt_src,
      .dst        = &tgt_dst,
      .size_d1_du = IMG_PIXELS,
      .mode       = DMA_TRANS_MODE_SINGLE,
      .win_du     = 0,
      .end        = DMA_TRANS_END_POLLING,
  };

  // Returning lets the runtime stop the core, and any reset after that
  // clears CTRL and blanks the screen, so this loops forever instead.
  for (;;) {
    dma_validate_transaction(&trans, DMA_ENABLE_REALIGN, DMA_PERFORM_CHECKS_INTEGRITY);
    dma_load_transaction(&trans);
    dma_launch(&trans);
    while (!dma_is_ready(0));
  }
}
