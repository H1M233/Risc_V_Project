// `define ENABLE_ICACHE
// `define ENABLE_DCACHE

`ifdef ENABLE_DCACHE
    `define DRAM_READ_DELAY 2
`else
    `define DRAM_READ_DELAY 1
`endif