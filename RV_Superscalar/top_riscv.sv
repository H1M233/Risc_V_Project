`include "rv32I.vh"
`include "alu.vh"
`include "switch.vh"

module top_riscv(
    input           cpu_rst,
    input           cpu_clk,

    // from IROM
    output  [31:0]  slot0_irom_addr,
    output  [31:0]  slot1_irom_addr,
    input   [31:0]  slot0_irom_data,
    input   [31:0]  slot1_irom_data,

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
    wire [31:0]     slot0_pc_pc_o;
    wire [31:0]     slot1_pc_pc_o;
    wire [31:0]     slot0_icache_inst;
    wire [31:0]     slot1_icache_inst;

    // ============================================================
    // hazard / stall
    // ============================================================
    (* max_fanout = 30 *)
    logic           hazard_hazard_en;
    logic           dual_stall;
    logic           dual_stall_finish;
    
    // ============================================================
    // regs to id
    // ============================================================
    logic [31:0]    slot0_reg_rs1_data_o;
    logic [31:0]    slot1_reg_rs1_data_o;
    logic [31:0]    slot0_reg_rs2_data_o;
    logic [31:0]    slot1_reg_rs2_data_o;
    
    // ============================================================
    // csr_regs to pc & ex
    // ============================================================
    wire [31:0]     slot0_csr_regs_csr_rdata;
    wire [31:0]     csr_regs_ecall_mret_addr;
    
    // ============================================================
    // if to if_id & bpu
    // ============================================================
    wire [31:0]     slot0_if1_pc_o;
    wire [31:0]     slot1_if1_pc_o;
    
    wire [31:0]     slot0_if2_pc_o;
    wire [31:0]     slot1_if2_pc_o;
    
    wire [31:0]     slot0_if2_inst_o;
    wire [31:0]     slot1_if2_inst_o;
    
    wire [6:0]      slot0_if2_opcode_o;
    wire [2:0]      slot0_if2_funct3_o;
    wire [6:0]      slot0_if2_funct7_o;
    wire [4:0]      slot0_if2_rd_o;
    wire [4:0]      slot0_if2_rs1_o;
    wire [4:0]      slot0_if2_rs2_o;
    
    wire [6:0]      slot1_if2_opcode_o;
    wire [2:0]      slot1_if2_funct3_o;
    wire [6:0]      slot1_if2_funct7_o;
    wire [4:0]      slot1_if2_rd_o;
    wire [4:0]      slot1_if2_rs1_o;
    wire [4:0]      slot1_if2_rs2_o;
    
    // ============================================================
    // if_id to id
    // ============================================================
    wire [31:0]     slot0_id_inst_i;
    wire [31:0]     slot0_id_pc_i;
    wire [6:0]      slot0_id_opcode_i;
    wire [2:0]      slot0_id_funct3_i;
    wire [6:0]      slot0_id_funct7_i;
    wire [4:0]      slot0_id_rd_i;
    wire [4:0]      slot0_id_rs1_i;
    wire [4:0]      slot0_id_rs2_i;
    
    wire [31:0]     slot1_id_inst_i;
    wire [31:0]     slot1_id_pc_i;
    wire [6:0]      slot1_id_opcode_i;
    wire [2:0]      slot1_id_funct3_i;
    wire [6:0]      slot1_id_funct7_i;
    wire [4:0]      slot1_id_rd_i;
    wire [4:0]      slot1_id_rs1_i;
    wire [4:0]      slot1_id_rs2_i;
    
    // ============================================================
    // id to id_ex
    // ============================================================
    data_t          slot0_id_data_packaged_o, slot1_id_data_packaged_o;
    decode_t        slot0_id_inst_packaged_o, slot1_id_inst_packaged_o;
    logic           slot0_id_regs_wen_o, slot1_id_regs_wen_o;
    logic           slot0_using_rs_data_o, slot1_using_rs_data_o;
    
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
    data_t          slot0_ex_data_packaged_i;
    data_t          slot1_ex_data_packaged_i;
    decode_t        slot0_ex_inst_packaged_i;
    decode_t        slot1_ex_inst_packaged_i;
    logic           slot0_ex_regs_wen_i;
    logic           slot1_ex_regs_wen_i;
    logic           slot0_ex_valid_i;
    logic           slot1_ex_valid_i;
    
    // ============================================================
    // ex-pred_flush
    // ============================================================
    logic           slot0_ex_pred_flush_en_o;
    logic           slot1_ex_pred_flush_en_o;
    logic [31:0]    slot0_ex_pred_flush_pc_o;
    logic [31:0]    slot1_ex_pred_flush_pc_o;
    logic           slot0_pred_flush_en;
    logic           slot1_pred_flush_en;
    logic [31:0]    slot0_pred_flush_pc;
    logic [31:0]    slot1_pred_flush_pc;
    logic           pred_flush_en;
    logic [31:0]    pred_flush_pc;
    assign pred_flush_en = slot0_pred_flush_en | slot1_pred_flush_en;
    assign pred_flush_pc = (slot0_pred_flush_en) ? slot0_pred_flush_pc : slot1_pred_flush_pc;
    
    // ============================================================
    // ex to ex_mem
    // ============================================================
    logic           slot0_ex_regs_wen_o, slot1_ex_regs_wen_o;
    logic           slot0_ex_ecall_o;
    logic           slot0_ex_mret_o;
    logic [31:0]    slot0_ex_ecall_inst;
    logic           slot0_ex_valid_o;
    logic           slot1_ex_valid_o;
    logic [1:0]     ex_load_addr_low_o;
    logic [1:0]     ex_load_mask_o;
    logic           ex_load_is_signed_o;
    logic           ex_dcache_req_load_o;
    logic           ex_dcache_req_store_o;
    logic [31:0]    ex_dcache_addr_o;
    logic [31:0]    ex_dcache_wdata_o;
    logic [3:0]     ex_dcache_we_o;
    logic           ex_dcache_write_dram_o;
    
    // ex to csr_regs
    logic           slot0_ex_csr_wen_o;
    logic [31:0]    slot0_ex_csr_wdata_o;
    logic [11:0]    slot0_ex_csr_addr_o;
    
    // ex to ex_mem & hazard
    wire [31:0]     slot0_ex_rd_data_o, slot1_ex_rd_data_o;
    wire [4:0]      slot0_ex_rd_addr_o, slot1_ex_rd_addr_o;
    wire            slot0_ex_req_load_o;
    
    // ============================================================
    // ex_mem to mem
    // ============================================================
    logic           slot0_mem_regs_wen_i;
    logic           slot1_mem_regs_wen_i;
    logic [31:0]    slot0_mem_rd_data_i;
    logic [31:0]    slot1_mem_rd_data_i;
    logic [4:0]     slot0_mem_rd_addr_i;
    logic [4:0]     slot1_mem_rd_addr_i;
    logic           slot0_mem_ecall_i;
    logic           slot0_mem_mret_i;
    logic [31:0]    slot0_mem_ecall_inst_i;
    logic           mem_req_load_i;
    logic [1:0]     mem_load_addr_low_i;
    logic [1:0]     mem_load_mask_i;
    logic           mem_load_is_signed_i;
    
    // ============================================================
    // mem to mem_wb
    // ============================================================
    logic [4:0]     slot0_mem1_rd_addr_o, slot1_mem1_rd_addr_o;
    logic [31:0]    slot0_mem1_rd_data_o, slot1_mem1_rd_data_o;
    logic           slot0_mem1_regs_wen_o, slot1_mem1_regs_wen_o;
    
    logic [4:0]     slot0_mem2_rd_addr_o, slot1_mem2_rd_addr_o;
    logic [31:0]    slot0_mem2_rd_data_o, slot1_mem2_rd_data_o;
    logic           slot0_mem2_regs_wen_o, slot1_mem2_regs_wen_o;
    
    logic           mem1_is_load_o;
    logic           mem2_is_load_o;
    
    logic           slot0_mem_ecall_o;
    logic           slot0_mem_mret_o;
    logic [31:0]    slot0_mem_ecall_inst_o;

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
    logic [31:0]    slot0_wb_rd_data_i;
    logic [31:0]    slot1_wb_rd_data_i;
    logic [4:0]     slot0_wb_rd_addr_i;
    logic [4:0]     slot1_wb_rd_addr_i;
    logic           slot0_wb_regs_wen_i;
    logic           slot1_wb_regs_wen_i;

    logic           wb_is_load_i;
    logic           slot0_wb_ecall_i;
    logic           slot0_wb_mret_i;
    logic [31:0]    slot0_wb_ecall_inst_i;

    // ============================================================
    // wb to regs
    // ============================================================
    wire [31:0]     slot0_wb_rd_data_o;
    wire [31:0]     slot1_wb_rd_data_o;
    wire [4:0]      slot0_wb_rd_addr_o;
    wire [4:0]      slot1_wb_rd_addr_o;
    wire            slot0_wb_regs_wen_o;
    wire            slot1_wb_regs_wen_o;

    // ============================================================
    // wb to pc & csg_regs
    // ============================================================
    wire            slot0_wb_ecall_o;
    wire            slot0_wb_mret_o;
    wire [31:0]     slot0_wb_ecall_inst_o;

    // ============================================================
    // wb to flush 
    // ============================================================
    wire            ecall_mret_flush = slot0_wb_ecall_o | slot0_wb_mret_o;

    // ============================================================
    // bpu to pc & id
    // ============================================================
    wire [31:0]     bpu_pred_pc;
    wire            bpu_pred_taken;
    logic           bpu_slot0_pred_taken;
    logic           bpu_slot1_pred_taken;
    logic [31:0]    bpu_slot0_pred_pc;
    logic [31:0]    bpu_slot1_pred_pc;
    logic [3:0]     bpu_ras_snapshot;
    logic           bpu_slot0_id_is_ret;
    logic           bpu_slot1_id_is_ret;

    // ��ˮ����ͣ����
    wire pipe_hold_pc = dcache_stall | hazard_hazard_en | dual_stall;
    wire pipe_hold_icache = dcache_stall | hazard_hazard_en | dual_stall;
    wire pipe_hold_if1_if2 = dcache_stall | hazard_hazard_en | dual_stall;
    wire pipe_hold_if2_id = dcache_stall | hazard_hazard_en | dual_stall;
    wire pipe_hold_bpu = dcache_stall | hazard_hazard_en | dual_stall;
    wire pipe_hold_ex_mem = dcache_stall;
    wire pipe_hold_ex_bpu = dcache_stall;

    wire pipe_flush_icache = bpu_pred_taken | pred_flush_en | ecall_mret_flush;
    wire pipe_flush_if1_if2 = bpu_pred_taken | pred_flush_en | ecall_mret_flush;
    wire pipe_flush_if2_id = bpu_pred_taken | pred_flush_en | ecall_mret_flush;
    wire pipe_flush_bpu = bpu_pred_taken | pred_flush_en | ecall_mret_flush;
    wire pipe_flush_ex_mem = pred_flush_en | ecall_mret_flush;
    wire pipe_flush_ex_bpu = pred_flush_en | ecall_mret_flush;

    // ============================================================
    // ex to bpu
    // ============================================================
    wire            slot0_ex_update_ras_o;
    wire            slot1_ex_update_ras_o;
    wire [3:0]      slot0_ex_ras_snapshot_o;
    wire [3:0]      slot1_ex_ras_snapshot_o;
    wire            slot0_ex_update_gshare_en_o;
    wire            slot1_ex_update_gshare_en_o;
    wire            slot0_ex_actual_taken_o;
    wire            slot1_ex_actual_taken_o;
    wire            slot0_ex_update_btb_en_o;
    wire            slot1_ex_update_btb_en_o;
    wire [31:0]     slot0_ex_update_target_o;
    wire [31:0]     slot1_ex_update_target_o;

    // ex_bpu to bpu
    wire            bpu_update_ras_i;
    wire [3:0]      bpu_ras_snapshot_i;
    wire            bpu_update_gshare_en_i;
    wire            bpu_actual_taken_i;
    wire            bpu_update_btb_en_i;
    wire [31:0]     bpu_update_target_i;
    wire [31:0]     bpu_update_btb_pc_i;
    wire [31:0]     bpu_update_gshare_pc_i;

    // hazard
    wire ex_valid_req_load = (pipe_flush_ex_mem) ? 1'b0 : slot0_ex_req_load_o;
    hazard HAZARD (
        .slot0_id_rs1_addr_i    (slot0_id_rs1_i),
        .slot0_id_rs2_addr_i    (slot0_id_rs2_i),
        .slot0_id_rd_addr_i     (slot0_id_rd_i),
        .slot0_id_regs_wen_i    (slot0_id_regs_wen_o),
        
        .slot1_id_rs1_addr_i    (slot1_id_rs1_i),
        .slot1_id_rs2_addr_i    (slot1_id_rs2_i),
        .slot1_using_rs_data_i  (slot1_using_rs_data_o),
        .slot1_id_is_load_i     (slot1_id_inst_packaged_o.is_load),
        .slot1_id_is_store_i    (slot1_id_inst_packaged_o.is_store),
        .slot1_id_is_zicsr_i    (slot1_id_inst_packaged_o.is_zicsr),
        
        .ex_rd_addr_i           (slot0_ex_rd_addr_o),
        .ex_is_load_i           (ex_valid_req_load),
        .mem1_rd_addr_i         (slot0_mem1_rd_addr_o),
        .mem1_is_load_i         (mem1_is_load_o),
        .hazard_en              (hazard_hazard_en),
        .dual_stall             (dual_stall),
        .dual_stall_finish      (dual_stall_finish)
    );

    // ============================================================
    // PC
    // ============================================================
    pc PC(
        .clk                (cpu_clk),
        .rst                (cpu_rst),
        .pipe_hold          (pipe_hold_pc),
        .dual_stall         (dual_stall),

        .pred_flush         (pred_flush_en),
        .pred_flush_pc      (pred_flush_pc),

        .wb_ecall           (slot0_wb_ecall_o),
        .wb_mret            (slot0_wb_mret_o),

        .ecall_mret_addr    (csr_regs_ecall_mret_addr),

        .slot0_pc_o         (slot0_pc_pc_o),
        .slot1_pc_o         (slot1_pc_pc_o),

        .pred_pc            (bpu_pred_pc),
        .pred_taken         (bpu_pred_taken)
    );

    // ============================================================
    // I-cache
    // ============================================================
    icache ICACHE(
        .clk                (cpu_clk),
        .rst                (cpu_rst),
        .pipe_hold          (pipe_hold_icache),
        .pipe_flush         (pipe_flush_icache),

        .slot0_cpu_pc       (slot0_if1_pc_o),
        .slot1_cpu_pc       (slot1_if1_pc_o),
        .slot0_cpu_inst     (slot0_icache_inst),
        .slot1_cpu_inst     (slot1_icache_inst),

        .slot0_mem_addr     (slot0_irom_addr),
        .slot1_mem_addr     (slot1_irom_addr),
        .slot0_mem_inst     (slot0_irom_data),
        .slot1_mem_inst     (slot1_irom_data)
    );

    // ============================================================
    // Regfile
    // ============================================================
    regs REGS(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .slot0_rd_addr_i    (slot0_wb_rd_addr_o),
        .slot1_rd_addr_i    (slot1_wb_rd_addr_o),
        .slot0_rd_data_i    (slot0_wb_rd_data_o),
        .slot1_rd_data_i    (slot1_wb_rd_data_o),
        .slot0_regs_wen     (slot0_wb_regs_wen_o),
        .slot1_regs_wen     (slot1_wb_regs_wen_o),

        .slot0_rs1_addr_i   (slot0_id_rs1_i),
        .slot1_rs1_addr_i   (slot1_id_rs1_i),
        .slot0_rs2_addr_i   (slot0_id_rs2_i),
        .slot1_rs2_addr_i   (slot1_id_rs2_i),

        .slot0_rs1_data_o   (slot0_reg_rs1_data_o),
        .slot1_rs1_data_o   (slot1_reg_rs1_data_o),
        .slot0_rs2_data_o   (slot0_reg_rs2_data_o),
        .slot1_rs2_data_o   (slot1_reg_rs2_data_o)
    );

    // ============================================================
    // CSR_Regfile
    // ============================================================
    csr_regs CSR_REGS(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .csr_addr           (slot0_ex_csr_addr_o),
        .csr_wdata          (slot0_ex_csr_wdata_o),
        .csr_wen            (slot0_ex_csr_wen_o),

        .csr_rdata          (slot0_csr_regs_csr_rdata),

        .ecall              (slot0_mem_ecall_o),      
        .mret               (slot0_mem_mret_o),       
        .ecall_inst         (slot0_mem_ecall_inst_o),     
        .ecall_mret_addr    (csr_regs_ecall_mret_addr)
    );

    // ============================================================
    // IF
    // ============================================================
    ifetch IF(
        .clk                   (cpu_clk),
        .rst                   (cpu_rst),
        .pipe_hold             (pipe_hold_if1_if2),
        .pipe_flush            (pipe_flush_if1_if2),
        .ecall_mret_flush      (ecall_mret_flush),

        // from pc
        .slot0_pc_i            (slot0_pc_pc_o),
        .slot1_pc_i            (slot1_pc_pc_o),

        // to bpu & icache
        .slot0_if1_pc_o        (slot0_if1_pc_o),
        .slot1_if1_pc_o        (slot1_if1_pc_o),

        // from icache
        .slot0_inst_i          (slot0_icache_inst),
        .slot1_inst_i          (slot1_icache_inst),

        // to if_id & bpu
        .slot0_pc_o            (slot0_if2_pc_o),
        .slot1_pc_o            (slot1_if2_pc_o),
        .slot0_inst_o          (slot0_if2_inst_o),
        .slot1_inst_o          (slot1_if2_inst_o),

        // pre-id
        .slot0_opcode_o        (slot0_if2_opcode_o),
        .slot0_funct3_o        (slot0_if2_funct3_o),
        .slot0_funct7_o        (slot0_if2_funct7_o),
        .slot0_rd_o            (slot0_if2_rd_o),
        .slot0_rs1_o           (slot0_if2_rs1_o),
        .slot0_rs2_o           (slot0_if2_rs2_o),

        .slot1_opcode_o        (slot1_if2_opcode_o),
        .slot1_funct3_o        (slot1_if2_funct3_o),
        .slot1_funct7_o        (slot1_if2_funct7_o),
        .slot1_rd_o            (slot1_if2_rd_o),
        .slot1_rs1_o           (slot1_if2_rs1_o),
        .slot1_rs2_o           (slot1_if2_rs2_o)
    );

    // ============================================================
    // IF/ID
    // ============================================================
    if_id IF_ID(
        .clk                (cpu_clk),
        .rst                (cpu_rst),
        .pipe_hold          (pipe_hold_if2_id),
        .pipe_flush         (pipe_flush_if2_id),
        .ecall_mret_flush   (ecall_mret_flush),

        .slot0_pc_i         (slot0_if2_pc_o),
        .slot0_inst_i       (slot0_if2_inst_o),
        .slot0_opcode_i     (slot0_if2_opcode_o),
        .slot0_funct3_i     (slot0_if2_funct3_o),
        .slot0_funct7_i     (slot0_if2_funct7_o),
        .slot0_rd_i         (slot0_if2_rd_o),
        .slot0_rs1_i        (slot0_if2_rs1_o),
        .slot0_rs2_i        (slot0_if2_rs2_o),

        .slot1_pc_i         (slot1_if2_pc_o),
        .slot1_inst_i       (slot1_if2_inst_o),
        .slot1_opcode_i     (slot1_if2_opcode_o),
        .slot1_funct3_i     (slot1_if2_funct3_o),
        .slot1_funct7_i     (slot1_if2_funct7_o),
        .slot1_rd_i         (slot1_if2_rd_o),
        .slot1_rs1_i        (slot1_if2_rs1_o),
        .slot1_rs2_i        (slot1_if2_rs2_o),

        .slot0_pc_o         (slot0_id_pc_i),
        .slot0_inst_o       (slot0_id_inst_i),
        .slot0_opcode_o     (slot0_id_opcode_i),
        .slot0_funct3_o     (slot0_id_funct3_i),
        .slot0_funct7_o     (slot0_id_funct7_i),
        .slot0_rd_o         (slot0_id_rd_i),
        .slot0_rs1_o        (slot0_id_rs1_i),
        .slot0_rs2_o        (slot0_id_rs2_i),

        .slot1_pc_o         (slot1_id_pc_i),
        .slot1_inst_o       (slot1_id_inst_i),
        .slot1_opcode_o     (slot1_id_opcode_i),
        .slot1_funct3_o     (slot1_id_funct3_i),
        .slot1_funct7_o     (slot1_id_funct7_i),
        .slot1_rd_o         (slot1_id_rd_i),
        .slot1_rs1_o        (slot1_id_rs1_i),
        .slot1_rs2_o        (slot1_id_rs2_i)
    );

    // ============================================================
    // ID
    // ============================================================
    id ID_SLOT0(
        .pc_addr_i          (slot0_id_pc_i),
        .inst_i             (slot0_id_inst_i),
        .opcode_i           (slot0_id_opcode_i),
        .funct3_i           (slot0_id_funct3_i),
        .funct7_i           (slot0_id_funct7_i),
        .rd_i               (slot0_id_rd_i),
        .rs1_i              (slot0_id_rs1_i),
        .rs2_i              (slot0_id_rs2_i),

        .pred_taken_i       (bpu_slot0_pred_taken),
        .pred_pc_i          (bpu_slot0_pred_pc),
        .ras_snapshot       (bpu_ras_snapshot),
        .is_ret             (bpu_slot0_id_is_ret),

        .rs1_data_i         (slot0_reg_rs1_data_o),
        .rs2_data_i         (slot0_reg_rs2_data_o),

        // to id_ex
        .data_packaged_o    (slot0_id_data_packaged_o),
        .inst_packaged_o    (slot0_id_inst_packaged_o),
        .regs_wen_o         (slot0_id_regs_wen_o),

        // to hazard
        .using_rs_data_o    (slot0_using_rs_data_o),

        // from ex
        .slot0_ex_regs_wen_i    (slot0_ex_regs_wen_o),
        .slot1_ex_regs_wen_i    (slot1_ex_regs_wen_o),
        .slot0_ex_rd_addr_i     (slot0_ex_rd_addr_o),
        .slot1_ex_rd_addr_i     (slot1_ex_rd_addr_o),

        // from mem1
        .slot0_mem1_regs_wen_i  (slot0_mem1_regs_wen_o),
        .slot1_mem1_regs_wen_i  (slot1_mem1_regs_wen_o),
        .slot0_mem1_rd_addr_i   (slot0_mem1_rd_addr_o),
        .slot1_mem1_rd_addr_i   (slot1_mem1_rd_addr_o),
        .slot0_mem1_rd_data_i   (slot0_mem1_rd_data_o),
        .slot1_mem1_rd_data_i   (slot1_mem1_rd_data_o),

        // from mem2
        .slot0_mem2_regs_wen_i  (slot0_mem2_regs_wen_o),
        .slot1_mem2_regs_wen_i  (slot1_mem2_regs_wen_o),
        .slot0_mem2_rd_addr_i   (slot0_mem2_rd_addr_o),
        .slot1_mem2_rd_addr_i   (slot1_mem2_rd_addr_o),
        .slot0_mem2_rd_data_i   (slot0_mem2_rd_data_o),
        .slot1_mem2_rd_data_i   (slot1_mem2_rd_data_o),

        // from wb
        .slot0_wb_regs_wen_i    (slot0_wb_regs_wen_o),
        .slot1_wb_regs_wen_i    (slot1_wb_regs_wen_o),
        .slot0_wb_rd_addr_i     (slot0_wb_rd_addr_o),
        .slot1_wb_rd_addr_i     (slot1_wb_rd_addr_o),
        .slot0_wb_rd_data_i     (slot0_wb_rd_data_o),
        .slot1_wb_rd_data_i     (slot1_wb_rd_data_o)
    );

    id ID_SLOT1(
        .pc_addr_i          (slot1_id_pc_i),
        .inst_i             (slot1_id_inst_i),
        .opcode_i           (slot1_id_opcode_i),
        .funct3_i           (slot1_id_funct3_i),
        .funct7_i           (slot1_id_funct7_i),
        .rd_i               (slot1_id_rd_i),
        .rs1_i              (slot1_id_rs1_i),
        .rs2_i              (slot1_id_rs2_i),

        .pred_taken_i       (bpu_slot1_pred_taken),
        .pred_pc_i          (bpu_slot1_pred_pc),
        .ras_snapshot       (bpu_ras_snapshot),
        .is_ret             (bpu_slot1_id_is_ret),

        .rs1_data_i         (slot1_reg_rs1_data_o),
        .rs2_data_i         (slot1_reg_rs2_data_o),

        // to id_ex
        .data_packaged_o    (slot1_id_data_packaged_o),
        .inst_packaged_o    (slot1_id_inst_packaged_o),
        .regs_wen_o         (slot1_id_regs_wen_o),

        // to hazard
        .using_rs_data_o    (slot1_using_rs_data_o),

        // from ex
        .slot0_ex_regs_wen_i    (slot0_ex_regs_wen_o),
        .slot1_ex_regs_wen_i    (slot1_ex_regs_wen_o),
        .slot0_ex_rd_addr_i     (slot0_ex_rd_addr_o),
        .slot1_ex_rd_addr_i     (slot1_ex_rd_addr_o),

        // from mem1
        .slot0_mem1_regs_wen_i  (slot0_mem1_regs_wen_o),
        .slot1_mem1_regs_wen_i  (slot1_mem1_regs_wen_o),
        .slot0_mem1_rd_addr_i   (slot0_mem1_rd_addr_o),
        .slot1_mem1_rd_addr_i   (slot1_mem1_rd_addr_o),
        .slot0_mem1_rd_data_i   (slot0_mem1_rd_data_o),
        .slot1_mem1_rd_data_i   (slot1_mem1_rd_data_o),

        // from mem2
        .slot0_mem2_regs_wen_i  (slot0_mem2_regs_wen_o),
        .slot1_mem2_regs_wen_i  (slot1_mem2_regs_wen_o),
        .slot0_mem2_rd_addr_i   (slot0_mem2_rd_addr_o),
        .slot1_mem2_rd_addr_i   (slot1_mem2_rd_addr_o),
        .slot0_mem2_rd_data_i   (slot0_mem2_rd_data_o),
        .slot1_mem2_rd_data_i   (slot1_mem2_rd_data_o),

        // from wb
        .slot0_wb_regs_wen_i    (slot0_wb_regs_wen_o),
        .slot1_wb_regs_wen_i    (slot1_wb_regs_wen_o),
        .slot0_wb_rd_addr_i     (slot0_wb_rd_addr_o),
        .slot1_wb_rd_addr_i     (slot1_wb_rd_addr_o),
        .slot0_wb_rd_data_i     (slot0_wb_rd_data_o),
        .slot1_wb_rd_data_i     (slot1_wb_rd_data_o)
    );

    // ============================================================
    // ID/EX
    // ============================================================
    id_ex ID_EX(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pred_flush         (pred_flush_en),
        .hazard_en          (hazard_hazard_en),
        .dcache_stall       (dcache_stall),
        .ecall_mret_flush   (ecall_mret_flush),
        .dual_stall         (dual_stall),
        .dual_stall_finish  (dual_stall_finish),

        .slot0_data_packaged_i      (slot0_id_data_packaged_o),
        .slot1_data_packaged_i      (slot1_id_data_packaged_o),
        
        .slot0_inst_packaged_i      (slot0_id_inst_packaged_o),
        .slot1_inst_packaged_i      (slot1_id_inst_packaged_o),

        .slot0_regs_wen_i           (slot0_id_regs_wen_o),
        .slot1_regs_wen_i           (slot1_id_regs_wen_o),
        
        .slot0_data_packaged_o      (slot0_ex_data_packaged_i),
        .slot1_data_packaged_o      (slot1_ex_data_packaged_i),
        
        .slot0_inst_packaged_o      (slot0_ex_inst_packaged_i),
        .slot1_inst_packaged_o      (slot1_ex_inst_packaged_i),

        .slot0_regs_wen_o           (slot0_ex_regs_wen_i),
        .slot1_regs_wen_o           (slot1_ex_regs_wen_i),

        .slot0_valid_o              (slot0_ex_valid_i),
        .slot1_valid_o              (slot1_ex_valid_i)
    );

    // ============================================================
    // EX
    // ============================================================
    ex EX_SLOT0(
        // from id_ex
        .data_packaged_i    (slot0_ex_data_packaged_i),
        .inst_packaged_i    (slot0_ex_inst_packaged_i),
        .regs_wen_i         (slot0_ex_regs_wen_i),
        .valid_i            (slot0_ex_valid_i),

        // forwarding
        .fwd_slot0_ex_rd_data_i(slot0_mem_rd_data_i),
        .fwd_slot1_ex_rd_data_i(slot1_mem_rd_data_i),

        // from csr_regs
        .csr_rdata          (slot0_csr_regs_csr_rdata),

        // to ex_mem & hazard
        .regs_wen_o         (slot0_ex_regs_wen_o),
        .ecall_o            (slot0_ex_ecall_o),
        .mret_o             (slot0_ex_mret_o),
        .mem_req_load       (slot0_ex_req_load_o),
        .mem_load_mask      (ex_load_mask_o),
        .mem_load_addr_low  (ex_load_addr_low_o),
        .mem_load_is_signed (ex_load_is_signed_o),
        .valid_o            (slot0_ex_valid_o),
        .rd_addr_o          (slot0_ex_rd_addr_o),
        .rd_data_o          (slot0_ex_rd_data_o),
        .dcache_req_load    (ex_dcache_req_load_o),
        .dcache_req_store   (ex_dcache_req_store_o),
        .dcache_addr        (ex_dcache_addr_o),
        .dcache_wdata       (ex_dcache_wdata_o),
        .dcache_we          (ex_dcache_we_o),
        .dcache_write_dram  (ex_dcache_write_dram_o),

        // to ex_bpu
        .update_ras_o       (slot0_ex_update_ras_o),
        .ras_snapshot_o     (slot0_ex_ras_snapshot_o),
        .update_gshare_en_o (slot0_ex_update_gshare_en_o),
        .actual_taken_o     (slot0_ex_actual_taken_o),
        .update_btb_en_o    (slot0_ex_update_btb_en_o),
        .update_target_o    (slot0_ex_update_target_o),
        .pred_flush_en      (slot0_ex_pred_flush_en_o),
        .pred_flush_pc      (slot0_ex_pred_flush_pc_o),

        // to csr_regs
        .csr_addr_o         (slot0_ex_csr_addr_o),
        .csr_wen_o          (slot0_ex_csr_wen_o),
        .csr_wdata_o        (slot0_ex_csr_wdata_o),
        .ecall_inst         (slot0_ex_ecall_inst)
    );

    ex EX_SLOT1(
        // from id_ex
        .data_packaged_i    (slot1_ex_data_packaged_i),
        .inst_packaged_i    (slot1_ex_inst_packaged_i),
        .regs_wen_i         (slot1_ex_regs_wen_i),
        .valid_i            (slot1_ex_valid_i),

        // forwarding
        .fwd_slot0_ex_rd_data_i(slot0_mem_rd_data_i),
        .fwd_slot1_ex_rd_data_i(slot1_mem_rd_data_i),

        // from csr_regs
        .csr_rdata          (),

        // to ex_mem & hazard
        .regs_wen_o         (slot1_ex_regs_wen_o),
        .ecall_o            (),
        .mret_o             (),
        .mem_req_load       (),
        .mem_load_mask      (),
        .mem_load_addr_low  (),
        .mem_load_is_signed (),
        .valid_o            (slot1_ex_valid_o),
        .rd_addr_o          (slot1_ex_rd_addr_o),
        .rd_data_o          (slot1_ex_rd_data_o),
        .dcache_req_load    (),
        .dcache_req_store   (),
        .dcache_addr        (),
        .dcache_wdata       (),
        .dcache_we          (),
        .dcache_write_dram  (),

        // to ex_bpu
        .update_ras_o       (slot1_ex_update_ras_o),
        .ras_snapshot_o     (slot1_ex_ras_snapshot_o),
        .update_gshare_en_o (slot1_ex_update_gshare_en_o),
        .actual_taken_o     (slot1_ex_actual_taken_o),
        .update_btb_en_o    (slot1_ex_update_btb_en_o),
        .update_target_o    (slot1_ex_update_target_o),
        .pred_flush_en      (slot1_ex_pred_flush_en_o),
        .pred_flush_pc      (slot1_ex_pred_flush_pc_o),

        // to csr_regs
        .csr_addr_o         (),
        .csr_wen_o          (),
        .csr_wdata_o        (),
        .ecall_inst         ()
    );

    // ============================================================
    // EX/MEM
    // ============================================================
    ex_mem EX_MEM_SLOT0(
        .clk                (cpu_clk),
        .rst                (cpu_rst),
        .pipe_hold          (pipe_hold_ex_mem),
        .pipe_flush         (pipe_flush_ex_mem),

        .rd_addr_i          (slot0_ex_rd_addr_o),
        .rd_data_i          (slot0_ex_rd_data_o),
        .regs_wen_i         (slot0_ex_regs_wen_o),
        .ecall_i            (slot0_ex_ecall_o),
        .mret_i             (slot0_ex_mret_o),
        .ecall_inst_i       (slot0_ex_ecall_inst),
        .mem_req_load_i     (slot0_ex_req_load_o),
        .load_mask_i        (ex_load_mask_o),
        .load_addr_low_i    (ex_load_addr_low_o),
        .load_is_signed_i   (ex_load_is_signed_o),
        .dcache_req_load_i  (ex_dcache_req_load_o),
        .dcache_req_store_i (ex_dcache_req_store_o),
        .dcache_addr_i      (ex_dcache_addr_o),
        .dcache_wdata_i     (ex_dcache_wdata_o),
        .dcache_we_i        (ex_dcache_we_o),
        .dcache_write_dram_i(ex_dcache_write_dram_o),

        .rd_addr_o          (slot0_mem_rd_addr_i),
        .rd_data_o          (slot0_mem_rd_data_i),
        .regs_wen_o         (slot0_mem_regs_wen_i),
        .ecall_o            (slot0_mem_ecall_i),
        .mret_o             (slot0_mem_mret_i),
        .ecall_inst_o       (slot0_mem_ecall_inst_i),
        .mem_req_load_o     (mem_req_load_i),
        .load_mask_o        (mem_load_mask_i),
        .load_addr_low_o    (mem_load_addr_low_i),
        .load_is_signed_o   (mem_load_is_signed_i),
        .dcache_req_load_o  (dcache_req_load_i),
        .dcache_req_store_o (dcache_req_store_i),
        .dcache_addr_o      (dcache_addr_i),
        .dcache_wdata_o     (dcache_wdata_i),
        .dcache_we_o        (dcache_we_i),
        .dcache_write_dram_o(dcache_write_dram_i)
    );

    ex_mem EX_MEM_SLOT1(
        .clk                (cpu_clk),
        .rst                (cpu_rst),
        .pipe_hold          (pipe_hold_ex_mem),
        .pipe_flush         (pipe_flush_ex_mem),

        .rd_addr_i          (slot1_ex_rd_addr_o),
        .rd_data_i          (slot1_ex_rd_data_o),
        .regs_wen_i         (slot1_ex_regs_wen_o),
        .ecall_i            (),
        .mret_i             (),
        .ecall_inst_i       (),
        .mem_req_load_i     (),
        .load_mask_i        (),
        .load_addr_low_i    (),
        .load_is_signed_i   (),
        .dcache_req_load_i  (),
        .dcache_req_store_i (),
        .dcache_addr_i      (),
        .dcache_wdata_i     (),
        .dcache_we_i        (),
        .dcache_write_dram_i(),

        .rd_addr_o          (slot1_mem_rd_addr_i),
        .rd_data_o          (slot1_mem_rd_data_i),
        .regs_wen_o         (slot1_mem_regs_wen_i),
        .ecall_o            (),
        .mret_o             (),
        .ecall_inst_o       (),
        .mem_req_load_o     (),
        .load_mask_o        (),
        .load_addr_low_o    (),
        .load_is_signed_o   (),
        .dcache_req_load_o  (),
        .dcache_req_store_o (),
        .dcache_addr_o      (),
        .dcache_wdata_o     (),
        .dcache_we_o        (),
        .dcache_write_dram_o()
    );

    // ============================================================
    // MEM
    // ============================================================
    mem MEM_SLOT0(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .forward_flush      (1'b0),

        .dcache_ack         (dcache_ack_mem),
        .dcache_rdata       (dcache_rdata),
        .dcache_stall       (dcache_stall),

        .rd_addr_i          (slot0_mem_rd_addr_i),
        .rd_data_i          (slot0_mem_rd_data_i),
        .regs_wen           (slot0_mem_regs_wen_i),
        .ecall_i            (slot0_mem_ecall_i),
        .mret_i             (slot0_mem_mret_i),
        .ecall_inst_i       (slot0_mem_ecall_inst_i),
        .mem_req_load_i     (mem_req_load_i),
        .load_mask_i        (mem_load_mask_i),
        .load_addr_low_i    (mem_load_addr_low_i),
        .load_is_signed_i   (mem_load_is_signed_i),

        .mem1_is_load_o     (mem1_is_load_o),
        .mem2_is_load_o     (mem2_is_load_o),

        .mem1_rd_addr_o     (slot0_mem1_rd_addr_o),
        .mem1_rd_data_o     (slot0_mem1_rd_data_o),
        .mem1_regs_wen_o    (slot0_mem1_regs_wen_o),

        .mem2_rd_addr_o     (slot0_mem2_rd_addr_o),
        .mem2_rd_data_o     (slot0_mem2_rd_data_o),
        .mem2_regs_wen_o    (slot0_mem2_regs_wen_o),
        .ecall_o            (slot0_mem_ecall_o),
        .mret_o             (slot0_mem_mret_o),
        .ecall_inst_o       (slot0_mem_ecall_inst_o)
    );

    mem MEM_SLOT1(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .forward_flush      (slot0_pred_flush_en),

        .dcache_ack         (0),
        .dcache_rdata       (0),
        .dcache_stall       (dcache_stall),

        .rd_addr_i          (slot1_mem_rd_addr_i),
        .rd_data_i          (slot1_mem_rd_data_i),
        .regs_wen           (slot1_mem_regs_wen_i),
        .ecall_i            (0),
        .mret_i             (0),
        .ecall_inst_i       (0),
        .mem_req_load_i     (0),
        .load_mask_i        (),
        .load_addr_low_i    (),
        .load_is_signed_i   (),

        .mem1_is_load_o     (),
        .mem2_is_load_o     (),

        .mem1_rd_addr_o     (slot1_mem1_rd_addr_o),
        .mem1_rd_data_o     (slot1_mem1_rd_data_o),
        .mem1_regs_wen_o    (slot1_mem1_regs_wen_o),

        .mem2_rd_addr_o     (slot1_mem2_rd_addr_o),
        .mem2_rd_data_o     (slot1_mem2_rd_data_o),
        .mem2_regs_wen_o    (slot1_mem2_regs_wen_o),
        .ecall_o            (),
        .mret_o             (),
        .ecall_inst_o       ()
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
    mem_wb MEM_WB_SLOT0(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .ecall_mret_flush   (ecall_mret_flush),

        .rd_addr_i          (slot0_mem2_rd_addr_o),
        .rd_data_i          (slot0_mem2_rd_data_o),
        .regs_wen_i         (slot0_mem2_regs_wen_o),
        .is_load_i          (mem2_is_load_o),
        .ecall_i            (slot0_mem_ecall_o),
        .mret_i             (slot0_mem_mret_o),
        .ecall_inst_i       (slot0_mem_ecall_inst_o),

        .rd_addr_o          (slot0_wb_rd_addr_i),
        .rd_data_o          (slot0_wb_rd_data_i),
        .regs_wen_o         (slot0_wb_regs_wen_i),
        .is_load_o          (wb_is_load_i),
        .ecall_o            (slot0_wb_ecall_i),
        .mret_o             (slot0_wb_mret_i),
        .ecall_inst_o       (slot0_wb_ecall_inst_i)
    );

    mem_wb MEM_WB_SLOT1(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .ecall_mret_flush   (ecall_mret_flush),

        .rd_addr_i          (slot1_mem2_rd_addr_o),
        .rd_data_i          (slot1_mem2_rd_data_o),
        .regs_wen_i         (slot1_mem2_regs_wen_o),
        .is_load_i          (),
        .ecall_i            (0),
        .mret_i             (0),
        .ecall_inst_i       (0),

        .rd_addr_o          (slot1_wb_rd_addr_i),
        .rd_data_o          (slot1_wb_rd_data_i),
        .regs_wen_o         (slot1_wb_regs_wen_i),
        .is_load_o          (wb_is_load_i),
        .ecall_o            (),
        .mret_o             (),
        .ecall_inst_o       ()
    );

    // ============================================================
    // WB
    // ============================================================
    wb WB_SLOT0(
        .rd_addr_i          (slot0_wb_rd_addr_i),
        .rd_data_i          (slot0_wb_rd_data_i),
        .regs_wen_i         (slot0_wb_regs_wen_i),
        .ecall_i            (slot0_wb_ecall_i),
        .mret_i             (slot0_wb_mret_i),
        .ecall_inst_i       (slot0_wb_ecall_inst_i),
        .rd_addr_o          (slot0_wb_rd_addr_o),
        .rd_data_o          (slot0_wb_rd_data_o),
        .regs_wen_o         (slot0_wb_regs_wen_o),

        .ecall_o            (slot0_wb_ecall_o),
        .mret_o             (slot0_wb_mret_o),
        .ecall_inst_o       (slot0_wb_ecall_inst_o)
    );

    wb WB_SLOT1(
        .rd_addr_i          (slot1_wb_rd_addr_i),
        .rd_data_i          (slot1_wb_rd_data_i),
        .regs_wen_i         (slot1_wb_regs_wen_i),
        .ecall_i            (0),
        .mret_i             (0),
        .ecall_inst_i       (0),
        .rd_addr_o          (slot1_wb_rd_addr_o),
        .rd_data_o          (slot1_wb_rd_data_o),
        .regs_wen_o         (slot1_wb_regs_wen_o),

        .ecall_o            (),
        .mret_o             (),
        .ecall_inst_o       ()
    );

    // ============================================================
    // BPU
    // ============================================================
    ex_bpu EX_BPU(
        .rst                (cpu_rst),
        .clk                (cpu_clk),

        .pipe_flush         (pipe_flush_ex_bpu),
        .pipe_hold          (pipe_hold_ex_bpu),

        .slot0_update_ras_i         (slot0_ex_update_ras_o),
        .slot1_update_ras_i         (slot1_ex_update_ras_o),
        .slot0_ras_snapshot_i       (slot0_ex_ras_snapshot_o),
        .slot1_ras_snapshot_i       (slot1_ex_ras_snapshot_o),
        .slot0_update_gshare_en_i   (slot0_ex_update_gshare_en_o),
        .slot0_actual_taken_i       (slot0_ex_actual_taken_o),
        .slot0_update_btb_en_i      (slot0_ex_update_btb_en_o),
        .slot1_update_btb_en_i      (slot1_ex_update_btb_en_o),
        .slot0_update_target_i      (slot0_ex_update_target_o),
        .slot1_update_target_i      (slot1_ex_update_target_o),
        .slot0_update_pc_i          (slot0_ex_data_packaged_i.pc),
        .slot1_update_pc_i          (slot1_ex_data_packaged_i.pc),

        .slot0_pred_flush_en_i (slot0_ex_pred_flush_en_o),
        .slot1_pred_flush_en_i (slot1_ex_pred_flush_en_o),
        .slot0_pred_flush_pc_i (slot0_ex_pred_flush_pc_o),
        .slot1_pred_flush_pc_i (slot1_ex_pred_flush_pc_o),

        .update_ras_o       (bpu_update_ras_i),
        .ras_snapshot_o     (bpu_ras_snapshot_i),
        .update_gshare_en_o (bpu_update_gshare_en_i),
        .actual_taken_o     (bpu_actual_taken_i),
        .update_btb_en_o    (bpu_update_btb_en_i),
        .update_target_o    (bpu_update_target_i),
        .btb_update_pc_o    (bpu_update_btb_pc_i),
        .gshare_update_pc_o (bpu_update_gshare_pc_i),

        .slot0_pred_flush_en_o (slot0_pred_flush_en),
        .slot1_pred_flush_en_o (slot1_pred_flush_en),
        .slot0_pred_flush_pc_o (slot0_pred_flush_pc),
        .slot1_pred_flush_pc_o (slot1_pred_flush_pc)
    );

    bpu_top #(
        .BHR_WIDTH          (`GSHARE_BHR_WIDTH),
        .PHT_IDX_WIDTH      (`GSHARE_PHT_IDX_WIDTH),
        .BTB_INDEX_WIDTH    (6),
        .RAS_DEPTH          (8)
    ) BPU(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .slot0_pc_addr      (slot0_if1_pc_o),
        .slot1_pc_addr      (slot1_if1_pc_o),

        .slot0_pc_addr_if2  (slot0_if2_pc_o),
        .slot1_pc_addr_if2  (slot1_if2_pc_o),

        .slot0_pc_inst      (slot0_if2_inst_o),
        .slot1_pc_inst      (slot1_if2_inst_o),

        .pred_pc            (bpu_pred_pc),
        .pred_taken         (bpu_pred_taken),
        .slot0_pred_taken   (bpu_slot0_pred_taken),
        .slot1_pred_taken   (bpu_slot1_pred_taken),
        .slot0_pred_pc      (bpu_slot0_pred_pc),
        .slot1_pred_pc      (bpu_slot1_pred_pc),
        .ras_snapshot       (bpu_ras_snapshot),
        .slot0_is_ret       (bpu_slot0_id_is_ret),
        .slot1_is_ret       (bpu_slot1_id_is_ret),

        .update_ras_i       (bpu_update_ras_i),
        .ras_snapshot_i     (bpu_ras_snapshot_i),
        .update_gshare_en   (bpu_update_gshare_en_i),
        .actual_taken       (bpu_actual_taken_i),
        .update_btb_en      (bpu_update_btb_en_i),
        .btb_update_pc      (bpu_update_btb_pc_i),
        .update_target      (bpu_update_target_i),
        .gshare_update_pc   (bpu_update_gshare_pc_i),

        .pipe_hold          (pipe_hold_bpu),
        .pipe_flush         (pipe_flush_bpu)
    );

endmodule