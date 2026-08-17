// Copyright 2026 EPFL
// Solderpad Hardware License, Version 2.1, see LICENSE.md for details.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1

// HDMI / DVI-D transmitter front end.
//
// Two clock domains meet here:
//   - clk_i  is the system bus clock (15 MHz on the Pynq-Z2), used by the
//     register file;
//   - pclk_i is the pixel clock (25 MHz for 640x480@60), used by the whole video
//     path.
//
// The module hands out three 10-bit TMDS words per pixel. Turning those into
// four serial pairs needs device-specific primitives (OSERDESE2 on 7-series), so
// that part lives in the FPGA wrapper and stays out of this portable RTL.
//
// Note on what is *not* here yet: the pixel source is a test pattern generator.
// A framebuffer fed by the DMA plugs into the same place, replacing hdmi_pattern
// as the source of {red, green, blue}.

module hdmi_if #(
    // Register interface data types
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic,

    // Video timing, 640x480@60 by default
    parameter int unsigned HActive  = 640,
    parameter int unsigned HFront   = 16,
    parameter int unsigned HSyncLen = 96,
    parameter int unsigned HBack    = 48,

    parameter int unsigned VActive  = 480,
    parameter int unsigned VFront   = 10,
    parameter int unsigned VSyncLen = 2,
    parameter int unsigned VBack    = 33
) (
    input logic clk_i,
    input logic rst_ni,

    // Register interface from the system bus
    input  reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,

    // Pixel clock domain
    input logic pclk_i,

    // TMDS words, transmitted LSB first. Channel 0 also carries the syncs.
    output logic [9:0] tmds_ch0_o,  // blue  + {vsync, hsync}
    output logic [9:0] tmds_ch1_o,  // green
    output logic [9:0] tmds_ch2_o   // red
);

  import hdmi_reg_pkg::*;

  localparam int unsigned CfgWidth = 27;  // {color[23:0], pattern[1:0], en}

  hdmi_reg2hw_t       reg2hw;
  hdmi_hw2reg_t       hw2reg;

  // ============================================================ pixel domain reset
  // rst_ni is asynchronous to pclk_i. Releasing it through two flops keeps the
  // video counters from starting out of step with each other.
  logic         [1:0] pclk_rst_sync;
  logic               pclk_rst_n;

  always_ff @(posedge pclk_i or negedge rst_ni) begin
    if (!rst_ni) pclk_rst_sync <= 2'b00;
    else pclk_rst_sync <= {pclk_rst_sync[0], 1'b1};
  end

  assign pclk_rst_n = pclk_rst_sync[1];

  // ============================================================ configuration CDC
  logic [CfgWidth-1:0] cfg_bus;
  logic [CfgWidth-1:0] cfg_sync;
  logic [CfgWidth-1:0] cfg_pix;

  assign cfg_bus = {reg2hw.color.q, reg2hw.ctrl.pattern.q, reg2hw.ctrl.en.q};

  for (genvar i = 0; i < CfgWidth; i++) begin : gen_cfg_sync
    sync #(
        .STAGES(2)
    ) cfg_sync_i (
        .clk_i   (pclk_i),
        .rst_ni  (pclk_rst_n),
        .serial_i(cfg_bus[i]),
        .serial_o(cfg_sync[i])
    );
  end

  logic        pix_de;
  logic        pix_hsync;
  logic        pix_vsync;
  logic [11:0] pix_hpos;
  logic [11:0] pix_vpos;

  // The synchronisers settle each bit independently, so the bundle is only
  // sampled during vertical sync. A write that lands mid-frame therefore takes
  // effect at the next frame boundary instead of tearing the visible image.
  always_ff @(posedge pclk_i or negedge pclk_rst_n) begin
    if (!pclk_rst_n) cfg_pix <= '0;
    else if (pix_vsync) cfg_pix <= cfg_sync;
  end

  logic        cfg_en;
  logic [ 1:0] cfg_pattern;
  logic [23:0] cfg_color;

  assign cfg_en      = cfg_pix[0];
  assign cfg_pattern = cfg_pix[2:1];
  assign cfg_color   = cfg_pix[26:3];

  // ============================================================ video timing
  hdmi_timing #(
      .HActive (HActive),
      .HFront  (HFront),
      .HSyncLen(HSyncLen),
      .HBack   (HBack),
      .VActive (VActive),
      .VFront  (VFront),
      .VSyncLen(VSyncLen),
      .VBack   (VBack)
  ) hdmi_timing_i (
      .clk_i  (pclk_i),
      .rst_ni (pclk_rst_n),
      .hpos_o (pix_hpos),
      .vpos_o (pix_vpos),
      .de_o   (pix_de),
      .hsync_o(pix_hsync),
      .vsync_o(pix_vsync)
  );

  // ============================================================ pixel source
  logic [7:0] pat_r, pat_g, pat_b;
  logic [7:0] pix_r, pix_g, pix_b;

  hdmi_pattern #(
      .HActive(HActive),
      .VActive(VActive)
  ) hdmi_pattern_i (
      .hpos_i   (pix_hpos),
      .vpos_i   (pix_vpos),
      .pattern_i(cfg_pattern),
      .color_i  (cfg_color),
      .red_o    (pat_r),
      .green_o  (pat_g),
      .blue_o   (pat_b)
  );

  // Disabling the output blacks out the picture but leaves the timing running,
  // so the monitor keeps its lock instead of dropping the mode.
  assign pix_r = cfg_en ? pat_r : 8'h00;
  assign pix_g = cfg_en ? pat_g : 8'h00;
  assign pix_b = cfg_en ? pat_b : 8'h00;

  // ============================================================ TMDS encoding
  // Channel 0 carries blue plus the two sync signals; the other two channels
  // send null control tokens during blanking.
  hdmi_tmds_encoder hdmi_tmds_ch0_i (
      .clk_i (pclk_i),
      .rst_ni(pclk_rst_n),
      .data_i(pix_b),
      .ctrl_i({pix_vsync, pix_hsync}),
      .de_i  (pix_de),
      .tmds_o(tmds_ch0_o)
  );

  hdmi_tmds_encoder hdmi_tmds_ch1_i (
      .clk_i (pclk_i),
      .rst_ni(pclk_rst_n),
      .data_i(pix_g),
      .ctrl_i(2'b00),
      .de_i  (pix_de),
      .tmds_o(tmds_ch1_o)
  );

  hdmi_tmds_encoder hdmi_tmds_ch2_i (
      .clk_i (pclk_i),
      .rst_ni(pclk_rst_n),
      .data_i(pix_r),
      .ctrl_i(2'b00),
      .de_i  (pix_de),
      .tmds_o(tmds_ch2_o)
  );

  // ============================================================ status readback
  logic        vsync_bus;
  logic        vsync_bus_q;
  logic [31:0] frame_cnt;

  sync #(
      .STAGES(2)
  ) vsync_sync_i (
      .clk_i,
      .rst_ni,
      .serial_i(pix_vsync),
      .serial_o(vsync_bus)
  );

  // Vertical sync lasts two lines, 64 us at 25 MHz, so the bus clock cannot miss
  // it. Counting here rather than in the pixel domain keeps the 32-bit counter
  // out of the crossing entirely.
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      vsync_bus_q <= 1'b0;
      frame_cnt   <= '0;
    end else begin
      vsync_bus_q <= vsync_bus;
      if (vsync_bus && !vsync_bus_q) frame_cnt <= frame_cnt + 32'd1;
    end
  end

  assign hw2reg.status.d     = vsync_bus;
  assign hw2reg.status.de    = 1'b1;
  assign hw2reg.frame_cnt.d  = frame_cnt;
  assign hw2reg.frame_cnt.de = 1'b1;

  // ============================================================ registers
  hdmi_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) hdmi_reg_top_i (
      .clk_i,
      .rst_ni,
      .reg2hw,
      .hw2reg,
      .reg_req_i,
      .reg_rsp_o,
      .devmode_i(1'b0)
  );

endmodule  // hdmi_if
