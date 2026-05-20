/**
 * SRAM bank instantiation heavily inspired by:
 *   "hw/vendor/pulp_platform/tech_cells_generic/src/fpga/tc_sram_xilinx.sv"
 *   "hw/ip_examples/slow_memory/rtl/slow_memory.sv"
 */

module cache
  import cache_reg_pkg::*;
  import obi_pkg::*;
#(
  parameter int unsigned NumWords  = N_SETS * SECTOR_SIZE_WORDS,
  parameter int unsigned DataWidth = WORD_SIZE_BITS,
  parameter int unsigned ByteWidth = BYTE_SIZE_BITS,

  // DEPENDENT PARAMETERS, DO NOT OVERWRITE!
  parameter int unsigned AddrWidth = (NumWords > 32'd1) ? $clog2(NumWords) : 32'd1,
  parameter int unsigned BeWidth   = (DataWidth + ByteWidth - 32'd1) / ByteWidth, // ceil_div
  parameter type         addr_t    = logic [AddrWidth-1:0],
  parameter type         data_t    = logic [DataWidth-1:0],
  parameter type         be_t      = logic [BeWidth-1:0]
) (
  input  logic           clk_i,
  input  logic           rst_ni,

  // DMA (SLAVE) communication
  input  obi_req_t       dma_req_i,
  output obi_req_t       dma_resp_o,

  // Controller (MASTER) communication
  input  cache_req_t     controller_req_i,
  output cache_res_t     controller_resp_o
);

  // Currently implements single way cache (direct-mapped) only

  logic [N_SETS_WIDTH-1:0]            req_tag;
  logic [N_SETS_WIDTH-1:0]            req_set;
  logic [SECTOR_SIZE_WORDS_WIDTH-1:0] req_word_off;
  logic                               last_sector_word;

  cache_op_e                          active_op_q, active_op_d;
  logic [SECTOR_SIZE_WORDS_WIDTH-1:0] word_counter_q, word_counter_d;

  // Cache way(s) signals
  logic  hit;
  logic  dirty;
  logic [SECTOR_ADDRESS_WIDTH-1:0] victim_sector;

  // SRAM Port signals
  logic  mem_req,   mem_req_q,   mem_req_d;
  logic  mem_we,    mem_we_q,    mem_we_d;
  addr_t mem_addr,  mem_addr_q,  mem_addr_d;
  data_t mem_wdata, mem_wdata_q, mem_wdata_d;
  be_t   mem_be,    mem_be_q,    mem_be_d;
  data_t mem_rdata;

  assign req_tag      = controller_req_i.addr.internal.tag;
  assign req_set      = controller_req_i.addr.internal.set;
  assign req_word_off = controller_req_i.addr.internal.byte_offset[SECTOR_SIZE_BYTES_WIDTH-1:2];
  assign last_sector_word = word_counter_q == SECTOR_SIZE_WORDS_WIDTH'(SECTOR_SIZE_WORDS - 1);

  // Pointer update
  always_ff @(posedege clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      active_op_q    <= CACHE_IDLE;
      word_counter_q <= SECTOR_SIZE_WORDS_WIDTH'h0;
    end else begin
      active_op_q    <= active_op_d;
      word_counter_q <= word_counter_d;
    end
  end

  always_comb begin
    word_counter_d = word_counter_q;

    if (controller_req_i.req) begin
      active_op_d = controller_req_i.op;
    end

    if (dma.done) begin
      word_counter_d = word_counter_q + 1'b1;
    end
  end

  // SRAM Accesses
  always_comb begin
    mem_req = 1'b0;
    mem_we = 1'b0;

    if (controller_req_i.req) begin
      unique case (controller_req_i.op)
        CACHE_READ: begin
          if (hit) begin
            mem_req = 1'b1;
            mem_we  = 1'b0;
            mem_addr = {req_tag, req_set, req_word_off};
            mem_be = controller_req_i.be;
          end
        end

        CACHE_WRITE: begin
          if (hit) begin
            mem_req = 1'b1;
            mem_we  = 1'b1;
            mem_addr = {req_tag, req_set, req_word_off};
            mem_wdata = controller_req_i.wdata;
            mem_be = controller_req_i.be;
          end
        end

        CACHE_FILL: begin
          mem_req = 1'b1;
          mem_we  = 1'b1;
          mem_addr = {req_tag, req_set, word_counter_d};
          mem_wdata = controller_req_i.wdata;
          mem_be  = 4'b1111;
        end

        CACHE_EVICT: begin
          mem_req = 1'b1;
          mem_we  = 1'b0;
          mem_addr = {req_tag, req_set, word_counter_d};
          mem_wdata = controller_req_i.wdata;
          mem_be  = 4'b1111;
        end

        default: ;
      endcase
    end
  end

  cache_way way (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    .request_i(controller_req_i),
    .last_sector_word_i(last_sector_word),

    .hit_o(hit),
    .dirty_o(dirty),
    .victim_sector_o(victim_sector)
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

  // Output assignments

  // DMA response

  // Controller response
  assign controller_resp_o.hit = hit;

  assign controller_resp_o.miss_info.dirty = dirty;
  assign controller_resp_o.miss_info.victim_sector_address = victim_sector;

endmodule
