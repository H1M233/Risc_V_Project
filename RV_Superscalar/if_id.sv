`include "rv32I.vh"

module if_id(
    input               clk,
    input               rst,
    input               pipe_hold,
    input               pipe_flush,

    // from wb
    input               ecall_flush,
    input               mret_flush,

    // from if
    input      [31:0]   slot0_pc_i,
    input      [31:0]   slot0_inst_i,
    input      [6:0]    slot0_opcode_i,
    input      [2:0]    slot0_funct3_i,
    input      [6:0]    slot0_funct7_i,
    input      [4:0]    slot0_rd_i,
    input      [4:0]    slot0_rs1_i,
    input      [4:0]    slot0_rs2_i,
    
    input      [31:0]   slot1_pc_i,
    input      [31:0]   slot1_inst_i,
    input      [6:0]    slot1_opcode_i,
    input      [2:0]    slot1_funct3_i,
    input      [6:0]    slot1_funct7_i,
    input      [4:0]    slot1_rd_i,
    input      [4:0]    slot1_rs1_i,
    input      [4:0]    slot1_rs2_i,

    // to id
    (* max_fanout = 30 *) output reg [31:0]   slot0_pc_o,
    (* max_fanout = 30 *) output reg [31:0]   slot0_inst_o,
    (* max_fanout = 30 *) output reg [6:0]    slot0_opcode_o,
    (* max_fanout = 30 *) output reg [2:0]    slot0_funct3_o,
    (* max_fanout = 30 *) output reg [6:0]    slot0_funct7_o,
    (* max_fanout = 30 *) output reg [4:0]    slot0_rd_o,
    (* max_fanout = 30 *) output reg [4:0]    slot0_rs1_o,
    (* max_fanout = 30 *) output reg [4:0]    slot0_rs2_o,

    (* max_fanout = 30 *) output reg [31:0]   slot1_pc_o,
    (* max_fanout = 30 *) output reg [31:0]   slot1_inst_o,
    (* max_fanout = 30 *) output reg [6:0]    slot1_opcode_o,
    (* max_fanout = 30 *) output reg [2:0]    slot1_funct3_o,
    (* max_fanout = 30 *) output reg [6:0]    slot1_funct7_o,
    (* max_fanout = 30 *) output reg [4:0]    slot1_rd_o,
    (* max_fanout = 30 *) output reg [4:0]    slot1_rs1_o,
    (* max_fanout = 30 *) output reg [4:0]    slot1_rs2_o

);
    wire if2_id_flush_en = (ecall_flush | mret_flush);

    always_ff @(posedge clk) begin
        if (!rst) begin
            slot0_pc_o        <= 32'b0;
            slot0_inst_o      <= `NOP;
            slot0_opcode_o    <= 7'b0;
            slot0_funct3_o    <= 3'b0;
            slot0_funct7_o    <= 7'b0;
            slot0_rd_o        <= 5'b0;
            slot0_rs1_o       <= 5'b0;
            slot0_rs2_o       <= 5'b0;

            slot1_pc_o        <= 32'b0;
            slot1_inst_o      <= `NOP;
            slot1_opcode_o    <= 7'b0;
            slot1_funct3_o    <= 3'b0;
            slot1_funct7_o    <= 7'b0;
            slot1_rd_o        <= 5'b0;
            slot1_rs1_o       <= 5'b0;
            slot1_rs2_o       <= 5'b0;
        end
        else if(if2_id_flush_en) begin
            slot0_pc_o        <= 32'b0;
            slot0_inst_o      <= `NOP;
            slot0_opcode_o    <= 7'b0;
            slot0_funct3_o    <= 3'b0;
            slot0_funct7_o    <= 7'b0;
            slot0_rd_o        <= 5'b0;
            slot0_rs1_o       <= 5'b0;
            slot0_rs2_o       <= 5'b0;

            slot1_pc_o        <= 32'b0;
            slot1_inst_o      <= `NOP;
            slot1_opcode_o    <= 7'b0;
            slot1_funct3_o    <= 3'b0;
            slot1_funct7_o    <= 7'b0;
            slot1_rd_o        <= 5'b0;
            slot1_rs1_o       <= 5'b0;
            slot1_rs2_o       <= 5'b0;
        end
        else if (pipe_hold) begin
            // ...
        end
        else if (pipe_flush) begin
            slot0_pc_o        <= 32'b0;
            slot0_inst_o      <= `NOP;
            slot0_opcode_o    <= 7'b0;
            slot0_funct3_o    <= 3'b0;
            slot0_funct7_o    <= 7'b0;
            slot0_rd_o        <= 5'b0;
            slot0_rs1_o       <= 5'b0;
            slot0_rs2_o       <= 5'b0;
            
            slot1_pc_o        <= 32'b0;
            slot1_inst_o      <= `NOP;
            slot1_opcode_o    <= 7'b0;
            slot1_funct3_o    <= 3'b0;
            slot1_funct7_o    <= 7'b0;
            slot1_rd_o        <= 5'b0;
            slot1_rs1_o       <= 5'b0;
            slot1_rs2_o       <= 5'b0;
        end
        else begin
            slot0_pc_o        <= slot0_pc_i;
            slot0_inst_o      <= slot0_inst_i;
            slot0_opcode_o    <= slot0_opcode_i;
            slot0_funct3_o    <= slot0_funct3_i;
            slot0_funct7_o    <= slot0_funct7_i;
            slot0_rd_o        <= slot0_rd_i;
            slot0_rs1_o       <= slot0_rs1_i;
            slot0_rs2_o       <= slot0_rs2_i;

            slot1_pc_o        <= slot1_pc_i;
            slot1_inst_o      <= slot1_inst_i;
            slot1_opcode_o    <= slot1_opcode_i;
            slot1_funct3_o    <= slot1_funct3_i;
            slot1_funct7_o    <= slot1_funct7_i;
            slot1_rd_o        <= slot1_rd_i;
            slot1_rs1_o       <= slot1_rs1_i;
            slot1_rs2_o       <= slot1_rs2_i;
        end
    end
endmodule