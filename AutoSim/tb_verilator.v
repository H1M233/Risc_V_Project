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


module tb_verilator(
    input clk_50MHz,
    input clk_cpu,
    input rst,

    output [31:0] seg,
    output [31:0] mem_inst,
    output        icache_req,
    output        icache_hit,
    output        dcache_req,
    output        dcache_hit,
    output [31:0] pc,
    output reg [31:0] func_block_addr,
    output [31:0] LED
);
    
    top uut (
        .w_clk_50Mhz    (clk_50MHz),
        .cpu_clk        (clk_cpu),
        .w_clk_rst      (rst),
        .i_uart_rx      (1'b1),
        .o_uart_tx      (),
        .virtual_led    (LED),  
        .virtual_seg    ()
    );

    initial begin
        $readmemh("./mem_init/irom.txt", tb_verilator.uut.student_top_inst.Mem_IROM.rom_mem);
        $readmemh("./mem_init/dram.txt", tb_verilator.uut.student_top_inst.bridge_inst.dram_driver_inst.Mem_DRAM.dram_inst.ram_mem);
    end

    assign seg = tb_verilator.uut.student_top_inst.bridge_inst.seg_driver.s;
    assign mem_inst = tb_verilator.uut.student_top_inst.Core_cpu.MEM.inst_i;
    

    assign pc = tb_verilator.uut.student_top_inst.Core_cpu.EX.pc_addr_i;

    assign icache_req = (tb_verilator.uut.student_top_inst.Core_cpu.ICACHE.state == 1'd0);
    assign icache_hit = tb_verilator.uut.student_top_inst.Core_cpu.ICACHE.hit;
    assign dcache_req = (tb_verilator.uut.student_top_inst.Core_cpu.DCACHE.state == 3'd1);
    assign dcache_hit = tb_verilator.uut.student_top_inst.Core_cpu.DCACHE.hit;
    wire [6:0] ex_opcode = tb_verilator.uut.student_top_inst.Core_cpu.EX.opcode;
    always @(posedge clk_cpu) begin
        if (ex_opcode == `JAL)          func_block_addr <= tb_verilator.uut.student_top_inst.Core_cpu.EX.add_res;
        else if (ex_opcode == `JALR)    func_block_addr <= tb_verilator.uut.student_top_inst.Core_cpu.EX.jalr_target;
        else if (ex_opcode == `TYPE_B & tb_verilator.uut.student_top_inst.Core_cpu.EX.branch_taken == 1'b1)  func_block_addr <= tb_verilator.uut.student_top_inst.Core_cpu.EX.branch_jump_addr;
    end

    // assign icache_req = 1'b1;
    // assign icache_hit = 1'b0;
    // assign dcache_req = 1'b1;
    // assign dcache_hit = 1'b0;
    // assign func_block_addr = 32'b0;

endmodule
