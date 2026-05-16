`include "rv32I.vh"

module regs(
    input               clk,
    input               rst,

    // from wb
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen,       // 寄存器写使能信号

    // from id
    input      [4:0]    rs1_addr_i,
    input      [4:0]    rs2_addr_i,

    // to id
    (* max_fanout = 30 *)
    output reg [31:0]   rs1_data_o,
    (* max_fanout = 30 *)
    output reg [31:0]   rs2_data_o
);
    reg [31:0] regs[31:0];              // 32个32位寄存器

    // 读寄存器
    always@(*) begin
        rs1_data_o  = regs[rs1_addr_i];
        rs2_data_o  = regs[rs2_addr_i];
    end

    integer i;
    // 写寄存器
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            regs[i] = 32'b0;
        end
    end
    always @(posedge clk) begin
        if (rst && regs_wen)  begin
            regs[rd_addr_i] <= rd_data_i;
        end
    end
endmodule