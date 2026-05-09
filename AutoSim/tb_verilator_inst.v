`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/16/2025 06:28:41 PM
// Design Name: 
// Module Name: tb_verilator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module tb_verilator_inst(
    input clk_50MHz,
    input clk_cpu,
    input rst,

    output x3,
    output x26,
    output x27
);
    
    top uut (
        .w_clk_50Mhz    (clk_50MHz),
        .cpu_clk        (clk_cpu),
        .w_clk_rst      (rst),
        .i_uart_rx      (1'b1),
        .o_uart_tx      (),
        .virtual_led    (),  
        .virtual_seg    ()
    );

    initial begin
        $readmemh("./mem_init/irom.txt", tb_verilator_inst.uut.student_top_inst.Mem_IROM.rom_mem);
        $readmemh("./mem_init/dram.txt", tb_verilator_inst.uut.student_top_inst.bridge_inst.dram_driver_inst.Mem_DRAM.dram_inst.ram_mem);
    end

    wire x3  = tb_verilator_inst.uut.student_top_inst.Core_cpu.REGS.regs[3];   // 进行的test序号
    wire x26 = tb_verilator_inst.uut.student_top_inst.Core_cpu.REGS.regs[26];  // 测试结束信号
    wire x27 = tb_verilator_inst.uut.student_top_inst.Core_cpu.REGS.regs[27];  // 0: fail, 1: pass
endmodule
