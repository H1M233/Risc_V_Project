`include "rv32I.vh"

module top_riscv(
    input           cpu_rst,
    input           cpu_clk,

    // from IROM
    output  [31:0]  irom_addr,
    input   [31:0]  irom_data,

    // to DROM
    output  [31:0]  perip_addr,
    output  [3:0]   perip_we,
    output          perip_wen,
    output  [31:0]  perip_wdata,
    input   [31:0]  perip_rdata
);

    // ============================================================
    // PC / I-cache
    // ============================================================
    wire [31:0]     pc_pc_addr_o;

    wire [31:0]     icache_inst;
    wire            icache_stall;
    wire            icache_block;
    wire            icache_flush;

    // ============================================================
    // jump
    // ============================================================
    wire            jump_jump_en_o;
    wire [31:0]     jump_jump_addr_o;

    // ============================================================
    // hazard / stall
    // ============================================================
    wire            hazard_hazard_en;
    wire            dcache_stall;
    wire            bpu_hold_en;

    // ============================================================
    // hazard to id
    // ============================================================
    wire            hazard_forward_rs1_en;
    wire            hazard_forward_rs2_en;
    wire [31:0]     hazard_forward_rs1_data;
    wire [31:0]     hazard_forward_rs2_data;

    // ============================================================
    // regs to id
    // ============================================================
    wire [31:0]     reg_rs1_data_o;
    wire [31:0]     reg_rs2_data_o;

    // ============================================================
    // if to if_id & bpu
    // ============================================================
    wire [31:0]     if_pc_addr_o;
    wire [31:0]     if_inst_o;

    // ============================================================
    // if_id to id
    // ============================================================
    wire [31:0]     id_pc_addr_i;
    wire [31:0]     if_id_inst_raw;
    wire            if_id_valid_o;
    wire [31:0]     id_inst_i;

    assign id_inst_i = if_id_valid_o ? if_id_inst_raw : `NOP;

    // ============================================================
    // id to id_ex
    // ============================================================
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

    // ============================================================
    // ex to dcache
    // ============================================================
    wire [31:0]     dcache_addr_i;
    wire            dcache_req_load_i;
    wire            dcache_req_store_i;
    wire [1:0]      dcache_mask_i;
    wire [31:0]     dcache_wdata_i;

    // ============================================================
    // id_ex to ex
    // ============================================================
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
    wire [4:0]      ex_rs1_addr_i;
    wire [4:0]      ex_rs2_addr_i;
    wire            ex_pred_taken_i;
    wire [31:0]     ex_pred_pc_i;
    wire            ex_valid_i;

    // ============================================================
    // ex to jump
    // ============================================================
    wire            ex_jump_en_o;
    wire [31:0]     ex_jump_addr_o;

    // ============================================================
    // ex to ex_mem
    // ============================================================
    wire            ex_regs_wen_o;
    wire [31:0]     ex_inst_o;

    // ============================================================
    // ex to hazard
    // ============================================================
    wire [6:0]      ex_hazard_opcode_o;

    // unused
    wire [31:0]     ex_rs1_data_o;

    // ex to ex_mem & hazard
    wire [31:0]     ex_rd_data_o;
    wire [4:0]      ex_rd_addr_o;

    // ============================================================
    // ex_mem to mem
    // ============================================================
    wire [31:0]     mem_inst_i;
    wire            mem_regs_wen_i;
    wire [31:0]     mem_rd_data_i;
    wire [4:0]      mem_rd_addr_i;

    // ============================================================
    // mem to mem_wb
    // ============================================================
    wire [31:0]     mem_rd_data_o;
    wire [4:0]      mem_rd_addr_o;
    wire            mem_regs_wen_o;

    // ============================================================
    // mem to D-cache
    // ============================================================
    wire [31:0]     dcache_rdata;
    wire            dcache_ack_mem;

    // ============================================================
    // mem_wb to wb
    // ============================================================
    wire [31:0]     wb_rd_data_i;
    wire [4:0]      wb_rd_addr_i;
    wire            wb_regs_wen_i;

    // ============================================================
    // wb to regs
    // ============================================================
    wire [31:0]     wb_rd_data_o;
    wire [4:0]      wb_rd_addr_o;
    wire            wb_regs_wen_o;

    // ============================================================
    // bpu to pc & id
    // ============================================================
    wire [31:0]     bpu_pred_pc;
    wire            bpu_pred_taken;

    // I-cache 原始 miss 信号不能直接阻塞流水线。
    // jump 或 BPU 预测跳转时，当前 IF 指令会被冲刷，不应被错误路径 I-cache miss 卡住。
    assign icache_block = icache_stall & ~bpu_pred_taken & ~jump_jump_en_o;

    // BPU 在真正需要 hold 的时候暂停
    assign bpu_hold_en = dcache_stall | hazard_hazard_en | icache_block;

    // ============================================================
    // ex to bpu
    // ============================================================
    wire            ex_pred_update_btb_en;
    wire            ex_pred_update_gshare_en;
    wire [31:0]     ex_pc_addr_o;
    wire [31:0]     ex_pred_update_target;
    wire            ex_actual_taken;
    wire            ex_pred_mispredict;

    // ============================================================
    // PC
    // ============================================================
    pc PC(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .dcache_stall       (dcache_stall),
        .icache_block       (icache_block),

        .hazard_en          (hazard_hazard_en),

        .jump_addr_i        (jump_jump_addr_o),
        .jump_en            (jump_jump_en_o),

        .pc_addr_o          (pc_pc_addr_o),

        .pred_pc            (bpu_pred_pc),
        .pred_taken         (bpu_pred_taken),
        .icache_flush       (icache_flush)
    );

    // ============================================================
    // I-cache
    // ============================================================
    icache ICACHE(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .cpu_addr           (pc_pc_addr_o),
        .cpu_inst           (icache_inst),
        .flush              (icache_flush),
        .stall              (icache_stall),

        .mem_addr           (irom_addr),
        .mem_inst           (irom_data)
    );

    // ============================================================
    // Jump
    // ============================================================
    assign jump_jump_addr_o = ex_jump_addr_o;
    assign jump_jump_en_o   = ex_jump_en_o;

    // ============================================================
    // Hazard
    //
    // 关键修改：
    // mem_waddr_i 使用 mem_rd_addr_i
    // mem_wdata_i 使用 mem_rd_data_i
    //
    // 不再用 mem_rd_data_o，因为 mem_rd_data_o 对 load 会经过 DCache/DROM，
    // 那条路径就是现在的最差时序路径。
    // ============================================================
    hazard HAZARD(
        // from ex
        .ex_waddr_i         (ex_rd_addr_o),
        .opcode             (ex_hazard_opcode_o),
        .ex_regs_wen_i      (ex_regs_wen_o),

        // from id
        .id_opcode_i        (id_inst_i[6:0]),
        .id_rs1_raddr_i     (id_rs1_addr_o),
        .id_rs2_raddr_i     (id_rs2_addr_o),

        // from mem
        .mem_waddr_i        (mem_rd_addr_i),
        .mem_regs_wen_i     (mem_regs_wen_i),

        // to id
        .forward_rs1_data   (hazard_forward_rs1_data),
        .forward_rs1_en     (hazard_forward_rs1_en),
        .forward_rs2_data   (hazard_forward_rs2_data),
        .forward_rs2_en     (hazard_forward_rs2_en),

        // to if_id, id_ex, pc
        .hazard_en          (hazard_hazard_en)
    );

    // ============================================================
    // Regfile
    // ============================================================
    regs REGS(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .rd_addr_i          (wb_rd_addr_o),
        .rd_data_i          (wb_rd_data_o),
        .regs_wen           (wb_regs_wen_o),

        .rs1_addr_i         (id_rs1_addr_o),
        .rs2_addr_i         (id_rs2_addr_o),

        .rs1_data_o         (reg_rs1_data_o),
        .rs2_data_o         (reg_rs2_data_o)
    );

    // ============================================================
    // IF
    // ============================================================
    ifif IFIF(
        .inst_i             (icache_inst),
        .pc_addr_i          (pc_pc_addr_o),

        .inst_o             (if_inst_o),
        .pc_addr_o          (if_pc_addr_o)
    );

    // ============================================================
    // IF/ID
    // ============================================================
    if_id IF_ID(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .dcache_stall       (dcache_stall),
        .icache_block       (icache_block),

        .hazard_en          (hazard_hazard_en),

        .inst_i             (if_inst_o),
        .pc_addr_i          (if_pc_addr_o),

        .jump_en            (jump_jump_en_o),

        .inst_o             (if_id_inst_raw),
        .pc_addr_o          (id_pc_addr_i),
        .valid_o            (if_id_valid_o),

        .pred_taken         (bpu_pred_taken)
    );

    // ============================================================
    // ID
    // ============================================================
    id ID(
        .forward_rs1_data   (hazard_forward_rs1_data),
        .forward_rs1_en     (hazard_forward_rs1_en),
        .forward_rs2_data   (hazard_forward_rs2_data),
        .forward_rs2_en     (hazard_forward_rs2_en),

        .inst_i             (id_inst_i),
        .pc_addr_i          (id_pc_addr_i),

        .pred_taken_i       (bpu_pred_taken),
        .pred_pc_i          (bpu_pred_pc),

        .rs1_data_i         (reg_rs1_data_o),
        .rs2_data_i         (reg_rs2_data_o),

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

        .rs1_addr_o         (id_rs1_addr_o),
        .rs2_addr_o         (id_rs2_addr_o)
    );

    // ============================================================
    // ID/EX
    // ============================================================
    id_ex ID_EX(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .dcache_stall       (dcache_stall),
        .icache_block       (icache_block),

        .hazard_en          (hazard_hazard_en),

        .pc_addr_i          (id_pc_addr_o),
        .inst_i             (id_inst_o),
        .jump1_i            (id_jump1_o),
        .jump2_i            (id_jump2_o),
        .rd_addr_i          (id_rd_addr_o),
        .regs_wen_i         (id_reg_wen),
        .rs1_data_i         (id_rs1_data_o),
        .rs2_data_i         (id_rs2_data_o),
        .rs1_addr_i         (id_rs1_addr_o),
        .rs2_addr_i         (id_rs2_addr_o),
        .value1_i           (id_value1_o),
        .value2_i           (id_value2_o),
        .pred_taken_i       (id_pred_taken_o),
        .pred_pc_i          (id_pred_pc_o),

        .jump_en            (jump_jump_en_o),

        .pc_addr_o          (ex_pc_addr_i),
        .inst_o             (ex_inst_i),
        .jump1_o            (ex_jump1_i),
        .jump2_o            (ex_jump2_i),
        .rd_addr_o          (ex_rd_addr_i),
        .regs_wen_o         (ex_regs_wen_i),
        .rs1_data_o         (ex_rs1_data_i),
        .rs2_data_o         (ex_rs2_data_i),
        .rs1_addr_o         (ex_rs1_addr_i),
        .rs2_addr_o         (ex_rs2_addr_i),
        .value1_o           (ex_value1_i),
        .value2_o           (ex_value2_i),
        .pred_taken_o       (ex_pred_taken_i),
        .pred_pc_o          (ex_pred_pc_i),
        .valid_o            (ex_valid_i)
    );

    // ============================================================
    // EX
    // ============================================================
    ex EX(
        .pc_addr_i          (ex_pc_addr_i),
        .inst_i             (ex_inst_i),
        .jump1_i            (ex_jump1_i),
        .jump2_i            (ex_jump2_i),
        .rd_addr_i          (ex_rd_addr_i),
        .regs_wen_i         (ex_regs_wen_i),
        .rs1_data_i         (ex_rs1_data_i),
        .rs2_data_i         (ex_rs2_data_i),
        .rs1_addr_i         (ex_rs1_addr_i),
        .rs2_addr_i         (ex_rs2_addr_i),
        .value1_i           (ex_value1_i),
        .value2_i           (ex_value2_i),
        .pred_taken_i       (ex_pred_taken_i),
        .pred_pc_i          (ex_pred_pc_i),
        .valid_i            (ex_valid_i),

        .mem_forward_rd_addr_i  (mem_rd_addr_i),
        .mem_forward_rd_data_i  (mem_rd_data_i),
        .mem_forward_regs_wen_i (mem_regs_wen_i),
        .mem_forward_opcode_i   (mem_inst_i[6:0]),

        .wb_forward_rd_addr_i   (wb_rd_addr_i),
        .wb_forward_rd_data_i   (wb_rd_data_i),
        .wb_forward_regs_wen_i  (wb_regs_wen_i),

        .hazard_opcode      (ex_hazard_opcode_o),

        .inst_o             (ex_inst_o),
        .regs_wen_o         (ex_regs_wen_o),

        .rd_addr_o          (ex_rd_addr_o),
        .rd_data_o          (ex_rd_data_o),

        .jump_en            (ex_jump_en_o),
        .jump_addr_o        (ex_jump_addr_o),

        .rs1_data_o         (ex_rs1_data_o),

        .update_btb_en      (ex_pred_update_btb_en),
        .update_gshare_en   (ex_pred_update_gshare_en),
        .pc_addr_o          (ex_pc_addr_o),
        .update_target      (ex_pred_update_target),
        .actual_taken       (ex_actual_taken),
        .pred_mispredict    (ex_pred_mispredict),

        .dcache_req_load    (dcache_req_load_i),
        .dcache_req_store   (dcache_req_store_i),
        .dcache_mask        (dcache_mask_i),
        .dcache_addr        (dcache_addr_i),
        .dcache_wdata       (dcache_wdata_i)
    );

    // ============================================================
    // EX/MEM
    // ============================================================
    ex_mem EX_MEM(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .dcache_stall       (dcache_stall),

        .inst_i             (ex_inst_o),
        .rd_addr_i          (ex_rd_addr_o),
        .rd_data_i          (ex_rd_data_o),
        .regs_wen_i         (ex_regs_wen_o),

        .inst_o             (mem_inst_i),
        .rd_addr_o          (mem_rd_addr_i),
        .rd_data_o          (mem_rd_data_i),
        .regs_wen_o         (mem_regs_wen_i)
    );

    // ============================================================
    // MEM
    // ============================================================
    mem MEM(
        .inst_i             (mem_inst_i),
        .rd_addr_i          (mem_rd_addr_i),
        .rd_data_i          (mem_rd_data_i),
        .regs_wen           (mem_regs_wen_i),

        .perip_rdata        (dcache_rdata),

        .rd_data_o          (mem_rd_data_o),
        .regs_wen_o         (mem_regs_wen_o),

        .rd_addr_o          (mem_rd_addr_o),

        .dcache_ack         (dcache_ack_mem)
    );

    // ============================================================
    // D-cache
    // ============================================================
    dcache DCACHE(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .cpu_req_load       (dcache_req_load_i),
        .cpu_req_store      (dcache_req_store_i),
        .cpu_mask           (dcache_mask_i),
        .cpu_addr           (dcache_addr_i),
        .cpu_wdata          (dcache_wdata_i),
        .cpu_rdata          (dcache_rdata),
        .stall              (dcache_stall),

        .mem_addr           (perip_addr),
        .mem_we             (perip_we),
        .mem_wen            (perip_wen),
        .mem_wdata          (perip_wdata),
        .mem_rdata          (perip_rdata),

        .mem_ack            (dcache_ack_mem)
    );

    // ============================================================
    // MEM/WB
    // ============================================================
    mem_wb MEM_WB(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .rd_addr_i          (mem_rd_addr_o),
        .rd_data_i          (mem_rd_data_o),
        .regs_wen_i         (mem_regs_wen_o),

        .rd_addr_o          (wb_rd_addr_i),
        .rd_data_o          (wb_rd_data_i),
        .regs_wen_o         (wb_regs_wen_i)
    );

    // ============================================================
    // WB
    // ============================================================
    wb WB(
        .rd_addr_i          (wb_rd_addr_i),
        .rd_data_i          (wb_rd_data_i),
        .regs_wen_i         (wb_regs_wen_i),

        .rd_addr_o          (wb_rd_addr_o),
        .rd_data_o          (wb_rd_data_o),
        .regs_wen_o         (wb_regs_wen_o)
    );

    // ============================================================
    // BPU
    // ============================================================
    bpu_top #(
        .BHR_WIDTH  (10),
        .PHT_SIZE   (1024),
        .RAS_DEPTH  (8)
    ) BPU(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pc_addr            (if_pc_addr_o),
        .pc_inst            (if_inst_o),

        .pred_pc            (bpu_pred_pc),
        .pred_taken         (bpu_pred_taken),

        .update_btb_en      (ex_pred_update_btb_en),
        .update_gshare_en   (ex_pred_update_gshare_en),
        .update_pc          (ex_pc_addr_o),
        .update_target      (ex_pred_update_target),
        .actual_taken       (ex_actual_taken),
        .pred_mispredict    (ex_pred_mispredict),

        .hazard_en          (bpu_hold_en),
        .dcache_stall       (dcache_stall)
    );

endmodule