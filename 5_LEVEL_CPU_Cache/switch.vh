// `define ENABLE_ICACHE
// `define ENABLE_DCACHE

`ifdef ENABLE_DCACHE
    `define DRAM_READ_DELAY 2
`else
    `define DRAM_READ_DELAY 2
`endif

`define DRAM_ADDR_START  32'h8010_0000
`define DRAM_ADDR_END    32'h8013_FFFF