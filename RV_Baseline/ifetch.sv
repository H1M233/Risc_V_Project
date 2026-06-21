`include "rv32I.svh"
`include "alu_def.svh"

module ifetch(
    input  logic        clk,
    input  logic        rst,

    // ctrl
    input  logic        pipe_hold,
    input  logic        pipe_flush,

    // from pc
    input  logic [31:0] pc_i,

    // from icache
    input      [31:0]   inst_i,

    // to bpu & icache
    output logic [31:0] if1_pc_o,

    // to if_id
    output if_id_t      data_packaged_o
);
    // if1
    logic [31:0] if1_if2_pc_i;
    assign if1_if2_pc_i = pc_i;
    assign if1_pc_o     = if1_if2_pc_i;

    // if1_if2
    logic [31:0] if1_if2_pc_o;
    always_ff @(posedge clk) begin
        if (!rst) begin
            if1_if2_pc_o <= 32'h0;
        end
        else if (pipe_hold) begin
            // ...
        end
        else if (pipe_flush) begin
            if1_if2_pc_o <= 32'b0;
        end
        else begin
            if1_if2_pc_o <= if1_if2_pc_i;
        end
    end

    // if2
    assign data_packaged_o.pc       = if1_if2_pc_o;
    assign data_packaged_o.inst     = inst_i;

    // 预译码
    assign data_packaged_o.opcode   = inst_i[6:0];
    assign data_packaged_o.funct3   = inst_i[14:12];
    assign data_packaged_o.funct7   = inst_i[31:25];
    assign data_packaged_o.rd       = inst_i[11:7];
    assign data_packaged_o.rs1      = inst_i[19:15];
    assign data_packaged_o.rs2      = inst_i[24:20];

endmodule