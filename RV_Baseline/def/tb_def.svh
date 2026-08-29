`ifndef TB_DEF
`define TB_DEF

// Inner
`define PERIP_BRIDGE_PATH   uut.student_top_inst.bridge_inst
`define CPU_PATH            uut.student_top_inst.Core_cpu
`define FRONTEND_PATH       `CPU_PATH.Frontend
`define BACKEND_PATH        `CPU_PATH.Backend

// Peripheral
`define IROM_PATH   `PERIP_BRIDGE_PATH.irom_driver_inst.Mem_IROM.rom_mem
`define DRAM_PATH   `PERIP_BRIDGE_PATH.dram_driver_inst.Mem_DRAM.dram_inst.ram_mem
`define LED_PATH    `PERIP_BRIDGE_PATH.LED
`define SEG_PATH    `PERIP_BRIDGE_PATH.SEG

// Outer
`define EX_PATH     `BACKEND_PATH.EX

`define HOLD_PATH   `BACKEND_PATH.pipe_hold_id_ex
`define FLUSH_PATH  `BACKEND_PATH.pipe_flush_id_ex

`endif