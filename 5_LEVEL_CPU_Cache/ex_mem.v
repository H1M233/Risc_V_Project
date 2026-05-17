`include "rv32I.vh"

module ex_mem(
    input               clk,
    input               rst,

    // from ex
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen_i,
    input               mem_req_load_i,
    input               ecall_i,
    input               mret_i,
    
    // from wb
    input               ecall_flush,
    input               mret_flush,
    // to mem
    (* max_fanout = 30 *)
    output reg [4:0]    rd_addr_o,
    (* max_fanout = 30 *)
    output reg [31:0]   rd_data_o,
    (* max_fanout = 30 *)
    output reg          regs_wen_o,
    output reg          mem_req_load_o,
    output reg          ecall_o,
    output reg          mret_o
);
    always@(posedge clk) begin
        if(!rst) begin
            rd_addr_o           <= 5'b0;
            rd_data_o           <= 32'b0;
            regs_wen_o          <= 1'b0;
            mem_req_load_o      <= 1'b0;
            ecall_o             <= 1'b0;
            mret_o              <= 1'b0;
        end
        else if(ecall_flush | mret_flush) begin
            rd_addr_o           <= 5'b0;
            rd_data_o           <= 32'b0;
            regs_wen_o          <= 1'b0;
            mem_req_load_o      <= 1'b0;
            ecall_o             <= 1'b0;    // ecall_flush 信号来自 wb，当发生 ecall 时，清空 ex_mem 寄存器，防止错误执行
            mret_o              <= 1'b0;    // mret_flush 信号来自 wb，当发生 mret 时，清空 ex_mem 寄存器，防止错误执行
        end
        else begin
            rd_addr_o           <= rd_addr_i;
            rd_data_o           <= rd_data_i;
            regs_wen_o          <= regs_wen_i;
            mem_req_load_o      <= mem_req_load_i;
            ecall_o             <= ecall_i;
            mret_o              <= mret_i;
        end
    end
endmodule