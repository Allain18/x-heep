package cache_reg_pkg;

  parameter int N_WAYS = 1;
  parameter int N_SETS = 4;
  parameter int SECTOR_SIZE_BYTES = 4096;

  parameter int N_WAYS_WIDTH = $clog2(N_WAYS);
  parameter int N_SETS_WIDTH = $clog2(N_SETS);
  parameter int SECTOR_SIZE_BYTES_WIDTH = $clog2(SECTOR_SIZE_BYTES);

  parameter int TAG_WIDTH = 32 - N_SETS_WIDTH - SECTOR_SIZE_BYTES_WIDTH;

  typedef union packed {
    logic [31:0] exposed;

    // Packed fields: tag | set | byte_offset
    struct packed {
      logic [TAG_WIDTH-1:0] tag;
      logic [N_SETS_WIDTH-1:0] set;
      logic [SECTOR_SIZE_BYTES_WIDTH-1:0] byte_offset;
    } internal;
  } address_t;

  // Cache request
  typedef struct packed {
    address_t addr;
    logic rnw; // 1 if read, 0 if write
  } cache_req_t;

  // Cache response
  typedef struct packed {
    logic dirty; // 1 if dirty, 0 if clean
    logic [(TAG_WIDTH + N_SETS_WIDTH)-1:0] victim_sector;
  } eviction_info_t;

  typedef struct packed {
    logic hit; // 1 if hit, 0 if miss
    eviction_info_t miss_info; // Only in case of miss, to handle eviction
  } cache_res_t;

endpackage
