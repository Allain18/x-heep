package cache_reg_pkg;

  parameter int N_WAYS = 1;
  parameter int N_SETS = 4;
  parameter int SECTOR_SIZE_BYTES = 4096;

  parameter int WORD_SIZE_BYTES = 4;
  parameter int WORD_SIZE_BITS  = WORD_SIZE_BYTES << 3;
  parameter int SECTOR_SIZE_WORDS = SECTOR_SIZE_BYTES / WORD_SIZE_BYTES;

  parameter int N_WAYS_WIDTH = (N_WAYS > 1) ? $clog2(N_WAYS) : 1;
  parameter int N_SETS_WIDTH = (N_SETS > 1) ? $clog2(N_SETS) : 1;
  parameter int SECTOR_SIZE_BYTES_WIDTH = (SECTOR_SIZE_BYTES > 1) ? $clog2(SECTOR_SIZE_BYTES) : 1;
  parameter int SECTOR_SIZE_WORDS_WIDTH = (SECTOR_SIZE_WORDS > 1) ? $clog2(SECTOR_SIZE_WORDS) : 1;

  parameter int TAG_WIDTH            = 32 - N_SETS_WIDTH - SECTOR_SIZE_BYTES_WIDTH;
  parameter int SECTOR_ADDRESS_WIDTH = 32 - SECTOR_SIZE_BYTES_WIDTH;

  typedef union packed {
    logic [31:0] exposed;

    // Packed fields: tag[31:14] | set[13:12] | byte_offset[11:0]
    struct packed {
      logic [TAG_WIDTH-1:0]               tag;
      logic [N_SETS_WIDTH-1:0]            set;
      logic [SECTOR_SIZE_BYTES_WIDTH-1:0] byte_offset;
    } internal;
  } address_t;

  typedef enum logic [1:0] {
    CACHE_READ,   // lookup + read word if hit
    CACHE_WRITE,  // lookup + write word if hit
    CACHE_FILL    // push a single word into cache (when filling sector)
  } cache_op_e;

  // Cache request
  typedef struct packed {
    cache_op_e                            op;
    address_t                             addr;
    logic [31:0]                          wdata; // data in case of a write
  } cache_req_t;

  // Cache response
  typedef struct packed {
    logic                                 dirty; // 1 if dirty, 0 if clean
    logic [SECTOR_ADDRESS_WIDTH-1:0]      victim_sector_address; // {tag, set}
  } eviction_info_t;

  typedef struct packed {
    logic                                 hit; // 1 if hit, 0 if miss
    logic [31:0]                          rdata; // data in case of hit
    eviction_info_t                       miss_info; // Only in case of miss, to handle eviction
  } cache_res_t;

endpackage
