`include "rv32I.vh"

module mem_wb(
    input  logic clk,
    input  logic rst,
    input  logic pipe_flush,

    // from mem
    input  mem_wb_data_t data_packaged_i,

    // to wb
    output logic [4:0]   rd_addr_o,
    output logic [31:0]  rd_data_o,
    output logic         regs_wen_o,
    output logic         ecall_o,
    output logic         mret_o
);
    always_ff @(posedge clk) begin
        if (!rst) begin
            rd_data_o       <= 32'b0;
            rd_addr_o       <= 5'b0;
            regs_wen_o      <= 1'b0;
            ecall_o         <= 1'b0;
            mret_o          <= 1'b0;
        end
        else if (pipe_flush) begin
            rd_data_o       <= 32'b0;
            rd_addr_o       <= 5'b0;
            regs_wen_o      <= 1'b0;
            ecall_o         <= 1'b0;    // ecall_flush 信号来自 wb，当发生 ecall 时，清空 mem_wb 寄存器，防止错误执行
            mret_o          <= 1'b0;    // mret_flush 信号来自 wb，当发生 mret 时，清空 mem_wb 寄存器，防止错误执行
        end
        else begin
            rd_data_o       <= data_packaged_i.rd_data;
            rd_addr_o       <= data_packaged_i.rd_addr;
            regs_wen_o      <= data_packaged_i.regs_wen;
            ecall_o         <= data_packaged_i.ecall;
            mret_o          <= data_packaged_i.mret;
        end
    end
endmodule
