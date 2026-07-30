

`define RGB565 3'b000
`define RGB555 3'b001
`define RGB444 3'b010
`define BYPASS_LITEND 3'b100
`define BYPASS_BIGEND 3'b101
`define BYPASS_10BITS 3'b110

module camera_if #(
    // Register Interface data types
    parameter type reg_req_t = logic,
    parameter type reg_rsp_t = logic
) (
    input logic clk_i,
    input logic rst_ni,

    // Register interface from system bus
    input  reg_req_t reg_req_i,
    output reg_rsp_t reg_rsp_o,

    // Input from camera
    input logic       cam_pclk_i,
    input logic       cam_hsync_i,
    input logic       cam_vsync_i,
    input logic [7:0] cam_data_i
);

  // ============== PACKAGE IMPORTS ==============
  import camera_reg_pkg::*;

  // ============== REGISTER SIGNALS ==============
  camera_reg2hw_t reg2hw;
  camera_hw2reg_t hw2reg;

  reg_req_t fifo_win_h2d;
  reg_rsp_t fifo_win_d2h;

  // ============== OTHER SIGNALS ==============

  assign hw2reg.status.de = 1;
  always @(cam_vsync_i) begin
    hw2reg.status.d = ~cam_vsync_i;
  end


  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin

    end else begin

    end
  end

  camera_window #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) camera_window_i (
      .win_i  (fifo_win_h2d),
      .win_o  (fifo_win_d2h),
      .data_i (32'hA9),
      .ready_o()
  );

  // ------------------------- Registers
  camera_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_rsp_t)
  ) camera_reg_top_i (
      .clk_i,
      .rst_ni,
      .reg2hw,
      .hw2reg,
      .reg_req_i,
      .reg_rsp_o,
      .reg_req_win_o(fifo_win_h2d),
      .reg_rsp_win_i(fifo_win_d2h),
      .devmode_i(1'b0)
  );

endmodule  // camera_if
