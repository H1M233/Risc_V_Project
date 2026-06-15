`include "rv32I.vh"

module regs(
    input  logic clk,
    input  logic rst,

    // from wb
    input  logic [5:0]  rd_addr_i,  // 增加最高位判断浮点寄存器
    input  logic [31:0] rd_data_i,
    input  logic        regs_wen,

    // from id
    input  logic [5:0]  rs1_addr_i,
    input  logic [5:0]  rs2_addr_i,

    // to id
    output logic [31:0] rs1_data_o,
    output logic [31:0] rs2_data_o
);
    // 64 个 32 位寄存器 - 高 32 为浮点寄存器
    reg [31:0] regs_p1 [0:63];
    reg [31:0] regs_p2 [0:63];

    // 初始化
    initial begin
        for (int i = 0; i < 64; i++) begin
            regs_p1[i] = 32'b0;
            regs_p2[i] = 32'b0;
        end
    end

    // 读寄存器
    assign rs1_data_o = regs_p1[rs1_addr_i];
    assign rs2_data_o = regs_p2[rs2_addr_i];

    // 写寄存器
    always_ff @(posedge clk) begin
        if (regs_wen) begin
            regs_p1[rd_addr_i] <= rd_data_i;
            regs_p2[rd_addr_i] <= rd_data_i;
        end
    end
endmodule