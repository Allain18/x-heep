module cache
  import cache_reg_pkg::*;
#(

) (
  input logic clk_i,
  input logic rst_ni,

  input cache_req_t request_i,

  output cache_res_t response_o
);

  // Implements single way only

  logic hit;
  logic dirty;
  logic [(SECTOR_SIZE_BYTES * 8)-1:0] data;

  cache_way way (
    .clk_i(clk_i),
    .rst_ni(rst_ni),

    .address_i(request_i.addr),
    .rnw_i(request_i.rnw),

    .hit_o(hit),
    .dirty_o(dirty),
    .data_o(data)
  );

  assign response_o.hit = hit;
  assign response_o.miss_info.dirty = dirty;
  assign response_o.miss_info.victim_sector = TODO;

endmodule
