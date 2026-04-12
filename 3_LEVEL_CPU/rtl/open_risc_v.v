module open_risc_v(
    input   wire        clk,
    input   wire        rst,

    // rom
    input   wire[31:0]  inst_i,
    output  wire[31:0]  inst_addr_o,

    // ram - read
    output  wire        ram_r_en_o,
    output  wire[31:0]  ram_r_addr_o,
    input   wire[31:0]  ram_r_data_i,

    // ram - write
    output  wire[3:0]   ram_w_en_o,
    output  wire[31:0]  ram_w_addr_o,
    output  wire[31:0]  ram_w_data_o
);
    // pc to if
    wire[31:0]  pc_reg_o;

    // if to if_id
    wire[31:0]  if_inst_addr_o;
    wire[31:0]  if_inst_o;

    // if_id to id
    wire[31:0]  if_id_inst_addr_o;
    wire[31:0]  if_id_inst_o;

    // id to regs
    wire[4:0]   id_rs1_addr_o;
    wire[4:0]   id_rs2_addr_o;

    // id to id_ex
    wire[31:0]  id_inst_addr_o;
    wire[31:0]  id_inst_o;
    wire[31:0]  id_op1_o;
    wire[31:0]  id_op2_o;
    wire[4:0]   id_rd_addr_o;
    wire        id_rd_wen_o;
    wire[31:0]  id_base_addr;
    wire[31:0]  id_addr_offest;

    // id_ex to ex
    wire[31:0]  id_ex_inst_addr_o;
    wire[31:0]  id_ex_inst_o;
    wire[31:0]  id_ex_op1_o;
    wire[31:0]  id_ex_op2_o;
    wire[4:0]   id_ex_rd_addr_o;
    wire        id_ex_rd_wen_o;
    wire[31:0]  id_ex_base_addr;
    wire[31:0]  id_ex_addr_offest;

    // regs to id
    wire[31:0]  regs_rs1_rdata_o;
    wire[31:0]  regs_rs2_rdata_o;

    // ex to regs
    wire[4:0]   ex_rd_addr_o;
    wire[31:0]  ex_rd_data_o;
    wire        ex_rd_wen_o;

    // ex to ctrl
    wire[31:0]  ex_jump_addr_o;
    wire        ex_jump_en_o;
    wire        ex_hold_flag_o;

    // ctrl to pc_reg
    wire[31:0]  ctrl_jump_addr_o;
    wire        ctrl_jump_en_o;

    // ctrl to if_id id_ex
    wire        ctrl_hold_flag_o;

    pc_reg pc_reg_inst(
        .clk            (clk),
        .rst            (rst),
        .jump_addr_i    (ctrl_jump_addr_o),
        .jump_en_i      (ctrl_jump_en_o),
        // .hold_flag_i    (ctrl_hold_flag_o),
        .pc_addr_o      (pc_reg_o)
    );

    ifetch ifetch_inst(
        .pc_addr_i      (pc_reg_o),
        .rom_inst_i     (inst_i),
        .if2rom_addr_o  (inst_addr_o),
        .inst_addr_o    (if_inst_addr_o),
        .inst_o         (if_inst_o)
    );

    if_id if_id_inst(
        .clk            (clk),
        .rst            (rst),
        .hold_flag_i    (ctrl_hold_flag_o),
        .inst_addr_i    (if_inst_addr_o),
        .inst_i         (if_inst_o),
        .inst_addr_o    (if_id_inst_addr_o),
        .inst_o         (if_id_inst_o)
    );

    id id_inst(
        .inst_addr_i    (if_id_inst_addr_o),
        .inst_i         (if_id_inst_o),
        .rs1_addr_o     (id_rs1_addr_o),
        .rs2_addr_o     (id_rs2_addr_o),
        .rs1_data_i     (regs_rs1_rdata_o),
        .rs2_data_i     (regs_rs2_rdata_o),
        .inst_addr_o    (id_inst_addr_o),
        .inst_o         (id_inst_o),
        .op1_o          (id_op1_o),
        .op2_o          (id_op2_o),
        .rd_addr_o      (id_rd_addr_o),
        .rd_wen_o       (id_rd_wen_o),
        .base_addr_o    (id_base_addr),
        .addr_offest_o  (id_addr_offest),
        .mem_r_addr_o   (ram_r_addr_o),
        .mem_r_req_o    (ram_r_en_o)
    );

    regs regs_inst(
        .clk            (clk),
        .rst            (rst),
        .rs1_raddr_i    (id_rs1_addr_o),
        .rs2_raddr_i    (id_rs2_addr_o),
        .rs1_rdata_o    (regs_rs1_rdata_o),
        .rs2_rdata_o    (regs_rs2_rdata_o),
        .rd_waddr_i     (ex_rd_addr_o),
        .rd_wdata_i     (ex_rd_data_o),
        .rd_wen_i       (ex_rd_wen_o)
    );

    id_ex id_ex_inst(
        .clk            (clk),
        .rst            (rst),
        .hold_flag_i    (ctrl_hold_flag_o),
        .inst_addr_i    (id_inst_addr_o),
        .inst_i         (id_inst_o),
        .op1_i          (id_op1_o),
        .op2_i          (id_op2_o),
        .rd_addr_i      (id_rd_addr_o),
        .rd_wen_i       (id_rd_wen_o),
        .base_addr_i    (id_base_addr),
        .addr_offest_i  (id_addr_offest),
        .inst_addr_o    (id_ex_inst_addr_o),
        .inst_o         (id_ex_inst_o),
        .op1_o          (id_ex_op1_o),
        .op2_o          (id_ex_op2_o),
        .rd_addr_o      (id_ex_rd_addr_o),
        .rd_wen_o       (id_ex_rd_wen_o),
        .base_addr_o    (id_ex_base_addr),
        .addr_offest_o  (id_ex_addr_offest)
    );

    ex ex_inst(
        .inst_addr_i    (id_ex_inst_addr_o),
        .inst_i         (id_ex_inst_o),
        .op1_i          (id_ex_op1_o),
        .op2_i          (id_ex_op2_o),
        .rd_addr_i      (id_ex_rd_addr_o),
        .rd_wen_i       (id_ex_rd_wen_o),
        .base_addr_i    (id_ex_base_addr),
        .addr_offest_i  (id_ex_addr_offest),
        .rd_addr_o      (ex_rd_addr_o),
        .rd_data_o      (ex_rd_data_o),
        .rd_wen_o       (ex_rd_wen_o),
        .jump_addr_o    (ex_jump_addr_o),
        .jump_en_o      (ex_jump_en_o),
        .hold_flag_o    (ex_hold_flag_o),
        .mem_w_sel_o    (ram_w_en_o),
        .mem_w_addr_o   (ram_w_addr_o),
        .mem_w_data_o   (ram_w_data_o),
        .mem_r_data_i   (ram_r_data_i)
    );
    
    ctrl ctrl_inst(
        .jump_addr_i    (ex_jump_addr_o),
        .jump_en_i      (ex_jump_en_o),
        .hold_flag_i    (ex_hold_flag_o),
        .jump_addr_o    (ctrl_jump_addr_o),
        .jump_en_o      (ctrl_jump_en_o),
        .hold_flag_o    (ctrl_hold_flag_o)
    );
endmodule