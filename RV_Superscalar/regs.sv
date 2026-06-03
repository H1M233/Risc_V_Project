`include "rv32I.vh"

module regs(
    input               clk,
    input               rst,

    // from wb
    input      [4:0]    slot0_rd_addr_i,
    input      [4:0]    slot1_rd_addr_i,
    input      [31:0]   slot0_rd_data_i,
    input      [31:0]   slot1_rd_data_i,
    input               slot0_regs_wen,
    input               slot1_regs_wen,

    // from id
    input      [4:0]    slot0_rs1_addr_i,
    input      [4:0]    slot1_rs1_addr_i,
    input      [4:0]    slot0_rs2_addr_i,
    input      [4:0]    slot1_rs2_addr_i,

    // to id
    output     [31:0]   slot0_rs1_data_o,
    output     [31:0]   slot1_rs1_data_o,
    output     [31:0]   slot0_rs2_data_o,
    output     [31:0]   slot1_rs2_data_o
);
    // 32个32位寄存器
    reg [31:0] regs_p1[31:0];
    reg [31:0] regs_p2[31:0];

    // 读寄存器
    assign slot0_rs1_data_o = regs_p1[slot0_rs1_addr_i];
    assign slot1_rs1_data_o = regs_p1[slot1_rs1_addr_i];
    assign slot0_rs2_data_o = regs_p2[slot0_rs2_addr_i];
    assign slot1_rs2_data_o = regs_p2[slot1_rs2_addr_i];

    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            regs_p1[i] = 32'b0;
            regs_p2[i] = 32'b0;
        end
    end

    logic write_same_rd;
    assign write_same_rd = slot0_rd_addr_i == slot1_rd_addr_i && slot0_regs_wen && slot1_regs_wen;
    always @(posedge clk) begin
        if (slot0_regs_wen && !write_same_rd)  begin
            regs_p1[slot0_rd_addr_i] <= slot0_rd_data_i;
            regs_p2[slot0_rd_addr_i] <= slot0_rd_data_i;
        end
        if (slot1_regs_wen) begin
            regs_p1[slot1_rd_addr_i] <= slot1_rd_data_i;
            regs_p2[slot1_rd_addr_i] <= slot1_rd_data_i;
        end
    end
endmodule