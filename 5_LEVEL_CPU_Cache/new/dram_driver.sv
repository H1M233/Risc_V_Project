`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/22/2025 11:42:01 AM
// Design Name: 
// Module Name: dram_driver
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


module dram_driver(
    input  logic         clk				,

    input  logic [15:0]  dram_addr			,
    input  logic [31:0]  perip_wdata		,
    input  logic [3:0]   perip_we           ,
    output logic [31:0]  perip_rdata		
);

    blk_mem_gen_0 Mem_DRAM (
        .addra      (dram_addr),
        .clka       (clk),
        .dina       (perip_wdata),
        .douta      (perip_rdata),
        .wea        (perip_we)
    );
endmodule
