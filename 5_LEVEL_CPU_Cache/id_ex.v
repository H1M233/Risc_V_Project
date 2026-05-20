`include "rv32I.vh"
`include "alu.vh"

module id_ex(
    input               clk,
    input               rst,

    input               pred_flush,
    input               hazard_en,
    input               dcache_stall,

    // from id
    input      [31:0]   pc_addr_i,
    input      [31:0]   inst_i,
    input      [31:0]   jump1_i,
    input      [31:0]   jump2_i,
    input      [4:0]    rd_addr_i,
    input               regs_wen_i,
    input      [4:0]    rs1_addr_i,
    input      [4:0]    rs2_addr_i,
    input      [31:0]   value1_i,
    input      [31:0]   value2_i,
    input               pred_taken_i,
    input      [`OP_INST_NUM - 1:0] inst_packaged_i,

    // from forwarding
    input      [31:0]   fwd_rs1_data_i,
    input      [31:0]   fwd_rs2_data_i,
    input               fwd_rs1_hit_ex_i,
    input               fwd_rs2_hit_ex_i,
    //ecall
    input               ecall_i,
    input               mret_i,
    //打拍给csr
    input      [11:0]   csr_addr_i,
    //form wb
    input               ecall_flush,
    input               mret_flush,

    // to ex
    output reg [31:0]   pc_addr_o,
    output reg [31:0]   inst_o,
    output reg [31:0]   jump1_o,
    output reg [31:0]   jump2_o,
    (* max_fanout = 30 *)
    output reg [4:0]    rd_addr_o,
    output reg          regs_wen_o,
    output reg [4:0]    rs1_addr_o,
    output reg [4:0]    rs2_addr_o,
    output reg [31:0]   value1_o,
    output reg [31:0]   value2_o,
    output reg          pred_taken_o,
    output reg [`OP_INST_NUM - 1:0] inst_packaged_o,
    output reg          valid_o,
    output reg [31:0]   fwd_rs1_data_o,
    output reg [31:0]   fwd_rs2_data_o,
    output reg          fwd_rs1_hit_ex_o,
    output reg          fwd_rs2_hit_ex_o,

    output reg          ecall_o,
    output reg          mret_o,

    output reg [11:0]   csr_addr_o
);
    wire id_ex_ecall_mret_flush = (ecall_flush | mret_flush);
    wire id_ex_hold_en  = dcache_stall;
    wire id_ex_flush_en_n = ~(pred_flush | hazard_en);
    always @(posedge clk) begin
        if(!rst) begin
            pc_addr_o           <= 32'b0;
            regs_wen_o          <= 1'b0;
            inst_o              <= `NOP;
            value1_o            <= 32'b0;
            value2_o            <= 32'b0;
            jump1_o             <= 32'b0;
            jump2_o             <= 32'b0;
            rd_addr_o           <= 5'b0;
            rs1_addr_o          <= 5'b0;
            rs2_addr_o          <= 5'b0;
            pred_taken_o        <= 1'b0;
            inst_packaged_o     <= {`OP_INST_NUM{1'b0}};
            valid_o             <= 1'b0;
            fwd_rs1_data_o      <= 32'b0;
            fwd_rs2_data_o      <= 32'b0;
            fwd_rs1_hit_ex_o    <= 1'b0;
            fwd_rs2_hit_ex_o    <= 1'b0;
            ecall_o             <= 1'b0;
            mret_o              <= 1'b0;
            csr_addr_o          <= 12'b0;
        end
        else if(id_ex_ecall_mret_flush) begin
            pc_addr_o           <= 32'b0;
            regs_wen_o          <= 1'b0;
            inst_o              <= `NOP;
            value1_o            <= 32'b0;
            value2_o            <= 32'b0;
            jump1_o             <= 32'b0;
            jump2_o             <= 32'b0;
            rd_addr_o           <= 5'b0;
            rs1_addr_o          <= 5'b0;
            rs2_addr_o          <= 5'b0;
            pred_taken_o        <= 1'b0;
            inst_packaged_o     <= {`OP_INST_NUM{1'b0}};
            valid_o             <= 1'b0;
            fwd_rs1_data_o      <= 32'b0;
            fwd_rs2_data_o      <= 32'b0;
            fwd_rs1_hit_ex_o    <= 1'b0;
            fwd_rs2_hit_ex_o    <= 1'b0;
            ecall_o             <= 1'b0;    // ecall_flush 信号来自 wb，当发生 ecall 时，清空 id_ex 寄存器，防止错误执行
            mret_o              <= 1'b0;    // mret_flush 信号来自 wb，当发生 mret 时，清空 id_ex 寄存器，防止错误执行
            csr_addr_o          <= 12'b0;
        end
        else if (id_ex_hold_en) begin
            // ..
        end
        else begin
            pc_addr_o           <= pc_addr_i;
            regs_wen_o          <= regs_wen_i & id_ex_flush_en_n;
            inst_o              <= inst_i;
            value1_o            <= value1_i;
            value2_o            <= value2_i;
            jump1_o             <= jump1_i;
            jump2_o             <= jump2_i;
            rd_addr_o           <= rd_addr_i;
            rs1_addr_o          <= rs1_addr_i;
            rs2_addr_o          <= rs2_addr_i;
            pred_taken_o        <= pred_taken_i;
            inst_packaged_o     <= inst_packaged_i & {`OP_INST_NUM{id_ex_flush_en_n}};
            valid_o             <= id_ex_flush_en_n;
            fwd_rs1_data_o      <= fwd_rs1_data_i;
            fwd_rs2_data_o      <= fwd_rs2_data_i;
            fwd_rs1_hit_ex_o    <= fwd_rs1_hit_ex_i;
            fwd_rs2_hit_ex_o    <= fwd_rs2_hit_ex_i;
            ecall_o             <= ecall_i;
            mret_o              <= mret_i;
            csr_addr_o          <= csr_addr_i;
        end
    end
endmodule