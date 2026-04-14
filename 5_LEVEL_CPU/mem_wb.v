`include "rv32I.vh"

module mem_wb(
    input clk,
    input rst_n,
    input [31:0] rd_data_i,
    input [4:0] rd_addr_i,
    input regs_wen_i,

    output reg [31:0] rd_data_o,
    output reg [4:0] rd_addr_o,
    output reg regs_wen_o
);
    always@(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            rd_data_o <= 32'b0;
            rd_addr_o <= 5'b0;
            regs_wen_o <= 1'b0;
        end 
        else begin
            rd_data_o <= rd_data_i;
            rd_addr_o <= rd_addr_i;
            regs_wen_o <= regs_wen_i;
        end
    end
endmodule
