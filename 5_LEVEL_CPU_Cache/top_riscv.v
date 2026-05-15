`include "rv32I.vh"
`include "alu.vh"
`include "switch.vh"

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

    // ============================================================
    // pred_flusher
    // ============================================================
    (* max_fanout = 30 *)
    wire            pred_flush_en_r;
    (* max_fanout = 30 *)
    wire [31:0]     pred_flush_pc_r;

    // ============================================================
    // hazard / stall
    // ============================================================
    wire            hazard_hazard_en;
    wire            dcache_stall;
    wire            mem1_is_load_o;

    // ============================================================
    // regs to id
    // ============================================================
    wire [31:0]     reg_rs1_data_o;
    wire [31:0]     reg_rs2_data_o;

    // ============================================================
    // if to if_id & bpu
    // ============================================================
    wire [31:0]     if1_pc_o;
    wire [31:0]     if2_pc_i;
    wire            if2_valid_i;
    wire [31:0]     if2_inst_o;
    wire [31:0]     if2_pc_o;

    // ============================================================
    // if_id to id
    // ============================================================
    wire [31:0]     id_inst_i;
    wire [31:0]     id_pc_i;

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
    wire [`OP_INST_NUM - 1:0] id_inst_packaged_o;

    // ============================================================
    // ex to dcache
    // ============================================================
    wire [31:0]     dcache_addr_i;
    wire [3:0]      dcache_addr_offset_i;
    wire            dcache_req_load_i;
    wire            dcache_req_store_i;
    wire [2:0]      dcache_mask_i;
    wire [31:0]     dcache_wdata_i;
    wire            dcache_is_signed_i;

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
    wire [4:0]      ex_rs1_addr_i;
    wire [4:0]      ex_rs2_addr_i;
    wire            ex_pred_taken_i;
    wire [31:0]     ex_pred_pc_i;
    wire            ex_valid_i;
    wire [`OP_INST_NUM - 1:0] ex_inst_packaged_i;

    // ============================================================
    // ex to jump
    // ============================================================
    (* max_fanout = 30 *)
    wire            ex_pred_flush_en_o;
    (* max_fanout = 30 *)
    wire [31:0]     ex_pred_flush_pc_o;

    // ============================================================
    // ex to ex_mem
    // ============================================================
    wire            ex_regs_wen_o;

    // ex to ex_mem & hazard
    wire [31:0]     ex_rd_data_o;
    wire [4:0]      ex_rd_addr_o;
    wire            ex_req_load_o;

    // ============================================================
    // ex_mem to mem
    // ============================================================
    wire            mem_regs_wen_i;
    wire [31:0]     mem_rd_data_i;
    wire [4:0]      mem_rd_addr_i;
    wire            mem_req_load_i;

    // ============================================================
    // mem to mem_wb
    // ============================================================
    wire [4:0]      mem1_rd_addr_o;
    wire [31:0]     mem1_rd_data_o;
    wire            mem1_regs_wen_o;

    wire [4:0]      mem2_rd_addr_o;
    wire [31:0]     mem2_rd_data_o;
    wire            mem2_regs_wen_o;

    wire            mem2_is_load_o;

    // ============================================================
    // mem to D-cache
    // ============================================================
    wire [31:0]     dcache_rdata;
    wire            dcache_ack;

    // ============================================================
    // mem_wb to wb
    // ============================================================
    wire [31:0]     wb_rd_data_i;
    wire [4:0]      wb_rd_addr_i;
    wire            wb_regs_wen_i;

    wire            wb_is_load_i;

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

    // 流水线暂停条件
    (* max_fanout = 30 *)
    wire pipe_hold_icache = dcache_stall | hazard_hazard_en;
    (* max_fanout = 30 *)
    wire pipe_hold_if1_if2 = dcache_stall | hazard_hazard_en;
    (* max_fanout = 30 *)
    wire pipe_hold_if2_id = dcache_stall | hazard_hazard_en;
    (* max_fanout = 30 *)
    wire pipe_hold_pred_flusher = dcache_stall | hazard_hazard_en;
    (* max_fanout = 30 *)
    wire pipe_hold_bpu = dcache_stall | hazard_hazard_en;

    // ============================================================
    // ex to bpu
    // ============================================================
    wire            ex_pred_update_btb_en;
    wire            ex_pred_update_gshare_en;
    wire [31:0]     ex_pred_update_pc_o;
    wire [31:0]     ex_pred_update_target;
    wire            ex_actual_taken;

    // forwarding to ex
    wire            fwd_rs1_hit_ex_o;
    wire            fwd_rs2_hit_ex_o;
    wire [31:0]     fwd_rs1_data_o;
    wire [31:0]     fwd_rs2_data_o;
    wire [31:0]     fwd_ex_rd_data_o;

    // ============================================================
    // PC
    // ============================================================
    pc PC(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .dcache_stall       (dcache_stall),

        .hazard_en          (hazard_hazard_en),

        .pred_flush_en      (pred_flush_en_r),
        .pred_flush_pc      (pred_flush_pc_r),

        .pc_addr_o          (pc_pc_addr_o),

        .pred_pc            (bpu_pred_pc),
        .pred_taken         (bpu_pred_taken)
    );

    // ============================================================
    // I-cache
    // ============================================================
    icache ICACHE(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .cpu_pc             (if1_pc_o),
        .cpu_inst           (icache_inst),
        .pipe_hold          (pipe_hold_icache),

        .mem_addr           (irom_addr),
        .mem_inst           (irom_data)
    );

    // ============================================================
    // Pred_flusher
    // ============================================================
    pred_flusher PRED_FLUSHER(
        .clk                (cpu_clk),
        .rst                (cpu_rst),
        .pipe_hold          (pipe_hold_pred_flusher),

        .pred_flush_en_i    (ex_pred_flush_en_o),
        .pred_flush_pc_i    (ex_pred_flush_pc_o),

        .pred_flush_en_r_o  (pred_flush_en_r),
        .pred_flush_pc_r_o  (pred_flush_pc_r)
    );

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
        .ex_rd_addr_i       (ex_rd_addr_o),
        .ex_is_load_i       (ex_req_load_o),

        .mem1_rd_addr_i     (mem1_rd_addr_o),
        .mem1_is_load_i     (mem1_is_load_o),

        .mem2_rd_addr_i     (mem2_rd_addr_o),
        .mem2_is_load_i     (mem2_is_load_o),

        // from id
        .id_rs1_raddr_i     (id_rs1_addr_o),
        .id_rs2_raddr_i     (id_rs2_addr_o),

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
    if1 IF1(
        .pc_i               (pc_pc_addr_o),
        .pred_flush         (pred_flush_en_r),

        .pc_o               (if1_pc_o)
    );

    if1_if2 IF1_IF2(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pred_taken         (bpu_pred_taken),
        .pred_flush         (pred_flush_en_r),
        .pipe_hold          (pipe_hold_if1_if2),

        .pc_i               (if1_pc_o),

        .if2_valid_o        (if2_valid_i),
        .pc_o               (if2_pc_i)
    );

    if2 IF2(
        .inst_i             (icache_inst),
        .pred_flush_r       (pred_flush_en_r),

        .if2_valid_i        (if2_valid_i),
        .pc_i               (if2_pc_i),

        .inst_o             (if2_inst_o),
        .pc_o               (if2_pc_o)
    );

    // ============================================================
    // IF/ID
    // ============================================================
    if2_id IF2_ID(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pipe_hold          (pipe_hold_if2_id),

        .inst_i             (if2_inst_o),
        .pc_i               (if2_pc_o),

        .pred_taken         (bpu_pred_taken),

        .inst_o             (id_inst_i),
        .pc_o               (id_pc_i)
    );

    // ============================================================
    // ID
    // ============================================================
    id ID(
        .inst_i             (id_inst_i),
        .pc_addr_i          (id_pc_i),

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
        .inst_packaged_o    (id_inst_packaged_o),

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

        .pred_flush         (ex_pred_flush_en_o),
        .pred_flush_r       (pred_flush_en_r),
        .hazard_en          (hazard_hazard_en),

        .pc_addr_i          (id_pc_addr_o),
        .inst_i             (id_inst_o),
        .jump1_i            (id_jump1_o),
        .jump2_i            (id_jump2_o),
        .rd_addr_i          (id_rd_addr_o),
        .regs_wen_i         (id_reg_wen),
        .rs1_addr_i         (id_rs1_addr_o),
        .rs2_addr_i         (id_rs2_addr_o),
        .value1_i           (id_value1_o),
        .value2_i           (id_value2_o),
        .pred_taken_i       (id_pred_taken_o),
        .pred_pc_i          (id_pred_pc_o),
        .inst_packaged_i    (id_inst_packaged_o),

        .pc_addr_o          (ex_pc_addr_i),
        .inst_o             (ex_inst_i),
        .jump1_o            (ex_jump1_i),
        .jump2_o            (ex_jump2_i),
        .rd_addr_o          (ex_rd_addr_i),
        .regs_wen_o         (ex_regs_wen_i),
        .rs1_addr_o         (ex_rs1_addr_i),
        .rs2_addr_o         (ex_rs2_addr_i),
        .value1_o           (ex_value1_i),
        .value2_o           (ex_value2_i),
        .pred_taken_o       (ex_pred_taken_i),
        .pred_pc_o          (ex_pred_pc_i),
        .inst_packaged_o    (ex_inst_packaged_i),
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
        .value1_i           (ex_value1_i),
        .value2_i           (ex_value2_i),
        .pred_taken_i       (ex_pred_taken_i),
        .pred_pc_i          (ex_pred_pc_i),
        .inst_packaged_i    (ex_inst_packaged_i),
        .valid_i            (ex_valid_i),

        .regs_wen_o         (ex_regs_wen_o),

        .rd_addr_o          (ex_rd_addr_o),
        .rd_data_o          (ex_rd_data_o),
        .mem_req_load_o     (ex_req_load_o),

        .pred_flush_en      (ex_pred_flush_en_o),
        .pred_flush_pc      (ex_pred_flush_pc_o),

        .update_btb_en_o    (ex_pred_update_btb_en),
        .update_gshare_en_o (ex_pred_update_gshare_en),
        .update_pc_o        (ex_pred_update_pc_o),
        .update_target_o    (ex_pred_update_target),
        .actual_taken_o     (ex_actual_taken),

        .dcache_req_load    (dcache_req_load_i),
        .dcache_req_store   (dcache_req_store_i),
        .dcache_mask        (dcache_mask_i),
        .dcache_addr        (dcache_addr_i),
        .dcache_addr_offset (dcache_addr_offset_i),
        .dcache_wdata       (dcache_wdata_i),
        .dcache_is_signed   (dcache_is_signed_i),

        .fwd_rs1_data_i     (fwd_rs1_data_o),
        .fwd_rs2_data_i     (fwd_rs2_data_o),
        .fwd_rs1_hit_ex_i   (fwd_rs1_hit_ex_o),
        .fwd_rs2_hit_ex_i   (fwd_rs2_hit_ex_o),
        .fwd_ex_rd_data_i   (fwd_ex_rd_data_o)
    );

    // ============================================================
    // EX/MEM
    // ============================================================
    ex_mem EX_MEM(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .rd_addr_i          (ex_rd_addr_o),
        .rd_data_i          (ex_rd_data_o),
        .regs_wen_i         (ex_regs_wen_o),
        .mem_req_load_i     (ex_req_load_o),

        .rd_addr_o          (mem_rd_addr_i),
        .rd_data_o          (mem_rd_data_i),
        .regs_wen_o         (mem_regs_wen_i),
        .mem_req_load_o     (mem_req_load_i)
    );

    // ============================================================
    // MEM
    // ============================================================
    mem MEM(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .rd_addr_i          (mem_rd_addr_i),
        .rd_data_i          (mem_rd_data_i),
        .regs_wen           (mem_regs_wen_i),
        .mem_req_load_i     (mem_req_load_i),

        .mem1_is_load_o     (mem1_is_load_o),
        .mem2_is_load_o     (mem2_is_load_o),

        .mem1_rd_addr_o     (mem1_rd_addr_o),
        .mem1_rd_data_o     (mem1_rd_data_o),
        .mem1_regs_wen_o    (mem1_regs_wen_o),

        .mem2_rd_addr_o     (mem2_rd_addr_o),
        .mem2_rd_data_o     (mem2_rd_data_o),
        .mem2_regs_wen_o    (mem2_regs_wen_o)
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
        .cpu_addr_offset    (dcache_addr_offset_i),
        .cpu_wdata          (dcache_wdata_i),
        .cpu_is_signed      (dcache_is_signed_i),
        .cpu_rdata          (dcache_rdata),
        .stall              (dcache_stall),

        .mem_addr           (perip_addr),
        .mem_we             (perip_we),
        .mem_wen            (perip_wen),
        .mem_wdata          (perip_wdata),
        .mem_rdata          (perip_rdata),

        .mem_ack            (dcache_ack)
    );

    // ============================================================
    // MEM/WB
    // ============================================================
    mem_wb MEM_WB(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .rd_addr_i          (mem2_rd_addr_o),
        .rd_data_i          (mem2_rd_data_o),
        .regs_wen_i         (mem2_regs_wen_o),
        .is_load_i          (mem2_is_load_o),

        .rd_addr_o          (wb_rd_addr_i),
        .rd_data_o          (wb_rd_data_i),
        .regs_wen_o         (wb_regs_wen_i),
        .is_load_o          (wb_is_load_i)
    );

    // ============================================================
    // WB
    // ============================================================
    wb WB(
        .rd_addr_i          (wb_rd_addr_i),
        .rd_data_i          (wb_rd_data_i),
        .regs_wen_i         (wb_regs_wen_i),
        .is_load            (wb_is_load_i),

        .rd_addr_o          (wb_rd_addr_o),
        .rd_data_o          (wb_rd_data_o),
        .regs_wen_o         (wb_regs_wen_o),

        .dcache_ack         (dcache_ack),
        .perip_rdata        (dcache_rdata)
    );

    // ============================================================
    // BPU
    // ============================================================
    bpu_top #(
        .BHR_WIDTH          (16),
        .BTB_INDEX_WIDTH    (4),
        .RAS_DEPTH          (8)
    ) BPU(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pc_addr            (if1_pc_o),
        .pc_inst            (if2_inst_o),

        .pred_pc            (bpu_pred_pc),
        .pred_taken         (bpu_pred_taken),

        .update_btb_en      (ex_pred_update_btb_en),
        .update_gshare_en   (ex_pred_update_gshare_en),
        .update_pc          (ex_pred_update_pc_o),
        .update_target      (ex_pred_update_target),
        .actual_taken       (ex_actual_taken),

        .pipe_hold          (pipe_hold_bpu),
        .pred_flush_r       (pred_flush_en_r)
    );

    // forwarding
    forwarding FWD(
        .clk                (cpu_clk),
        .rst                (cpu_rst),
        .dcache_stall       (dcache_stall),

        // from id
        .id_rs1_addr_i      (id_rs1_addr_o),
        .id_rs2_addr_i      (id_rs2_addr_o),
        .id_rs1_data_i      (id_rs1_data_o),
        .id_rs2_data_i      (id_rs2_data_o),

        // from ex
        .ex_regs_wen_i      (ex_regs_wen_o),
        .ex_rd_addr_i       (ex_rd_addr_o),
        .ex_rd_data_i       (ex_rd_data_o),

        // from mem1
        .mem1_rd_addr_i      (mem1_rd_addr_o),
        .mem1_rd_data_i      (mem1_rd_data_o),
        .mem1_regs_wen_i     (mem1_regs_wen_o),

        // from mem2
        .mem2_rd_addr_i      (mem2_rd_addr_o),
        .mem2_rd_data_i      (mem2_rd_data_o),
        .mem2_regs_wen_i     (mem2_regs_wen_o),

        // to ex
        .forwarding_rs1_data_o      (fwd_rs1_data_o),
        .forwarding_rs2_data_o      (fwd_rs2_data_o),
        .forwarding_rs1_hit_ex_o    (fwd_rs1_hit_ex_o),
        .forwarding_rs2_hit_ex_o    (fwd_rs2_hit_ex_o),
        .forwarding_ex_rd_data_o    (fwd_ex_rd_data_o)
);

endmodule