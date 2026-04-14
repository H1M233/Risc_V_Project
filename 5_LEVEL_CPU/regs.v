`include "rv32I.vh"

module regs(
    input clk,
    input rst,
    input regs_wen,       // 寄存器写使能信号
    input [4:0] rs1_addr_i,
    input [4:0] rs2_addr_i,
    input [4:0] rd_addr_i,
    input [31:0] rd_data_i,

    output reg [31:0] rs1_data_o,
    output reg [31:0] rs2_data_o
);
    reg [31:0] regs[31:0];     // 32个32位寄存器

    // 读寄存器
    always@(*) begin
        if(rst) begin
            rs1_data_o = 32'b0;
        end 
        else if((rs1_addr_i == rd_addr_i) && regs_wen && (rd_addr_i != 0)) begin
            rs1_data_o = rd_data_i;   // 数据转发，解决数据冒险
        end
        else begin
            rs1_data_o = (rs1_addr_i != 0) ? regs[rs1_addr_i] : 32'b0;
        end
    end

    always@(*) begin
        if(rst) begin
            rs2_data_o = 32'b0;
        end 
        else if((rs2_addr_i == rd_addr_i) && regs_wen && (rd_addr_i != 0)) begin
            rs2_data_o = rd_data_i;   // 数据转发，解决数据冒险
        end
        else begin
            rs2_data_o = (rs2_addr_i != 0) ? regs[rs2_addr_i] : 32'b0;
        end
    end
    integer i;
    // 写寄存器
    always @(posedge clk or negedge rst) begin
        if (rst) begin
            // 复位时将所有寄存器清零
            for (i = 1; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end 
        else if (regs_wen && (rd_addr_i != 0))  begin
            regs[rd_addr_i] <= rd_data_i;   // 写入数据到指定寄存器，x0寄存器不可写
        end
    end
endmodule