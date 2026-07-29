

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
      .devmode_i(1'b0)
  );

endmodule  // camera_if
