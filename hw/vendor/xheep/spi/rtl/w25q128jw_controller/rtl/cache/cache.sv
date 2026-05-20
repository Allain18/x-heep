/**
 * SRAM bank instantiation heavily inspired by:
 *   "hw/vendor/pulp_platform/tech_cells_generic/src/fpga/tc_sram_xilinx.sv"
 *   "hw/ip_examples/slow_memory/rtl/slow_memory.sv"
 */

module cache
  import cache_reg_pkg::*;
#(
  parameter int unsigned NumWords     = N_SETS * SECTOR_SIZE_WORDS,
  parameter int unsigned DataWidth    = WORD_SIZE_BITS,
  parameter int unsigned ByteWidth    = BYTE_SIZE_BITS,

  // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
  parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1,
  parameter int unsigned BeWidth   = (DataWidth + ByteWidth - 32'd1) / ByteWidth, // ceil_div
  parameter type         addr_t    = logic [AddrWidth-1:0],
  parameter type         data_t    = logic [DataWidth-1:0],
  parameter type         be_t      = logic [BeWidth-1:0]
) (
  input logic clk_i,
  input logic rst_ni,

  input cache_req_t request_i,

  output cache_res_t response_o
);

  // Currently implements single way cache (direct-mapped) only

  logic [N_SETS_WIDTH-1:0] current_set;
  logic [SECTOR_SIZE_WORDS_WIDTH-1:0] word_offset;

  assign current_set = request_i.addr.internal.set;
  assign word_offset = request_i.addr.internal.byte_offset[SECTOR_SIZE_BYTES_WIDTH-1:2];

  logic  mem_req,   mem_req_q,   mem_req_d;
  logic  mem_we,    mem_we_q,    mem_we_d;
  addr_t mem_addr,  mem_addr_q,  mem_addr_d;
  data_t mem_wdata, mem_wdata_q, mem_wdata_d;
  be_t   mem_be,    mem_be_q,    mem_be_d;
  data_t mem_rdata;

  // SRAM Port
  always_comb begin
    mem_req = 1'b0;
    mem_we = 1'b0;

    mem_addr = {current_set, word_offset};
    mem_wdata = request_i.wdata;
    mem_be = request_i.be;

    unique case (request_i.op)
      CACHE_READ: begin
        if (hit) begin
          mem_req = 1'b1;
          mem_we  = 1'b0;
        end
      end

      CACHE_WRITE: begin
        if (hit) begin
          mem_req = 1'b1;
          mem_we  = 1'b1;
        end
      end

      CACHE_FILL: begin
        mem_req = 1'b1;
        mem_we  = 1'b1;
        mem_be  = 4'b1111;
      end

      default: ;
    endcase
  end

  cache_way way (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    .request_i(request_i),
    .response_o(response_o)
  );

  tc_sram #(
    .NumWords (NumWords),       // Number of Words in data array
    .DataWidth(DataWidth),      // Data signal width (in bits)
    .ByteWidth(ByteWidth),      // Width of a data byte (in bits)
    .NumPorts (N_WAYS),         // Number of read and write ports
    .Latency  (32'd1)           // Latency when the read data is available
  ) cache_data (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    .req_i  (mem_req),
    .we_i   (mem_we),
    .addr_i (mem_addr),
    .wdata_i(mem_wdata),
    .be_i   (mem_be),
    // output ports
    .rdata_o(mem_rdata)
  );

  assign response_o.hit = hit;
  assign response_o.rdata = TODO;
  assign response_o.rvalid = TODO;

  assign response_o.miss_info.dirty = dirty;
  assign response_o.miss_info.victim_sector_address = SECTOR_ADDRESS_WIDTH'({tags[current_set], current_set});

endmodule
