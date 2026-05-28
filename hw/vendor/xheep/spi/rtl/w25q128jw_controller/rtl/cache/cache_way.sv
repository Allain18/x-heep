/**
 * This module contains the metadata for each of the cache ways.
 * It is used to check a hit/miss, if the line is dirty and which line to replace
 * if needed.
 *
 * The cache data lives in `cache.sv`.
 */

module cache_way
  import cache_reg_pkg::*;
(
  input  logic                            clk_i,
  input  logic                            rst_ni,

  input  cache_req_t                      request_i,
  input  logic                            last_sector_word_i,

  output logic                            hit_o,
  output logic                            dirty_o,
  output logic [SECTOR_ADDRESS_WIDTH-1:0] victim_sector_o // Only defined in case of miss
);

  logic [N_SETS-1:0]                  valid_q, valid_d;
  logic [N_SETS-1:0]                  dirty_q, dirty_d;
  logic [TAG_WIDTH-1:0]               tags_q [N_SETS-1:0], tags_d [N_SETS-1:0];

  logic [N_SETS_WIDTH-1:0]            current_set;
  logic [TAG_WIDTH-1:0]               current_tag;
  logic                               hit;

  assign current_set = request_i.addr.internal.set;
  assign current_tag = request_i.addr.internal.tag;
  assign hit         = valid_q[current_set] & (tags_q[current_set] == current_tag);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      valid_q <= 'h0;
      dirty_q <= 'h0;

      for (int i = 0; i < N_SETS; i++) tags_q[i] <= 'h0;
    end else begin
      valid_q <= valid_d;
      dirty_q <= dirty_d;

      for (int i = 0; i < N_SETS; i++) tags_q[i] <= tags_d[i];
    end
  end

  always_comb begin
    valid_d = valid_q;
    dirty_d = dirty_q;

    for (int i = 0; i < N_SETS; i++) tags_d[i] = tags_q[i];

    if (request_i.req) begin
      unique case (request_i.op)
        CACHE_WRITE: begin
          // Sector is now fully in cache (valid), and may be dirty if it's a write
          if (last_sector_word_i) begin
            valid_d[current_set] = 1'b1;
            dirty_d[current_set] = request_i.dirty;
            tags_d[current_set]  = current_tag;
          end
        end

        CACHE_EVICT: begin
          // Sector is evicted (not valid)
          if (hit) begin
            valid_d[current_set] = 1'b0;
          end
        end

        default: ;
      endcase
    end
  end

  assign hit_o   = hit;
  assign dirty_o = dirty_q[current_set];
  assign victim_sector_o = {tags_q[current_set], current_set};

endmodule
