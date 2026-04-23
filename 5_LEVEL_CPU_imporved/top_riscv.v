`include "rv32I.vh"

module top_riscv(
    input           cpu_rst,
    input           cpu_clk,

    // from IROM
    output  [31:0]  irom_addr,
    input   [31:0]  irom_data,

    // to DROM
    output  [31:0]  perip_addr,
    output          perip_wen,
    output  [1:0]   perip_mask,
    output  [31:0]  perip_wdata,
    input   [31:0]  perip_rdata
);

    // pc to IROM
    wire [31:0]     pc_pc_addr_o;
    assign irom_addr = pc_pc_addr_o; // 将pc模块输出的地址连接到irom_addr，供指令存储器使用

    // jump to if_id, id_ex, pc
    wire            jump_jump_en_o;

    // jump to pc
    wire [31:0]     jump_jump_addr_o;

    // hazard to if_id, id_ex, pc
    wire            hazard_hazard_en;

    // hazard to id
    wire            hazard_forward_rs1_en;
    wire            hazard_forward_rs2_en;
    wire [31:0]     hazard_forward_rs1_data;
    wire [31:0]     hazard_forward_rs2_data;

    // reg to id
    wire [31:0]     reg_rs1_data_o;
    wire [31:0]     reg_rs2_data_o;

    // if to if_id & bpu
    wire [31:0]     if_pc_addr_o;
    wire [31:0]     if_inst_o;
    wire            if_pred_taken_o;
    wire [31:0]     if_pred_pc_o;

    // if_id to id
    wire [31:0]     id_pc_addr_i;
    wire [31:0]     id_inst_i;
    wire            id_pred_taken_i;
    wire [31:0]     id_pred_pc_i;

    // id to id_ex
    wire [31:0]     id_pc_addr_o;
    wire [31:0]     id_inst_o;
    wire [31:0]     id_value1_o;
    wire [31:0]     id_value2_o;
    wire [31:0]     id_jump1_o;
    wire [31:0]     id_jump2_o;
    wire            id_reg_wen;
    wire [31:0]     id_rs1_data_o;
    wire [31:0]     id_rs2_data_o;
    wire [4:0]      id_rs1_addr_o;
    wire [4:0]      id_rs2_addr_o;
    wire [4:0]      id_rd_addr_o;
    wire            id_pred_taken_o;
    wire [31:0]     id_pred_pc_o;

    // id_ex to ex
    wire [31:0]     ex_pc_addr_i;
    wire            ex_regs_wen_i;
    wire [31:0]     ex_inst_i;
    wire [31:0]     ex_value1_i;
    wire [31:0]     ex_value2_i;
    wire [31:0]     ex_jump1_i;
    wire [31:0]     ex_jump2_i;
    wire [4:0]      ex_rd_addr_i;
    wire [31:0]     ex_rs1_data_i;
    wire [31:0]     ex_rs2_data_i;
    wire            ex_pred_taken_i;
    wire [31:0]     ex_pred_pc_i;

    // ex to jump
    wire            ex_jump_en_o;
    wire [31:0]     ex_jump_addr_o;

    // ex to ex_mem
    wire            ex_regs_wen_o;
    wire [31:0]     ex_inst_o;
    wire            ex_mem_wen;
    wire            ex_mem_req;
    wire [31:0]     ex_mem_addr_o;
    wire [31:0]     ex_rs2_data_o;

    // ex to hazard
    wire [6:0]      ex_hazard_opcode_o;

    // 这俩端口暂时没用到
    wire [31:0]     ex_rs1_data_o;

    // ex to ex_mem & hazard
    wire [31:0]     ex_rd_data_o;
    wire [4:0]      ex_rd_addr_o;

    // ex_mem to mem
    wire [31:0]     mem_inst_i;
    wire            mem_mem_wen_i;
    wire            mem_mem_req_i;
    wire [31:0]     mem_mem_addr_i;
    wire            mem_regs_wen_i;
    wire [31:0]     mem_rd_data_i;
    wire [4:0]      mem_rd_addr_i;
    wire [31:0]     mem_rs2_data_i;

    // mem to mem_wb & hazard
    wire [31:0]     mem_rd_data_o;
    wire [4:0]      mem_rd_addr_o;

    // mem to mem_wb
    wire            mem_regs_wen_o;

    // mem_wb to wb
    wire [31:0]     wb_rd_data_i;
    wire [4:0]      wb_rd_addr_i;
    wire            wb_regs_wen_i;

    // wb to regs
    wire [31:0]     wb_rd_data_o;
    wire [4:0]      wb_rd_addr_o;
    wire            wb_regs_wen_o;

    // bpu to pc & if
    wire [31:0]     bpu_pred_pc;
    wire            bpu_pred_taken;

    // ex to bpu
    wire [1:0]      ex_pred_update_en;
    wire [31:0]     ex_pc_addr_o;
    wire [31:0]     ex_pred_update_target;
    wire            ex_actual_taken;
    wire            ex_pred_mispredict;

    // 连接各模块
    pc PC(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        // from hazard
        .hazard_en          (hazard_hazard_en),

        // from jump
        .jump_addr_i        (jump_jump_addr_o),
        .jump_en            (jump_jump_en_o),

        // to if & IROM
        .pc_addr_o          (pc_pc_addr_o),

        // from bpu
        .pred_pc            (bpu_pred_pc),
        .pred_taken         (bpu_pred_taken)
    );

    jump JUMP(
        // from ex
        .jump_addr_i        (ex_jump_addr_o),
        .jump_en_i          (ex_jump_en_o),

        // to pc
        .jump_addr_o        (jump_jump_addr_o),

        // to if_id, id_ex, pc
        .jump_en_o          (jump_jump_en_o)
    );

    hazard HAZARD(
        // from ex
        .ex_waddr_i         (ex_rd_addr_o),
        .ex_wdata_i         (ex_rd_data_o),
        .opcode             (ex_hazard_opcode_o),

        // from id
        .id_rs1_raddr_i     (id_rs1_addr_o),
        .id_rs2_raddr_i     (id_rs2_addr_o),

        // from mem
        .mem_waddr_i        (mem_rd_addr_o),
        .mem_wdata_i        (mem_rd_data_o),

        // to id
        .forward_rs1_data   (hazard_forward_rs1_data),
        .forward_rs1_en     (hazard_forward_rs1_en),
        .forward_rs2_data   (hazard_forward_rs2_data),
        .forward_rs2_en     (hazard_forward_rs2_en),

        // to if_id, id_ex, pc
        .hazard_en          (hazard_hazard_en)
    );

    regs REGS(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        // from wb
        .rd_addr_i          (wb_rd_addr_o),
        .rd_data_i          (wb_rd_data_o),
        .regs_wen           (wb_regs_wen_o),

        // from id
        .rs1_addr_i         (id_rs1_addr_o),
        .rs2_addr_i         (id_rs2_addr_o),

        // to id
        .rs1_data_o         (reg_rs1_data_o),
        .rs2_data_o         (reg_rs2_data_o)
    );

    ifif IFIF(
        // from IROM
        .inst_i             (irom_data),

        // from pc
        .pc_addr_i          (pc_pc_addr_o),

        // from bpu
        .pred_taken_i       (bpu_pred_taken),
        .pred_pc_i          (bpu_pred_pc),

        // to if_id
        .inst_o             (if_inst_o),
        .pc_addr_o          (if_pc_addr_o),
        .pred_taken_o       (if_pred_taken_o),
        .pred_pc_o          (if_pred_pc_o)
    );

    if_id IF_ID(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        // from hazard
        .hazard_en          (hazard_hazard_en),

        // from if
        .inst_i             (if_inst_o),
        .pc_addr_i          (if_pc_addr_o),
        .pred_taken_i       (if_pred_taken_o),
        .pred_pc_i          (if_pred_pc_o),

        // from jump
        .jump_en            (jump_jump_en_o),

        // to id
        .inst_o             (id_inst_i),
        .pc_addr_o          (id_pc_addr_i),
        .pred_taken_o       (id_pred_taken_i),
        .pred_pc_o          (id_pred_pc_i)
    );

    id ID(
        // from hazard
        .forward_rs1_data   (hazard_forward_rs1_data),
        .forward_rs1_en     (hazard_forward_rs1_en),
        .forward_rs2_data   (hazard_forward_rs2_data),
        .forward_rs2_en     (hazard_forward_rs2_en),

        // from if_id
        .inst_i             (id_inst_i),
        .pc_addr_i          (id_pc_addr_i),
        .pred_taken_i       (id_pred_taken_i),
        .pred_pc_i          (id_pred_pc_i),

        // from regs
        .rs1_data_i         (reg_rs1_data_o),
        .rs2_data_i         (reg_rs2_data_o),

        // to id_ex
        .pc_addr_o          (id_pc_addr_o),
        .inst_o             (id_inst_o),
        .jump1_o            (id_jump1_o),
        .jump2_o            (id_jump2_o),
        .rd_addr_o          (id_rd_addr_o),
        .reg_wen            (id_reg_wen),
        .rs1_data_o         (id_rs1_data_o),
        .rs2_data_o         (id_rs2_data_o),
        .value1_o           (id_value1_o),
        .value2_o           (id_value2_o),
        .pred_taken_o       (id_pred_taken_o),
        .pred_pc_o          (id_pred_pc_o),

        // to regs & hazard
        .rs1_addr_o         (id_rs1_addr_o),
        .rs2_addr_o         (id_rs2_addr_o)
    );

    id_ex ID_EX(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        // from hazard
        .hazard_en          (hazard_hazard_en),

        // from id
        .pc_addr_i          (id_pc_addr_o),
        .inst_i             (id_inst_o),
        .jump1_i            (id_jump1_o),
        .jump2_i            (id_jump2_o),
        .rd_addr_i          (id_rd_addr_o),
        .regs_wen_i         (id_reg_wen),
        .rs1_data_i         (id_rs1_data_o),
        .rs2_data_i         (id_rs2_data_o),
        .value1_i           (id_value1_o),
        .value2_i           (id_value2_o),
        .pred_taken_i       (id_pred_taken_o),
        .pred_pc_i          (id_pred_pc_o),

        // from jump
        .jump_en            (jump_jump_en_o),

        // to ex
        .pc_addr_o          (ex_pc_addr_i),
        .inst_o             (ex_inst_i),
        .jump1_o            (ex_jump1_i), 
        .jump2_o            (ex_jump2_i), 
        .rd_addr_o          (ex_rd_addr_i),
        .regs_wen_o         (ex_regs_wen_i),
        .rs1_data_o         (ex_rs1_data_i), 
        .rs2_data_o         (ex_rs2_data_i),
        .value1_o           (ex_value1_i),
        .value2_o           (ex_value2_i),
        .pred_taken_o       (ex_pred_taken_i),
        .pred_pc_o          (ex_pred_pc_i)
    );

    ex EX(
        // from id_ex
        .pc_addr_i          (ex_pc_addr_i),
        .inst_i             (ex_inst_i),
        .jump1_i            (ex_jump1_i),
        .jump2_i            (ex_jump2_i),
        .rd_addr_i          (ex_rd_addr_i),
        .regs_wen_i         (ex_regs_wen_i),
        .rs1_data_i         (ex_rs1_data_i),
        .rs2_data_i         (ex_rs2_data_i),
        .value1_i           (ex_value1_i),
        .value2_i           (ex_value2_i),
        .pred_taken_i       (ex_pred_taken_i),
        .pred_pc_i          (ex_pred_pc_i),

        // to hazard
        .hazard_opcode      (ex_hazard_opcode_o),

        // to ex_mem
        .inst_o             (ex_inst_o),
        .mem_addr_o         (ex_mem_addr_o),
        .mem_req            (ex_mem_req),
        .mem_wen            (ex_mem_wen),
        .regs_wen_o         (ex_regs_wen_o),
        .rs2_data_o         (ex_rs2_data_o),

        // to ex_mem & hazard
        .rd_addr_o          (ex_rd_addr_o),
        .rd_data_o          (ex_rd_data_o),

        // to jump
        .jump_en            (ex_jump_en_o),
        .jump_addr_o        (ex_jump_addr_o),

        // 没用上
        .rs1_data_o         (ex_rs1_data_o),

        // to Gshare
        .update_en          (ex_pred_update_en),
        .pc_addr_o          (ex_pc_addr_o),
        .update_target      (ex_pred_update_target),
        .actual_taken       (ex_actual_taken),
        .pred_mispredict    (ex_pred_mispredict)
    );

    ex_mem EX_MEM(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        // from ex
        .inst_i             (ex_inst_o),
        .mem_addr_i         (ex_mem_addr_o),
        .mem_req_i          (ex_mem_req),
        .mem_wen_i          (ex_mem_wen),
        .rd_addr_i          (ex_rd_addr_o),
        .rd_data_i          (ex_rd_data_o),
        .regs_wen_i         (ex_regs_wen_o),
        .rs2_data_i         (ex_rs2_data_o),

        // to mem
        .inst_o             (mem_inst_i),
        .mem_addr_o         (mem_mem_addr_i),
        .mem_req_o          (mem_mem_req_i),
        .mem_wen_o          (mem_mem_wen_i),
        .rd_addr_o          (mem_rd_addr_i),
        .rd_data_o          (mem_rd_data_i),
        .regs_wen_o         (mem_regs_wen_i),
        .rs2_data_o         (mem_rs2_data_i)
    );

    mem MEM(
        // from ex_mem
        .inst_i             (mem_inst_i),
        .mem_addr_i         (mem_mem_addr_i),
        .mem_req            (mem_mem_req_i),
        .mem_wen            (mem_mem_wen_i),
        .rd_addr_i          (mem_rd_addr_i),
        .rd_data_i          (mem_rd_data_i),
        .regs_wen           (mem_regs_wen_i),
        .rs2_data_i         (mem_rs2_data_i),

        // from DRAM
        .perip_rdata        (perip_rdata),

        // to DRAM
        .perip_addr         (perip_addr),
        .perip_mask         (perip_mask),
        .perip_wdata        (perip_wdata),
        .perip_wen          (perip_wen),

        // to mem_wb
        .rd_data_o          (mem_rd_data_o),
        .regs_wen_o         (mem_regs_wen_o),

        // to mem_wb & hazard
        .rd_addr_o          (mem_rd_addr_o)
    );

    mem_wb MEM_WB(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        // from mem
        .rd_addr_i          (mem_rd_addr_o),
        .rd_data_i          (mem_rd_data_o),
        .regs_wen_i         (mem_regs_wen_o),

        // to wb
        .rd_addr_o          (wb_rd_addr_i),
        .rd_data_o          (wb_rd_data_i),
        .regs_wen_o         (wb_regs_wen_i)
    );

    wb WB(
        // from mem_wb
        .rd_addr_i          (wb_rd_addr_i),
        .rd_data_i          (wb_rd_data_i),
        .regs_wen_i         (wb_regs_wen_i),

        // to regs
        .rd_addr_o          (wb_rd_addr_o),
        .rd_data_o          (wb_rd_data_o),
        .regs_wen_o         (wb_regs_wen_o)
    );

    bpu #(
        .BHR_WIDTH  (10),
        .PHT_SIZE   (1024),
        .RAS_DEPTH  (8)
    ) BPU(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        // from if
        .pc_addr            (if_pc_addr_o),
        .pc_inst            (if_inst_o),

        // to pc & if
        .pred_pc            (bpu_pred_pc),
        .pred_taken         (bpu_pred_taken),

        // from ex
        .update_en          (ex_pred_update_en),
        .update_pc          (ex_pc_addr_o),
        .update_target      (ex_pred_update_target),
        .actual_taken       (ex_actual_taken),
        .pred_mispredict    (ex_pred_mispredict)
    );
endmodule