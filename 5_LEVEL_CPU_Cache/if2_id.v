`include "rv32I.vh"

module if2_id(
    input               clk,
    input               rst,
    input               pred_taken,
    input               pred_flush,
    (* max_fanout = 30 *)
    input               pipe_hold,

    // from if
    input      [31:0]   inst_i,
    input      [31:0]   pc_i,
    input      [6:0]    opcode_i,
    input      [2:0]    funct3_i,
    input      [6:0]    funct7_i,
    input      [4:0]    rd_i,
    input      [4:0]    rs1_i,
    input      [4:0]    rs2_i,

    // from wb
    input               ecall_flush,
    input               mret_flush,

    // to id
    (* max_fanout = 30 *) output reg [31:0]   inst_o,
    (* max_fanout = 30 *) output reg [31:0]   pc_o,
    (* max_fanout = 30 *) output reg [6:0]    opcode_o,
    (* max_fanout = 30 *) output reg [2:0]    funct3_o,
    (* max_fanout = 30 *) output reg [6:0]    funct7_o,
    (* max_fanout = 30 *) output reg [4:0]    rd_o,
    (* max_fanout = 30 *) output reg [4:0]    rs1_o,
    (* max_fanout = 30 *) output reg [4:0]    rs2_o

);
    wire if2_id_hold_en = pipe_hold;
    wire if2_id_flush_en = (ecall_flush | mret_flush | pred_taken | pred_flush);
    always @(posedge clk) begin
        if (!rst) begin
            pc_o        <= 32'b0;
            inst_o      <= `NOP;
            opcode_o    <= 7'b0;
            funct3_o    <= 3'b0;
            funct7_o    <= 7'b0;
            rd_o        <= 5'b0;
            rs1_o       <= 5'b0;
            rs2_o       <= 5'b0;
        end
        else if (if2_id_hold_en) begin
            // ...
        end
        else if (if2_id_flush_en) begin
            pc_o        <= 32'b0;
            inst_o      <= `NOP;
            opcode_o    <= 7'b0;
            funct3_o    <= 3'b0;
            funct7_o    <= 7'b0;
            rd_o        <= 5'b0;
            rs1_o       <= 5'b0;
            rs2_o       <= 5'b0;
        end
        else begin
            pc_o        <= pc_i;
            inst_o      <= inst_i;
            opcode_o    <= opcode_i;
            funct3_o    <= funct3_i;
            funct7_o    <= funct7_i;
            rd_o        <= rd_i;
            rs1_o       <= rs1_i;
            rs2_o       <= rs2_i;
        end
    end
endmodule