`timescale 1ns / 1ps
module dram_driver(
    input  logic         clk				,

    input  logic [31:0]  perip_addr			,
    input  logic [31:0]  perip_wdata		,
    input  logic [3:0]   perip_we           ,
    output logic [31:0]  perip_rdata		
);

    logic [15:0] dram_addr;
    assign dram_addr = perip_addr[17:2];

    DRAM Mem_DRAM (
        .addra      (dram_addr),
        .clka       (clk),
        .dina       (perip_wdata),
        .douta      (perip_rdata),
        .wea        (perip_we)
    );
endmodule
