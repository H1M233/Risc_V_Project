`include "rv32I.vh"

module mem_wb(
    input               clk,
    input               rst,

    // from mem
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen_i,
    input               is_load_i,
    input               ecall_i,
    input               mret_i,

    // from wb
    input               ecall_flush,
    input               mret_flush,

    // to wb
    output reg [4:0]    rd_addr_o,
    output reg [31:0]   rd_data_o,
    output reg          regs_wen_o,
    output reg          is_load_o,
    output reg          ecall_o,
    output reg          mret_o
);
    always@(posedge clk) begin
        if(!rst) begin
            rd_data_o       <= 32'b0;
            rd_addr_o       <= 5'b0;
            regs_wen_o      <= 1'b0;
            is_load_o       <= 1'b0;
            ecall_o         <= 1'b0;
            mret_o          <= 1'b0;
        end
        else if(ecall_flush | mret_flush) begin
            rd_data_o       <= 32'b0;
            rd_addr_o       <= 5'b0;
            regs_wen_o      <= 1'b0;
            is_load_o       <= 1'b0;
            ecall_o         <= 1'b0;    // ecall_flush 信号来自 wb，当发生 ecall 时，清空 mem_wb 寄存器，防止错误执行
            mret_o          <= 1'b0;    // mret_flush 信号来自 wb，当发生 mret 时，清空 mem_wb 寄存器，防止错误执行
        end
        else begin
            rd_data_o       <= rd_data_i;
            rd_addr_o       <= rd_addr_i;
            regs_wen_o      <= regs_wen_i;
            is_load_o       <= is_load_i;
            ecall_o         <= ecall_i;
            mret_o          <= mret_i;
        end
    end
endmodule
