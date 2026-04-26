`include "rv32I.vh"

module mem(
    input      [31:0]   inst_i,
    input      [31:0]   mem_addr_i,
    input               mem_req,
    input               mem_wen,
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen,
    input      [31:0]   rs2_data_i,

    input      [31:0]   perip_rdata,

    output     [31:0]   perip_addr,
    output     [1:0]    perip_mask,
    output     [31:0]   perip_wdata,
    output              perip_wen,

    output     [31:0]   inst_o,
    output     [4:0]    rd_addr_o,
    output     [31:0]   alu_data_o,
    output     [31:0]   mem_data_o,
    output              regs_wen_o
);

    wire [6:0] opcode;
    wire [2:0] funct3;

    assign opcode = inst_i[6:0];
    assign funct3 = inst_i[14:12];

    wire is_load;
    wire is_store;

    assign is_load  = opcode == `TYPE_L;
    assign is_store = opcode == `TYPE_S;

    wire is_lh;
    wire is_lw;
    wire is_lhu;
    wire is_sh;
    wire is_sw;

    assign is_lh  = is_load  && (funct3 == `LH);
    assign is_lw  = is_load  && (funct3 == `LW);
    assign is_lhu = is_load  && (funct3 == `LHU);
    assign is_sh  = is_store && (funct3 == `SH);
    assign is_sw  = is_store && (funct3 == `SW);

    assign perip_addr  = mem_addr_i;
    assign perip_wen   = mem_req && mem_wen;
    assign perip_wdata = is_store ? rs2_data_i : 32'b0;

    assign perip_mask =
        (is_lw | is_sw)          ? 2'b10 :
        (is_lh | is_lhu | is_sh) ? 2'b01 :
                                   2'b00;

    assign inst_o      = inst_i;
    assign rd_addr_o   = rd_addr_i;
    assign alu_data_o  = rd_data_i;
    assign mem_data_o  = perip_rdata;
    assign regs_wen_o  = regs_wen;

endmodule