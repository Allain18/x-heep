module cache_way
  import cache_reg_pkg::*;
(
  input  logic       clk_i,
  input  logic       rst_ni,

  input  cache_req_t request_i,
  output cache_res_t response_o,
);

  logic [N_SETS-1:0]                  valid_q, valid_d;
  logic [N_SETS-1:0]                  dirty_q, dirty_d;
  logic [TAG_WIDTH-1:0]               tags_q [N_SETS-1:0], tags_d [N_SETS-1:0];

  logic [N_SETS_WIDTH-1:0]            current_set;
  logic [TAG_WIDTH-1:0]               current_tag;
  logic [SECTOR_SIZE_WORDS_WIDTH-1:0] word_offset;

  logic                               hit;

  assign current_set = request_i.addr.internal.set;
  assign current_tag = request_i.addr.internal.tag;
  assign word_offset = request_i.addr.internal.byte_offset[SECTOR_SIZE_BYTES_WIDTH-1:2];

  assign hit = valid_bits[current_set] & (tags[current_set] == current_tag);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      valid_q <= 'h0;
      dirty_q <= 'h0;

      for (int i = 0; i < N_SETS; i++) tags_q[i] <= 'h0;
    end else begin
      valid_q <= valid_d;
      dirty_q <= valid_d;

      for (int i = 0; i < N_SETS; i++) tags_q[i] <= tags_d[i];
    end
  end

  always_comb begin

  end

  tc_sram #(
    .NumWords (N_SETS * SECTOR_SIZE_WORDS),
    .DataWidth(WORD_SIZE_BITS),
    .ByteWidth(32'd8),
    .NumPorts (32'd1),
    .Latency (32'd1)
  ) tc_ram_i (
    .clk_i  (clk_i),
    .rst_ni (rst_ni),
    .req_i  (mem_req),
    .we_i   (mem_we),
    .addr_i (mem_addr),
    .wdata_i(mem_wdata),
    .be_i   (mem_be),
    // output ports
    .rdata_o(rdata_o)
  );

  assign response_o.hit = hit;
  assign response_o.miss_info.dirty = dirty;
  assign response_o.miss_info.victim_sector = {tags[prev_set], prev_set};

  assign data_o = data[current_set];

endmodule
