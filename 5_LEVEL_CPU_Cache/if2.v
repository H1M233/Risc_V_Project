`include "rv32I.vh"

module if2(
    // from if1_if2
    input      [31:0]   pc_i,

    // from icache
    input      [31:0]   inst_i,

    // to if_id & bpu
    (* max_fanout = 30 *)
    output reg [31:0]   pc_o,
    (* max_fanout = 30 *)
    output reg [31:0]   inst_o,
    output reg [6:0]    opcode_o,
    output reg [2:0]    funct3_o,
    output reg [6:0]    funct7_o,
    output reg [4:0]    rd_o,
    output reg [4:0]    rs1_o,
    output reg [4:0]    rs2_o
);
    always @(*) begin
        pc_o    = pc_i;
        inst_o  = inst_i;

        // 预译码
        opcode_o  = inst_o[6:0];
        funct3_o  = inst_o[14:12];
        funct7_o  = inst_o[31:25];
        rd_o      = inst_o[11:7];
        rs1_o     = inst_o[19:15];
        rs2_o     = inst_o[24:20];
    end
endmodule