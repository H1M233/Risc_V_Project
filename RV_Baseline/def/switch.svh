
`ifndef SWITCH
`define SWITCH

// RAM
// L1:   8 KB
// L2: 256 KB

// I-CACHE
`define ICACHE_INDEX_WIDTH 7 // 4 KB

// D-CACHE
`define DCACHE_INDEX_WIDTH 9 // 4 KB

// Perip Range
`ifdef VERILATOR_INST_TEST
    `define DRAM_ADDR_START  32'h0000_0000
    `define DRAM_ADDR_END    32'hFFFF_FFFF
`else
    `define DRAM_ADDR_START  32'h8000_0000
    `define DRAM_ADDR_END    32'h8013_FFFF
`endif

// 扩展
`define ENABLE_M
// `define ENABLE_B
`ifdef ENABLE_B
    `define ENABLE_B_ZBA
    // `define ENABLE_B_ZBB
    // `define ENABLE_B_ZBC
    `define ENABLE_B_ZBS
    // `define ENABLE_B_ZBKB
    // `define ENABLE_B_ZBKX
`endif

// `define ENABLE_Zicond
// `define ENABLE_A
// `define ENABLE_F
// `define ENABLE_C

// LUT 存放位置
`define LUT_PATH "D:/FPGA_Project/Risc_V_Project/LUT"

`endif