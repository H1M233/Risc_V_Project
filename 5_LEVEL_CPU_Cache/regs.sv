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
    output     [31:0]   rs1_data_o,
    (* max_fanout = 30 *)
    output     [31:0]   rs2_data_o
);
    // 32个32位寄存器
    reg [31:0] regs_p1[31:0];
    reg [31:0] regs_p2[31:0];

    // 读寄存器
    assign rs1_data_o = regs_p1[rs1_addr_i];
    assign rs2_data_o = regs_p2[rs2_addr_i];

    integer i;
    always_ff @(posedge clk) begin
        if (!rst) begin
            for (i = 0; i < 32; i = i + 1) begin
				regs_p1[i] <= 32'b0;
                regs_p2[i] <= 32'b0;
            end
		end
        else if (regs_wen)  begin
            regs_p1[rd_addr_i] <= rd_data_i;
            regs_p2[rd_addr_i] <= rd_data_i;
        end
    end
endmodule