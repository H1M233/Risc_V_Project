`include "rv32I.vh"
module id_ex(
    input clk,
    input rst,
    input jump_en,              // 来自控制单元的跳转使能信号
    input hazard_en,             // 来自控制单元的冒险使能信号
    input regs_wen_i,                   // 来自控制单元的寄存器写使能信号
    input [31:0] inst_i,
    input [31:0] value1_i,        
    input [31:0] value2_i,         
    input [31:0] jump1_i,
    input [31:0] jump2_i,
    input [4:0] rd_addr_i,
    input [31:0] rs1_data_i,
    input [31:0] rs2_data_i,
    
    output reg regs_wen_o,                  
    output reg [31:0] inst_o,
    output reg [31:0] value1_o,         
    output reg [31:0] value2_o,         
    output reg [31:0] jump1_o,
    output reg [31:0] jump2_o,
    output reg [4:0] rd_addr_o,
    output reg [31:0] rs1_data_o,
    output reg [31:0] rs2_data_o
);
    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            regs_wen_o <= 1'b0;
            inst_o <= `NOP;
            value1_o <= 32'b0;
            value2_o <= 32'b0;
            jump1_o <= 32'b0;
            jump2_o <= 32'b0;
            rd_addr_o <= 5'b0;
            rs1_data_o <= 32'b0;
            rs2_data_o <= 32'b0;     
        end
        else if(jump_en) begin
            regs_wen_o <= 1'b0;
            inst_o <= `NOP;
            value1_o <= 32'b0;
            value2_o <= 32'b0;
            jump1_o <= 32'b0;
            jump2_o <= 32'b0;
            rd_addr_o <= 5'b0;
            rs1_data_o <= 32'b0;
            rs2_data_o <= 32'b0;  
        end
        else if(hazard_en) begin
            regs_wen_o <= 1'b0;
            inst_o <= `NOP;
            value1_o <= 32'b0;
            value2_o <= 32'b0;
            jump1_o <= 32'b0;
            jump2_o <= 32'b0;
            rd_addr_o <= 5'b0;
            rs1_data_o <= 32'b0;
            rs2_data_o <= 32'b0;  
        end
        else begin
            regs_wen_o <= regs_wen_i;
            inst_o <= inst_i;
            value1_o <= value1_i;
            value2_o <= value2_i;
            jump1_o <= jump1_i;
            jump2_o <= jump2_i;
            rd_addr_o <= rd_addr_i;
            rs1_data_o <= rs1_data_i;
            rs2_data_o <= rs2_data_i;       
        end
    end
endmodule