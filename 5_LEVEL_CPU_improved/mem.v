`include "rv32I.vh"

module mem(
    // from ex_mem
    input      [31:0]   inst_i,
    input      [31:0]   mem_addr_i,
    input               mem_req,
    input               mem_wen,
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen,
    input      [31:0]   rs2_data_i,

    // from DRAM
    input      [31:0]   perip_rdata,

    // to DRAM
    output     [31:0]   perip_addr,
    output     [1:0]    perip_mask,
    output     [31:0]   perip_wdata,
    output              perip_wen,

    // to mem_wb
    output     [31:0]   rd_data_o,
    output              regs_wen_o,

    // to mem_wb and hazard
    output     [4:0]    rd_addr_o
);

    wire [6:0] opcode;
    wire [2:0] funct3;

    assign opcode = inst_i[6:0];
    assign funct3 = inst_i[14:12];

    wire is_load;
    wire is_store;

    assign is_load  = opcode == `TYPE_L;
    assign is_store = opcode == `TYPE_S;

    wire is_lb;
    wire is_lh;
    wire is_lw;
    wire is_lbu;
    wire is_lhu;

    assign is_lb  = is_load  && (funct3 == `LB);
    assign is_lh  = is_load  && (funct3 == `LH);
    assign is_lw  = is_load  && (funct3 == `LW);
    assign is_lbu = is_load  && (funct3 == `LBU);
    assign is_lhu = is_load  && (funct3 == `LHU);

    wire is_sb;
    wire is_sh;
    wire is_sw;

    assign is_sb = is_store && (funct3 == `SB);
    assign is_sh = is_store && (funct3 == `SH);
    assign is_sw = is_store && (funct3 == `SW);

    wire valid_load;
    wire valid_store;

    assign valid_load  = is_lb | is_lh | is_lw | is_lbu | is_lhu;
    assign valid_store = is_sb | is_sh | is_sw;

    assign perip_addr  = mem_addr_i;
    assign perip_wen   = mem_req && mem_wen;
    assign perip_wdata = valid_store ? rs2_data_i : 32'b0;

    assign perip_mask =
        (is_lw | is_sw)             ? 2'b10 :
        (is_lh | is_lhu | is_sh)    ? 2'b01 :
                                      2'b00;

    wire [31:0] load_data;

    assign load_data[7:0] = perip_rdata[7:0];

    assign load_data[15:8] =
        is_lb              ? {8{perip_rdata[7]}} :
        is_lbu             ? 8'b0 :
                              perip_rdata[15:8];

    assign load_data[31:16] =
        is_lb              ? {16{perip_rdata[7]}} :
        is_lh              ? {16{perip_rdata[15]}} :
        is_lw              ? perip_rdata[31:16] :
                              16'b0;

    assign rd_data_o =
        is_load ? (valid_load ? load_data : 32'b0) :
                  rd_data_i;

    assign rd_addr_o  = rd_addr_i;
    assign regs_wen_o = regs_wen;

endmodule