`include "rv32I.vh"

module mem2(
    input      [31:0]   inst_i,
    input      [4:0]    rd_addr_i,
    input      [31:0]   alu_data_i,
    input      [31:0]   mem_data_i,
    input               regs_wen_i,

    output     [4:0]    rd_addr_o,
    output     [31:0]   rd_data_o,
    output              regs_wen_o
);

    wire [6:0] opcode;
    wire [2:0] funct3;

    assign opcode = inst_i[6:0];
    assign funct3 = inst_i[14:12];

    wire is_load;
    wire is_lb;
    wire is_lh;
    wire is_lw;
    wire is_lbu;
    wire is_lhu;

    assign is_load = opcode == `TYPE_L;
    assign is_lb   = is_load && (funct3 == `LB);
    assign is_lh   = is_load && (funct3 == `LH);
    assign is_lw   = is_load && (funct3 == `LW);
    assign is_lbu  = is_load && (funct3 == `LBU);
    assign is_lhu  = is_load && (funct3 == `LHU);

    wire [31:0] load_data;

    assign load_data[7:0] = mem_data_i[7:0];

    assign load_data[15:8] =
        is_lb  ? {8{mem_data_i[7]}} :
        is_lbu ? 8'b0 :
                 mem_data_i[15:8];

    assign load_data[31:16] =
        is_lb  ? {16{mem_data_i[7]}}  :
        is_lh  ? {16{mem_data_i[15]}} :
        is_lw  ? mem_data_i[31:16]    :
                 16'b0;

    assign rd_data_o  = is_load ? load_data : alu_data_i;
    assign rd_addr_o  = rd_addr_i;
    assign regs_wen_o = regs_wen_i;

endmodule