/**
 * SRAM bank instantiation heavily inspired by:
 *   "hw/vendor/pulp_platform/tech_cells_generic/src/fpga/tc_sram_xilinx.sv"
 *   "hw/ip_examples/slow_memory/rtl/slow_memory.sv"
 */

module cache
  import cache_reg_pkg::*;
  import obi_pkg::*;
#(
  parameter int unsigned SramLatency = 32'd1
) (
  input  logic           clk_i,
  input  logic           rst_ni,

  // DMA (SLAVE) communication
  input  obi_req_t       dma_req_i,
  output obi_resp_t      dma_resp_o,

  // Controller (MASTER) communication
  input  cache_req_t     controller_req_i,
  output cache_res_t     controller_resp_o
);

  // Currently implements single way cache (direct-mapped) only

  localparam int unsigned SramAddrWidth = $clog2(N_WORDS);

  logic [TAG_WIDTH-1:0]               req_tag;
  logic [N_SETS_WIDTH-1:0]            req_set;
  logic [SECTOR_SIZE_WORDS_WIDTH-1:0] req_word_off;
  logic                               last_sector_word;

  cache_op_e                          active_op_q, active_op_d;
  logic [SECTOR_SIZE_WORDS_WIDTH-1:0] word_counter_q, word_counter_d;

  // Sector address registered at start of FILL/EVICT
  logic [N_SETS_WIDTH-1:0]  target_set_q, target_set_d;
  logic [TAG_WIDTH-1:0]     target_tag_q, target_tag_d;

  // Cache way(s) signals
  logic  hit;
  logic  dirty;
  logic [SECTOR_ADDRESS_WIDTH-1:0] victim_sector;

  // SRAM Port signals
  logic                        mem_req;
  logic                        mem_we;
  logic [SramAddrWidth-1:0]    mem_addr;
  data_t                       mem_wdata;
  be_t                         mem_be;
  data_t                       mem_rdata;

  logic                   gnt;
  logic [SramLatency-1:0] rvalid;

  assign req_tag      = controller_req_i.addr.internal.tag;
  assign req_set      = controller_req_i.addr.internal.set;
  assign req_word_off = controller_req_i.addr.internal.byte_offset[SECTOR_SIZE_BYTES_WIDTH-1:2];

  // FSM state, word counter, and target sector address
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      active_op_q    <= CACHE_IDLE;
      word_counter_q <= '0;
      target_set_q   <= '0;
      target_tag_q   <= '0;
    end else begin
      active_op_q    <= active_op_d;
      word_counter_q <= word_counter_d;
      target_set_q   <= target_set_d;
      target_tag_q   <= target_tag_d;
    end
  end

  always_comb begin
    active_op_d    = active_op_q;
    word_counter_d = word_counter_q;
    target_set_d   = target_set_q;
    target_tag_d   = target_tag_q;

    last_sector_word = (word_counter_q == SECTOR_SIZE_WORDS_WIDTH'(SECTOR_SIZE_WORDS - 1));

    if (controller_req_i.req) begin
      active_op_d    = controller_req_i.op;
      target_set_d   = controller_req_i.addr.internal.set;
      target_tag_d   = controller_req_i.addr.internal.tag;
      word_counter_d = '0;
    end else begin
      unique case (active_op_q)
        CACHE_FILL, CACHE_EVICT: begin
          if (dma_req_i.req) begin
            word_counter_d = word_counter_q + 1'b1;

            if (last_sector_word) begin
              active_op_d = CACHE_IDLE;
            end
          end
        end

        default: ;
      endcase
    end
  end

  // SRAM Accesses
  always_comb begin
    mem_req   = 1'b0;
    mem_we    = 1'b0;
    mem_addr  = '0;
    mem_wdata = '0;
    mem_be    = '0;

    if (controller_req_i.req) begin
      unique case (controller_req_i.op)
        CACHE_READ: begin
          if (hit) begin
            mem_req  = 1'b1;
            mem_addr = SramAddrWidth'({req_set, req_word_off});
            mem_be   = controller_req_i.be;
          end
        end

        CACHE_WRITE: begin
          if (hit) begin
            mem_req   = 1'b1;
            mem_we    = 1'b1;
            mem_addr  = SramAddrWidth'({req_set, req_word_off});
            mem_wdata = controller_req_i.wdata;
            mem_be    = controller_req_i.be;
          end
        end

        default: ;
      endcase

    end else if (dma_req_i.req) begin
      // Multi-cycle fill/evict streaming driven by DMA
      unique case (active_op_q)
        CACHE_FILL: begin
          mem_req   = 1'b1;
          mem_we    = 1'b1;
          mem_addr  = SramAddrWidth'({target_set_q, word_counter_q});
          mem_wdata = dma_req_i.wdata;
          mem_be    = 4'b1111;
        end

        CACHE_EVICT: begin
          mem_req  = 1'b1;
          mem_we   = 1'b0;
          mem_addr = SramAddrWidth'({target_set_q, word_counter_q});
          mem_be   = 4'b1111;
        end

        default: ;
      endcase
    end
  end

  // SRAM valid signal
  assign gnt = dma_req_i.req;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      rvalid <= '0;
    end else begin
      rvalid <= (rvalid << 1) | SramLatency'(gnt);
    end
  end

  // Cache way metadata
  cache_way way (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    .request_i(controller_req_i),
    .last_sector_word_i(last_sector_word),

    .hit_o(hit),
    .dirty_o(dirty),
    .victim_sector_o(victim_sector)
  );

  // Cache data (SRAM bank)
  tc_sram #(
    .NumWords (N_WORDS),        // Number of Words in data array
    .DataWidth(WORD_SIZE_BITS), // Data signal width (in bits)
    .ByteWidth(BYTE_SIZE_BITS), // Width of a data byte (in bits)
    .NumPorts (N_WAYS),         // Number of read and write ports
    .Latency  (SramLatency)     // Latency when the read data is available
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
  assign dma_resp_o.gnt    = gnt;
  assign dma_resp_o.rvalid = rvalid[SramLatency-1];
  assign dma_resp_o.rdata  = mem_rdata;

  // Controller response
  assign controller_resp_o.hit = hit;

  assign controller_resp_o.miss_info.dirty = dirty;
  assign controller_resp_o.miss_info.victim_sector_address = victim_sector;

endmodule
