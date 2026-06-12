// BPU
`define GSHARE_BHR_WIDTH 12
`define GSHARE_PHT_IDX_WIDTH 12

// RAM
// L1:   8 KB
// L2: 256 KB

// D-CACHE
`define DCACHE_INDEX_WIDTH 10 // 2 * 1024 * 4

// Perip Range
`ifdef VERILATOR_INST_TEST
    `define DRAM_ADDR_START  32'h0000_0000
    `define DRAM_ADDR_END    32'hFFFF_FFFF
`else
    `define DRAM_ADDR_START  32'h8010_0000
    `define DRAM_ADDR_END    32'h8013_FFFF
`endif

// 扩展
// `define ENABLE_M

// `define ENABLE_B
`ifdef ENABLE_B
    `define ENABLE_B_ZBA
    `define ENABLE_B_ZBB
    `define ENABLE_B_ZBC
    `define ENABLE_B_ZBS
    `define ENABLE_B_ZBKB
    `define ENABLE_B_ZBKX
`endif

// `define ENABLE_Zicond

`define ENABLE_A