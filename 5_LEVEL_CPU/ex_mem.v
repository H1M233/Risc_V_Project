`include "rv32I.vh"

module ex_mem(
    input clk,
    input rst_n,

    input [31:0] inst_i,
    input mem_wen_i,
    input mem_req_i,
    input [31:0] mem_addr_i,
    input regs_wen_i,
    input [31:0] rd_data_i,
    input [4:0] rd_addr_i,
    input [31:0] rs2_data_i,

    output reg [31:0] inst_o,
    output reg mem_wen_o,
    output reg mem_req_o,
    output reg [31:0] mem_addr_o,
    output reg regs_wen_o,
    output reg [31:0] rd_data_o,
    output reg [4:0] rd_addr_o,
    output reg [31:0] rs2_data_o
);
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            inst_o <= `NOP;
            mem_wen_o <= 1'b0;
            mem_req_o <= 1'b0;
            mem_addr_o <= 32'b0;
            regs_wen_o <= 1'b0;
            rd_data_o <= 32'b0;
            rd_addr_o <= 5'b0;
            rs2_data_o <= 32'b0;
        end else begin
            inst_o <= inst_i;
            mem_wen_o <= mem_wen_i;
            mem_req_o <= mem_req_i;
            mem_addr_o <= mem_addr_i;
            regs_wen_o <= regs_wen_i;
            rd_data_o <= rd_data_i;
            rd_addr_o <= rd_addr_i;
            rs2_data_o <= rs2_data_i;
        end
    end
endmodule