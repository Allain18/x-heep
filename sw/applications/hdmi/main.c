// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// HDMI output smoke test.
//
// Checks that the pixel clock is actually running by watching the frame
// counter, then walks through the built-in test patterns so there is something
// to look at on the monitor.

#include <stdint.h>
#include <stdio.h>

#include "hdmi_regs.h"
#include "hdmi_structs.h"
#include "soc_ctrl.h"
#include "timer_sdk.h"
#include "x-heep.h"

#ifndef HDMI_IS_INCLUDED
#error ("This app does NOT work as the HDMI peripheral is not included")
#endif

/* By default, PRINTFs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA 1
#define PRINTF_IN_SIM 1

#if TARGET_SIM && PRINTF_IN_SIM
#define PRINTF(fmt, ...) printf(fmt, ##__VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
#define PRINTF(fmt, ...) printf(fmt, ##__VA_ARGS__)
#else
#define PRINTF(...)
#endif

#define HDMI_PATTERN_BARS 0
#define HDMI_PATTERN_XOR 1
#define HDMI_PATTERN_CHECKER 2
#define HDMI_PATTERN_SOLID 3

static void hdmi_set_pattern(uint32_t pattern) {
  hdmi_peri->CTRL =
      (1 << HDMI_CTRL_EN_BIT) |
      ((pattern & HDMI_CTRL_PATTERN_MASK) << HDMI_CTRL_PATTERN_OFFSET);
}

static void hdmi_set_solid(uint32_t rgb) {
  hdmi_peri->COLOR = rgb & HDMI_COLOR_RGB_MASK;
  hdmi_set_pattern(HDMI_PATTERN_SOLID);
}

// Busy-waits on the cycle counter rather than using timer_wait_us, which parks
// the core in wfi and would need the timer interrupt wired up.
static void wait_cycles(uint32_t cycles) {
  uint32_t start = timer_get_cycles();
  while ((timer_get_cycles() - start) < cycles);
}

int main(void) {
  soc_ctrl_t soc_ctrl;
  soc_ctrl.base_addr = mmio_region_from_addr((uintptr_t)SOC_CTRL_START_ADDRESS);
  uint32_t freq_hz = soc_ctrl_get_frequency(&soc_ctrl);

  timer_cycles_init();
  timer_start();

  PRINTF("=== HDMI Test ===\n");
  PRINTF("system clock: %u Hz\n", freq_hz);

  // The frame counter lives in the bus clock domain but only advances on
  // vertical sync coming from the pixel domain. If it never moves, the pixel
  // clock is dead and nothing else is worth debugging.
#if TARGET_SIM
  // In simulation the pixel clock is tied to the bus clock, so a whole frame is
  // 800*525 cycles. Wait for a couple of them rather than for real time.
  uint32_t measure_cycles = 2 * 800 * 525;
#else
  uint32_t measure_cycles = freq_hz / 2;  // half a second
#endif

  PRINTF("Number of cycles to measure: %u\n", measure_cycles);
  uint32_t frames_before = hdmi_peri->FRAME_CNT;
  wait_cycles(measure_cycles);
  uint32_t frames_after = hdmi_peri->FRAME_CNT;
  uint32_t frames = frames_after - frames_before;

  PRINTF("frames in %u cycles: %u\n", measure_cycles, frames);

  if (frames == 0) {
    PRINTF("[ERROR] frame counter is stuck: no pixel clock\n");
    return -1;
  }

#if !TARGET_SIM
  // measure_cycles is half a second, so twice the count is the refresh rate.
  PRINTF("refresh: ~%u Hz (expect ~59)\n", frames * 2);
#endif

  PRINTF("colour bars\n");
  hdmi_set_pattern(HDMI_PATTERN_BARS);
  wait_cycles(measure_cycles);

  PRINTF("xor texture\n");
  hdmi_set_pattern(HDMI_PATTERN_XOR);
  wait_cycles(measure_cycles);

  PRINTF("checkerboard with border\n");
  hdmi_set_pattern(HDMI_PATTERN_CHECKER);
  wait_cycles(measure_cycles);

  PRINTF("solid red, green, blue\n");
  hdmi_set_solid(0xFF0000);
  wait_cycles(measure_cycles);
  hdmi_set_solid(0x00FF00);
  wait_cycles(measure_cycles);
  hdmi_set_solid(0x0000FF);
  wait_cycles(measure_cycles);

  // Leave something recognisable on screen.
  hdmi_set_pattern(HDMI_PATTERN_BARS);

  PRINTF("=== Test finished ===\n");
  return 0;
}
