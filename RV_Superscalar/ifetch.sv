`include "rv32I.vh"

module ifetch(
    input               clk,
    input               rst,
    input               pipe_hold,
    input               pipe_flush,
    input               ecall_mret_flush,

    // from pc
    input      [31:0]   slot0_pc_i,
    input      [31:0]   slot1_pc_i,

    // to bpu & icache
    output     [31:0]   slot0_if1_pc_o,
    output     [31:0]   slot1_if1_pc_o,

    // from icache
    input      [31:0]   slot0_inst_i,
    input      [31:0]   slot1_inst_i,

    // to if_id & bpu
    output     [31:0]   slot0_pc_o,
    output     [31:0]   slot1_pc_o,
    output     [31:0]   slot0_inst_o,
    output     [31:0]   slot1_inst_o,

    // pre-id
    output     [6:0]    slot0_opcode_o,
    output     [2:0]    slot0_funct3_o,
    output     [6:0]    slot0_funct7_o,
    output     [4:0]    slot0_rd_o,
    output     [4:0]    slot0_rs1_o,
    output     [4:0]    slot0_rs2_o,
    output     [6:0]    slot1_opcode_o,
    output     [2:0]    slot1_funct3_o,
    output     [6:0]    slot1_funct7_o,
    output     [4:0]    slot1_rd_o,
    output     [4:0]    slot1_rs1_o,
    output     [4:0]    slot1_rs2_o
);
    logic [31:0] slot0_if1_if2_pc_i, slot0_if1_if2_pc_o;
    logic [31:0] slot1_if1_if2_pc_i, slot1_if1_if2_pc_o;

    // if1
    assign slot0_if1_if2_pc_i = slot0_pc_i;
    assign slot1_if1_if2_pc_i = slot1_pc_i;
    
    assign slot0_if1_pc_o = slot0_pc_i;
    assign slot1_if1_pc_o = slot1_pc_i;

    // if1_if2
    always_ff @(posedge clk) begin
        if (!rst) begin
            slot0_if1_if2_pc_o <= 32'b0;
            slot1_if1_if2_pc_o <= 32'b0;
        end
        else if (pipe_hold) begin
            // ...
        end
        else if (pipe_flush) begin
            slot0_if1_if2_pc_o <= 32'b0;
            slot1_if1_if2_pc_o <= 32'b0;
        end
        else begin
            slot0_if1_if2_pc_o <= slot0_if1_if2_pc_i;
            slot1_if1_if2_pc_o <= slot1_if1_if2_pc_i;
        end
    end

    // if2
    assign slot0_pc_o      = slot0_if1_if2_pc_o;
    assign slot1_pc_o      = slot1_if1_if2_pc_o;

    assign slot0_inst_o    = slot0_inst_i;
    assign slot1_inst_o    = slot1_inst_i;

    // 预译码
    assign slot0_opcode_o  = slot0_inst_o[6:0];
    assign slot0_funct3_o  = slot0_inst_o[14:12];
    assign slot0_funct7_o  = slot0_inst_o[31:25];
    assign slot0_rd_o      = slot0_inst_o[11:7];
    assign slot0_rs1_o     = slot0_inst_o[19:15];
    assign slot0_rs2_o     = slot0_inst_o[24:20];

    assign slot1_opcode_o  = slot1_inst_o[6:0];
    assign slot1_funct3_o  = slot1_inst_o[14:12];
    assign slot1_funct7_o  = slot1_inst_o[31:25];
    assign slot1_rd_o      = slot1_inst_o[11:7];
    assign slot1_rs1_o     = slot1_inst_o[19:15];
    assign slot1_rs2_o     = slot1_inst_o[24:20];
endmodule