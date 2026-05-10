`include "ooo_defs.vh"

module arch_regfile_2w4r (
    input               clk,
    input               rst,
    input  [4:0]        rs1_addr_0,
    input  [4:0]        rs2_addr_0,
    input  [4:0]        rs1_addr_1,
    input  [4:0]        rs2_addr_1,
    output [31:0]       rs1_data_0,
    output [31:0]       rs2_data_0,
    output [31:0]       rs1_data_1,
    output [31:0]       rs2_data_1,
    input               wen_0,
    input  [4:0]        waddr_0,
    input  [31:0]       wdata_0,
    input               wen_1,
    input  [4:0]        waddr_1,
    input  [31:0]       wdata_1
);
    integer i;
    reg [31:0] regs [0:31];

    always @(posedge clk) begin
        if (!rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'b0;
        end else begin
            if (wen_0 && waddr_0 != 5'd0)
                regs[waddr_0] <= wdata_0;
            if (wen_1 && waddr_1 != 5'd0)
                regs[waddr_1] <= wdata_1;
        end
    end

    // Bypass: slot1 > slot0 > regfile
    function [31:0] read_bp;
        input [4:0]  raddr;
        input        w0en;  input [4:0] w0a; input [31:0] w0d;
        input        w1en;  input [4:0] w1a; input [31:0] w1d;
        begin
            if (raddr == 5'd0)          read_bp = 32'b0;
            else if (w1en && w1a == raddr) read_bp = w1d;
            else if (w0en && w0a == raddr) read_bp = w0d;
            else                           read_bp = regs[raddr];
        end
    endfunction

    assign rs1_data_0 = read_bp(rs1_addr_0, wen_0, waddr_0, wdata_0, wen_1, waddr_1, wdata_1);
    assign rs2_data_0 = read_bp(rs2_addr_0, wen_0, waddr_0, wdata_0, wen_1, waddr_1, wdata_1);
    assign rs1_data_1 = read_bp(rs1_addr_1, wen_0, waddr_0, wdata_0, wen_1, waddr_1, wdata_1);
    assign rs2_data_1 = read_bp(rs2_addr_1, wen_0, waddr_0, wdata_0, wen_1, waddr_1, wdata_1);
endmodule
