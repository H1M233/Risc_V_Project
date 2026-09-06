
`ifndef SWITCH
`define SWITCH

// BPU
`define GSHARE_BHR_WIDTH        10
`define GSHARE_PHT_IDX_WIDTH    12
`define BTB_IDX_WIDTH           4

// 空间分配
`ifdef VERILATOR_INST_TEST
    `define IROM_ADDR_START         32'h8000_0000
    `define IROM_ADDR_END           32'h8000_3FFF
    `define DRAM_ADDR_START         32'h8000_0000
    `define DRAM_ADDR_END           32'h8000_3FFF
    `define PERIP_KEY_ADDR          32'h8020_0010
    `define PERIP_SEG_ADDR          32'h8020_0020
    `define PERIP_LED_ADDR          32'h8020_0040
    `define PERIP_CNT_ADDR          32'h8020_0050
    `define PERIP_UART_ADDR         32'h8020_0060       // (0): TX, (+4) RX, (+8): STATUS
`elsif VERILATOR_SOFTWARE_TEST
    `define IROM_ADDR_START         32'h8000_0000       // 16 KB
    `define IROM_ADDR_END           32'h8000_3FFF
    `define DRAM_ADDR_START         32'h8010_0000       // 256 KB
    `define DRAM_ADDR_END           32'h8013_FFFF
    `define PERIP_KEY_ADDR          32'h8020_0010
    `define PERIP_SEG_ADDR          32'h8020_0020
    `define PERIP_LED_ADDR          32'h8020_0040
    `define PERIP_CNT_ADDR          32'h8020_0050
    `define PERIP_UART_ADDR         32'h8020_0060       // (0): TX, (+4) RX, (+8): STATUS
`elsif VERILATOR_MYSYSTEM
    `define IROM_ADDR_START         32'h4000_0000       // 16 KB
    `define IROM_ADDR_END           32'h4000_3FFF
    `define DRAM_ADDR_START         32'h8000_0000       // 256 KB
    `define DRAM_ADDR_END           32'h8003_FFFF
    // `define DRAM_ADDR_START         32'h8000_0000       // 1 GB
    // `define DRAM_ADDR_END           32'hBFFF_FFFF
    `define PERIP_KEY_ADDR          32'h2000_0010
    `define PERIP_SEG_ADDR          32'h2000_0014
    `define PERIP_LED_ADDR          32'h2000_0018
    `define PERIP_CNT_ADDR          32'h2000_001C
    `define PERIP_UART_ADDR         32'h2000_0020       // (0): TX, (+4) RX, (+8): STATUS
`else
    `define IROM_ADDR_START         32'h4000_0000       // 16 KB
    `define IROM_ADDR_END           32'h4000_3FFF
    `define DRAM_ADDR_START         32'h8000_0000       // 256 KB
    `define DRAM_ADDR_END           32'h8003_FFFF
    // `define DRAM_ADDR_START         32'h8000_0000       // 1 GB
    // `define DRAM_ADDR_END           32'hBFFF_FFFF
    `define PERIP_KEY_ADDR          32'h2000_0010
    `define PERIP_SEG_ADDR          32'h2000_0014
    `define PERIP_LED_ADDR          32'h2000_0018
    `define PERIP_CNT_ADDR          32'h2000_001C
    `define PERIP_UART_ADDR         32'h2000_0020       // (0): TX, (+4) RX, (+8): STATUS
`endif

// Cache 配置
`define ICACHE_INDEX_WIDTH 8 // I-Cache : 4 KB
`define DCACHE_INDEX_WIDTH 9 // D-Cache : 4 KB

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
`define ENABLE_C

// LUT 存放位置
`define LUT_PATH "D:/FPGA_Project/Risc_V_Project/Fext_LUT"

`endif