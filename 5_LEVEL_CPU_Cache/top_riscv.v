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
    (* max_fanout = 30 *)
    wire [31:0]     pc_pc_addr_o;
    wire [31:0]     icache_inst;

    // ============================================================
    // hazard / stall
    // ============================================================
    (* max_fanout = 30 *)
    wire            hazard_hazard_en;
    wire            mem1_is_load_o;

    // ============================================================
    // regs to id
    // ============================================================
    wire [31:0]     reg_rs1_data_o;
    wire [31:0]     reg_rs2_data_o;

    // ============================================================
    // csr_regs to pc & ex
    // ============================================================
    wire [31:0]     csr_regs_csr_rdata;
    wire [31:0]     csr_regs_ecall_mret_addr;

    // ============================================================
    // if to if_id & bpu
    // ============================================================
    wire [31:0]     if1_pc_o;
    wire [31:0]     if2_pc_i;
    (* max_fanout = 30 *)
    wire [31:0]     if2_inst_o;
    wire [31:0]     if2_pc_o;
    wire [6:0]      if2_opcode_o;
    wire [2:0]      if2_funct3_o;
    wire [6:0]      if2_funct7_o;
    wire [4:0]      if2_rd_o;
    wire [4:0]      if2_rs1_o;
    wire [4:0]      if2_rs2_o;

    // ============================================================
    // if_id to id
    // ============================================================
    (* max_fanout = 30 *)
    wire [31:0]     id_inst_i;
    wire [31:0]     id_pc_i;
    wire [6:0]      id_opcode_i;
    wire [2:0]      id_funct3_i;
    wire [6:0]      id_funct7_i;
    wire [4:0]      id_rd_i;
    wire [4:0]      id_rs1_i;
    wire [4:0]      id_rs2_i;

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
    (* max_fanout = 30 *)
    wire [4:0]      id_rs1_addr_o;
    (* max_fanout = 30 *)
    wire [4:0]      id_rs2_addr_o;
    wire [4:0]      id_rd_addr_o;
    wire            id_pred_taken_o;
    wire [`OP_INST_NUM - 1:0] id_inst_packaged_o;
    wire            id_fwd_rs1_hit_ex_o;
    wire            id_fwd_rs2_hit_ex_o;
    wire [31:0]     id_fwd_rs1_data_o;
    wire [31:0]     id_fwd_rs2_data_o;
    wire [11:0]     id_csr_addr_o;
    wire            id_ecall_o;
    wire            id_mret_o;


    // ============================================================
    // ex to dcache
    // ============================================================
    wire [31:0]     dcache_addr_i;
    wire            dcache_req_load_i;
    wire            dcache_req_store_i;
    wire [31:0]     dcache_wdata_i;
    wire [3:0]      dcache_we_i;
    wire            dcache_write_dram_i;

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
    wire            ex_valid_i;
    wire [`OP_INST_NUM - 1:0] ex_inst_packaged_i;
    wire            ex_fwd_rs1_hit_ex_i;
    wire            ex_fwd_rs2_hit_ex_i;
    wire [31:0]     ex_fwd_rs1_data_i;
    wire [31:0]     ex_fwd_rs2_data_i;
    wire [11:0]     ex_csr_addr_i;
    wire            ex_ecall_i;
    wire            ex_mret_i;

    // ============================================================
    // ex to jump
    // ============================================================
    (* max_fanout = 30 *)
    wire            ex_pred_flush_en_o;
    wire [31:0]     ex_pred_flush_pc_o;

    // ============================================================
    // ex to ex_mem
    // ============================================================
    wire [1:0]      ex_load_addr_low_o;
    wire [1:0]      ex_load_mask_o;
    wire            ex_load_is_signed_o;
    wire            ex_regs_wen_o;
    wire            ex_ecall_o;
    wire            ex_mret_o;

    // ex to csr_regs
    wire            ex_csr_wen_o;
    wire [31:0]     ex_csr_wdata_o;
    wire [31:0]     ex_ecall_inst;
    wire [11:0]     ex_csr_addr_o;

    // ex to ex_mem & hazard
    wire [31:0]     ex_rd_data_o;
    wire [4:0]      ex_rd_addr_o;
    wire            ex_req_load_o;

    // ============================================================
    // ex_mem to mem
    // ============================================================
    wire [1:0]      mem_load_addr_low_i;
    wire [1:0]      mem_load_mask_i;
    wire            mem_load_is_signed_i;
    wire            mem_regs_wen_i;
    wire [31:0]     mem_rd_data_i;
    wire [4:0]      mem_rd_addr_i;
    wire            mem_req_load_i;
    wire            mem_ecall_i;
    wire            mem_mret_i;

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

    wire            mem_ecall_o;
    wire            mem_mret_o;

    // ============================================================
    // mem to D-cache
    // ============================================================
    wire [31:0]     dcache_rdata;
    wire            dcache_ack_mem;
    (* max_fanout = 30 *)
    wire            dcache_stall;

    // ============================================================
    // mem_wb to wb
    // ============================================================
    wire [31:0]     wb_rd_data_i;
    wire [4:0]      wb_rd_addr_i;
    wire            wb_regs_wen_i;

    wire            wb_is_load_i;
    wire            wb_ecall_i;
    wire            wb_mret_i;

    // ============================================================
    // wb to regs
    // ============================================================
    wire [31:0]     wb_rd_data_o;
    wire [4:0]      wb_rd_addr_o;
    wire            wb_regs_wen_o;

    // ============================================================
    // wb to pc
    // ============================================================
    wire            wb_ecall_o;
    wire            wb_mret_o;

    // ============================================================
    // wb to flush 
    // ============================================================

    wire            wb_ecall_flush;
    wire            wb_mret_flush;

    // ============================================================
    // bpu to pc & id
    // ============================================================
    wire [31:0]     bpu_pred_pc;
    wire            bpu_pred_taken;

    // ��ˮ����ͣ����
    (* max_fanout = 30 *) wire pipe_hold_icache = dcache_stall | hazard_hazard_en;
    (* max_fanout = 30 *) wire pipe_hold_if1_if2 = dcache_stall | hazard_hazard_en;
    (* max_fanout = 30 *) wire pipe_hold_if2_id = dcache_stall | hazard_hazard_en;
    (* max_fanout = 30 *) wire pipe_hold_bpu = dcache_stall | hazard_hazard_en;

    (* max_fanout = 30 *) wire pipe_flush_icache = bpu_pred_taken | ex_pred_flush_en_o | wb_ecall_flush | wb_mret_flush;
    (* max_fanout = 30 *) wire pipe_flush_if1_if2 = bpu_pred_taken | ex_pred_flush_en_o | wb_ecall_flush | wb_mret_flush;
    (* max_fanout = 30 *) wire pipe_flush_if2_id = bpu_pred_taken | ex_pred_flush_en_o | wb_ecall_flush | wb_mret_flush;
    (* max_fanout = 30 *) wire pipe_flush_bpu = bpu_pred_taken | ex_pred_flush_en_o | wb_ecall_flush | wb_mret_flush;

    // ============================================================
    // ex to bpu
    // ============================================================
    wire            ex_pred_update_btb_en;
    wire            ex_pred_update_gshare_en;
    wire [31:0]     ex_pred_update_pc_o;
    wire [31:0]     ex_pred_update_target;
    (* max_fanout = 30 *)
    wire            ex_actual_taken;


    // ============================================================
    // PC
    // ============================================================
    pc PC(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .hazard_en          (hazard_hazard_en),
        .dcache_stall       (dcache_stall),

        .pred_flush         (ex_pred_flush_en_o),
        .pred_flush_pc      (ex_pred_flush_pc_o),

        .wb_ecall           (wb_ecall_o),
        .wb_mret            (wb_mret_o),

        .ecall_mret_addr    (csr_regs_ecall_mret_addr),

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
        .pipe_flush         (pipe_flush_icache),

        .mem_addr           (irom_addr),
        .mem_inst           (irom_data)
    );

    // ============================================================
    // Hazard
    //
    // �ؼ��޸ģ�
    // mem_waddr_i ʹ�� mem_rd_addr_i
    // mem_wdata_i ʹ�� mem_rd_data_i
    //
    // ������ mem_rd_data_o����Ϊ mem_rd_data_o �� load �ᾭ�� DCache/DROM��
    // ����·���������ڵ����ʱ��·����
    // ============================================================
    hazard HAZARD(
        // from ex
        .ex_rd_addr_i       (ex_rd_addr_o),
        .ex_is_load_i       (ex_req_load_o),

        .mem1_rd_addr_i     (mem1_rd_addr_o),
        .mem1_is_load_i     (mem1_is_load_o),

        // from id
        .id_rs1_raddr_i     (id_rs1_i),
        .id_rs2_raddr_i     (id_rs2_i),

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
    // CSR_Regfile
    // ============================================================
    csr_regs CSR_REGS(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .csr_addr           (ex_csr_addr_o),        
        .csr_wdata          (ex_csr_wdata_o),     
        .csr_wen            (ex_csr_wen_o),

        .csr_rdata          (csr_regs_csr_rdata),

        .ecall              (mem_ecall_o),      
        .mret               (mem_mret_o),       
        .ecall_inst         (ex_ecall_inst),     
        .ecall_mret_addr    (csr_regs_ecall_mret_addr)
    );

    // ============================================================
    // IF
    // ============================================================
    if1 IF1(
        .pc_i               (pc_pc_addr_o),

        .pc_o               (if1_pc_o)
    );

    if1_if2 IF1_IF2(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pipe_hold          (pipe_hold_if1_if2),
        .pipe_flush         (pipe_flush_if1_if2),

        .pc_i               (if1_pc_o),
        .pc_o               (if2_pc_i)
    );

    if2 IF2(
        .inst_i             (icache_inst),

        .pc_i               (if2_pc_i),

        .inst_o             (if2_inst_o),
        .pc_o               (if2_pc_o),
        .opcode_o           (if2_opcode_o),
        .funct3_o           (if2_funct3_o),
        .funct7_o           (if2_funct7_o),
        .rd_o               (if2_rd_o),
        .rs1_o              (if2_rs1_o),
        .rs2_o              (if2_rs2_o)
    );

    // ============================================================
    // IF/ID
    // ============================================================
    if2_id IF2_ID(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pipe_hold          (pipe_hold_if2_id),
        .pipe_flush         (pipe_flush_if2_id),

        .inst_i             (if2_inst_o),
        .pc_i               (if2_pc_o),
        .opcode_i           (if2_opcode_o),
        .funct3_i           (if2_funct3_o),
        .funct7_i           (if2_funct7_o),
        .rd_i               (if2_rd_o),
        .rs1_i              (if2_rs1_o),
        .rs2_i              (if2_rs2_o),

        .ecall_flush        (wb_ecall_flush),
        .mret_flush         (wb_mret_flush),

        .inst_o             (id_inst_i),
        .pc_o               (id_pc_i),
        .opcode_o           (id_opcode_i),
        .funct3_o           (id_funct3_i),
        .funct7_o           (id_funct7_i),
        .rd_o               (id_rd_i),
        .rs1_o              (id_rs1_i),
        .rs2_o              (id_rs2_i)
    );

    // ============================================================
    // ID
    // ============================================================
    id ID(
        .inst_i             (id_inst_i),
        .pc_addr_i          (id_pc_i),
        .opcode_i           (id_opcode_i),
        .funct3_i           (id_funct3_i),
        .funct7_i           (id_funct7_i),
        .rd_i               (id_rd_i),
        .rs1_i              (id_rs1_i),
        .rs2_i              (id_rs2_i),

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
        .value1_o           (id_value1_o),
        .value2_o           (id_value2_o),
        .pred_taken_o       (id_pred_taken_o),
        .inst_packaged_o    (id_inst_packaged_o),

        .rs1_addr_o         (id_rs1_addr_o),
        .rs2_addr_o         (id_rs2_addr_o),

        .ex_regs_wen_i      (ex_regs_wen_o),
        .ex_rd_addr_i       (ex_rd_addr_o),

        .mem1_regs_wen_i    (mem1_regs_wen_o),
        .mem1_rd_addr_i     (mem1_rd_addr_o),
        .mem1_rd_data_i     (mem1_rd_data_o),

        .mem2_regs_wen_i    (mem2_regs_wen_o),
        .mem2_rd_addr_i     (mem2_rd_addr_o),
        .mem2_rd_data_i     (mem2_rd_data_o),

        .wb_regs_wen_i      (wb_regs_wen_o),
        .wb_rd_addr_i       (wb_rd_addr_o),
        .wb_rd_data_i       (wb_rd_data_o),

        .fwd_rs1_data_o     (id_fwd_rs1_data_o),
        .fwd_rs2_data_o     (id_fwd_rs2_data_o),               
        .fwd_rs1_hit_ex_o   (id_fwd_rs1_hit_ex_o),
        .fwd_rs2_hit_ex_o   (id_fwd_rs2_hit_ex_o),

        .csr_addr_o         (id_csr_addr_o),
        .ecall              (id_ecall_o),
        .mret               (id_mret_o)
    );

    // ============================================================
    // ID/EX
    // ============================================================
    id_ex ID_EX(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pred_flush         (ex_pred_flush_en_o),
        .hazard_en          (hazard_hazard_en),
        .dcache_stall       (dcache_stall),

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
        .inst_packaged_i    (id_inst_packaged_o),

        .fwd_rs1_data_i     (id_fwd_rs1_data_o),
        .fwd_rs2_data_i     (id_fwd_rs2_data_o),
        .fwd_rs1_hit_ex_i   (id_fwd_rs1_hit_ex_o),
        .fwd_rs2_hit_ex_i   (id_fwd_rs2_hit_ex_o),
        .ecall_i            (id_ecall_o),
        .mret_i             (id_mret_o),

        .csr_addr_i         (id_csr_addr_o),

        .ecall_flush        (wb_ecall_flush),
        .mret_flush         (wb_mret_flush),

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
        .inst_packaged_o    (ex_inst_packaged_i),
        .valid_o            (ex_valid_i),
        .fwd_rs1_data_o     (ex_fwd_rs1_data_i),
        .fwd_rs2_data_o     (ex_fwd_rs2_data_i),
        .fwd_rs1_hit_ex_o   (ex_fwd_rs1_hit_ex_i),
        .fwd_rs2_hit_ex_o   (ex_fwd_rs2_hit_ex_i),

        .ecall_o            (ex_ecall_i),
        .mret_o             (ex_mret_i),
        .csr_addr_o         (ex_csr_addr_i)
    );

    // ============================================================
    // EX
    // ============================================================
    ex EX(
        .clk                (cpu_clk),

        .pc_addr_i          (ex_pc_addr_i),
        .inst_i             (ex_inst_i),
        .jump1_i            (ex_jump1_i),
        .jump2_i            (ex_jump2_i),
        .rd_addr_i          (ex_rd_addr_i),
        .regs_wen_i         (ex_regs_wen_i),
        .value1_i           (ex_value1_i),
        .value2_i           (ex_value2_i),
        .pred_taken_i       (ex_pred_taken_i),
        .inst_packaged_i    (ex_inst_packaged_i),
        .valid_i            (ex_valid_i),
        .mem_load_mask      (ex_load_mask_o),
        .mem_load_addr_low  (ex_load_addr_low_o),
        .mem_load_is_signed (ex_load_is_signed_o),

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
        .dcache_addr        (dcache_addr_i),
        .dcache_wdata       (dcache_wdata_i),
        .dcache_we          (dcache_we_i),
        .dcache_write_dram  (dcache_write_dram_i),

        .fwd_rs1_data_i     (ex_fwd_rs1_data_i),
        .fwd_rs2_data_i     (ex_fwd_rs2_data_i),
        .fwd_rs1_hit_ex_i   (ex_fwd_rs1_hit_ex_i),
        .fwd_rs2_hit_ex_i   (ex_fwd_rs2_hit_ex_i),
        .fwd_ex_rd_data_i   (mem_rd_data_i),

        .ecall_i            (ex_ecall_i),
        .mret_i             (ex_mret_i),
        .csr_addr_i         (ex_csr_addr_i),
        .csr_rdata          (csr_regs_csr_rdata),
        .ecall_o            (ex_ecall_o),
        .mret_o             (ex_mret_o),
        .csr_addr_o         (ex_csr_addr_o),
        .csr_wen_o          (ex_csr_wen_o),
        .csr_wdata_o        (ex_csr_wdata_o),
        .ecall_inst         (ex_ecall_inst),
        
        .ecall_flush        (wb_ecall_flush),
        .mret_flush         (wb_mret_flush)
    );

    // ============================================================
    // EX/MEM
    // ============================================================
    ex_mem EX_MEM(
        .clk                (cpu_clk),
        .rst                (cpu_rst),
        .dcache_stall       (dcache_stall),

        .rd_addr_i          (ex_rd_addr_o),
        .rd_data_i          (ex_rd_data_o),
        .regs_wen_i         (ex_regs_wen_o),
        .mem_req_load_i     (ex_req_load_o),
        .ecall_i            (ex_ecall_o),
        .mret_i             (ex_mret_o),
        .load_mask_i        (ex_load_mask_o),
        .load_addr_low_i    (ex_load_addr_low_o),
        .load_is_signed_i   (ex_load_is_signed_o),

        .ecall_flush        (wb_ecall_flush),
        .mret_flush         (wb_mret_flush),

        .rd_addr_o          (mem_rd_addr_i),
        .rd_data_o          (mem_rd_data_i),
        .regs_wen_o         (mem_regs_wen_i),
        .mem_req_load_o     (mem_req_load_i),
        .ecall_o            (mem_ecall_i),
        .mret_o             (mem_mret_i),
        .load_mask_o        (mem_load_mask_i),
        .load_addr_low_o    (mem_load_addr_low_i),
        .load_is_signed_o   (mem_load_is_signed_i)
    );

    // ============================================================
    // MEM
    // ============================================================
    mem MEM(
        .clk                (cpu_clk),
        .rst                (cpu_rst),
        .dcache_ack         (dcache_ack_mem),
        .dcache_rdata       (dcache_rdata),

        .rd_addr_i          (mem_rd_addr_i),
        .rd_data_i          (mem_rd_data_i),
        .regs_wen           (mem_regs_wen_i),
        .mem_req_load_i     (mem_req_load_i),
        .ecall_i            (mem_ecall_i),
        .mret_i             (mem_mret_i),
        .load_mask_i        (mem_load_mask_i),
        .load_addr_low_i    (mem_load_addr_low_i),
        .load_is_signed_i   (mem_load_is_signed_i),

        .mem1_is_load_o     (mem1_is_load_o),
        .mem2_is_load_o     (mem2_is_load_o),

        .mem1_rd_addr_o     (mem1_rd_addr_o),
        .mem1_rd_data_o     (mem1_rd_data_o),
        .mem1_regs_wen_o    (mem1_regs_wen_o),

        .mem2_rd_addr_o     (mem2_rd_addr_o),
        .mem2_rd_data_o     (mem2_rd_data_o),
        .mem2_regs_wen_o    (mem2_regs_wen_o),
        .ecall_o            (mem_ecall_o),
        .mret_o             (mem_mret_o)
    );

    // ============================================================
    // D-cache
    // ============================================================
    dcache DCACHE(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .cpu_req_load       (dcache_req_load_i),
        .cpu_req_store      (dcache_req_store_i),
        .cpu_addr           (dcache_addr_i),
        .cpu_wdata          (dcache_wdata_i),
        .cpu_we             (dcache_we_i),
        .cpu_rdata          (dcache_rdata),
        .cpu_write_dram     (dcache_write_dram_i),

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

        .rd_addr_i          (mem2_rd_addr_o),
        .rd_data_i          (mem2_rd_data_o),
        .regs_wen_i         (mem2_regs_wen_o),
        .is_load_i          (mem2_is_load_o),
        .ecall_i            (mem_ecall_o),
        .mret_i             (mem_mret_o),

        .ecall_flush        (wb_ecall_flush),
        .mret_flush         (wb_mret_flush),

        .rd_addr_o          (wb_rd_addr_i),
        .rd_data_o          (wb_rd_data_i),
        .regs_wen_o         (wb_regs_wen_i),
        .is_load_o          (wb_is_load_i),
        .ecall_o            (wb_ecall_i),
        .mret_o             (wb_mret_i)
    );

    // ============================================================
    // WB
    // ============================================================
    wb WB(
        .rd_addr_i          (wb_rd_addr_i),
        .rd_data_i          (wb_rd_data_i),
        .regs_wen_i         (wb_regs_wen_i),
        .ecall_i            (wb_ecall_i),
        .mret_i             (wb_mret_i),

        .rd_addr_o          (wb_rd_addr_o),
        .rd_data_o          (wb_rd_data_o),
        .regs_wen_o         (wb_regs_wen_o),

        .ecall_o            (wb_ecall_o),
        .mret_o             (wb_mret_o),
        .ecall_flush        (wb_ecall_flush),
        .mret_flush         (wb_mret_flush)
    );

    // ============================================================
    // BPU
    // ============================================================
    bpu_top #(
        .BHR_WIDTH          (14),
        .BTB_INDEX_WIDTH    (4),
        .RAS_DEPTH          (8)
    ) BPU(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pc_addr            (if1_pc_o),
        .pc_addr_if2        (if2_pc_o),
        .pc_inst            (if2_inst_o),

        .pred_pc            (bpu_pred_pc),
        .pred_taken         (bpu_pred_taken),

        .update_btb_en      (ex_pred_update_btb_en),
        .update_gshare_en   (ex_pred_update_gshare_en),
        .update_pc          (ex_pred_update_pc_o),
        .update_target      (ex_pred_update_target),
        .actual_taken       (ex_actual_taken),

        .pipe_hold          (pipe_hold_bpu),
        .pipe_flush         (pipe_flush_bpu)
    );

endmodule