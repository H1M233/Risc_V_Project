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
    wire [31:0]     pc_pc_o;
    wire [31:0]     icache_inst;

    // ============================================================
    // hazard / stall
    // ============================================================
    (* max_fanout = 30 *)
    wire            hazard_hazard_en;

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
    if_id_t         if_data_packaged_o;

    // ============================================================
    // if_id to id
    // ============================================================
    if_id_t         id_data_packaged_i;

    // ============================================================
    // id to id_ex
    // ============================================================
    id_ex_data_t    id_data_packaged_o;
    decode_t        id_inst_packaged_o;
    wire            id_regs_wen_o;

    // ============================================================
    // ex to dcache
    // ============================================================
    ex_lsu_data_t ex_dcache_data_packaged_o;

    // ============================================================
    // id_ex to ex
    // ============================================================
    id_ex_data_t    ex_data_packaged_i;
    decode_t        ex_inst_packaged_i;
    wire            ex_regs_wen_i;
    wire            ex_valid_i;

    // ============================================================
    // ex-pred_flush
    // ============================================================
    wire            ex_pred_flush_en_o;
    wire [31:0]     ex_pred_flush_pc_o;
    wire            pred_flush_en;
    wire [31:0]     pred_flush_pc;

    // ============================================================
    // ex to ex_mem & hazard
    // ============================================================
    ex_mem_data_t   ex_mem_data_packaged_o;
    wire            ex_valid_o;

    // ex to csr_regs
    ex_csr_data_t   ex_csr_data_packaged_o;
    wire            ex_ctrl_stall;

    // ============================================================
    // ex_mem to mem
    // ============================================================
    ex_mem_data_t   mem_data_packaged_i;
    ex_lsu_data_t   dcache_data_packaged_i;

    // ============================================================
    // mem to mem_wb
    // ============================================================
    wire            mem2_is_load_o;
    mem_wb_data_t   mem_data_packaged_o;

    // ============================================================
    // D-cache to mem
    // ============================================================
    wire [31:0]     dcache_rdata;
    wire            dcache_load_ready;
    wire            dcache_store_ready;
    (* max_fanout = 30 *)
    wire            dcache_stall;

    // ============================================================
    // mem_wb to wb
    // ============================================================
    wire [31:0]     wb_rd_data_i;
    wire [4:0]      wb_rd_addr_i;
    wire            wb_regs_wen_i;
    wire            wb_ecall_i;
    wire            wb_mret_i;

    // ============================================================
    // wb to regs
    // ============================================================
    wire [31:0]     wb_rd_data_o;
    wire [4:0]      wb_rd_addr_o;
    wire            wb_regs_wen_o;

    // ============================================================
    // wb to pc & csg_regs
    // ============================================================
    wire            wb_ecall_o;
    wire            wb_mret_o;

    wire            mret_ecall_flush = wb_ecall_o | wb_mret_o;

    // ============================================================
    // bpu to pc & id
    // ============================================================
    wire [31:0]     bpu_pred_pc;
    wire            bpu_pred_taken;
    wire [3:0]      bpu_ras_ptr_o;

    // ��ˮ����ͣ����
    (* max_fanout = 30 *) wire pipe_hold_pc = dcache_stall | hazard_hazard_en | ex_ctrl_stall;
    (* max_fanout = 30 *) wire pipe_hold_icache = dcache_stall | hazard_hazard_en | ex_ctrl_stall;
    (* max_fanout = 30 *) wire pipe_hold_if1_if2 = dcache_stall | hazard_hazard_en | ex_ctrl_stall;
    (* max_fanout = 30 *) wire pipe_hold_if2_id = dcache_stall | hazard_hazard_en | ex_ctrl_stall;
    (* max_fanout = 30 *) wire pipe_hold_bpu = dcache_stall | hazard_hazard_en | ex_ctrl_stall;
    (* max_fanout = 30 *) wire pipe_hold_id_ex = dcache_stall | ex_ctrl_stall;
    (* max_fanout = 30 *) wire pipe_hold_ex_mem = dcache_stall;
    (* max_fanout = 30 *) wire pipe_hold_ex_bpu = dcache_stall;

    (* max_fanout = 30 *) wire pipe_flush_icache = bpu_pred_taken | pred_flush_en | mret_ecall_flush;
    (* max_fanout = 30 *) wire pipe_flush_if1_if2 = bpu_pred_taken | pred_flush_en | mret_ecall_flush;
    (* max_fanout = 30 *) wire pipe_flush_if2_id = bpu_pred_taken | pred_flush_en | mret_ecall_flush;
    (* max_fanout = 30 *) wire pipe_flush_bpu = bpu_pred_taken | pred_flush_en | mret_ecall_flush;
    (* max_fanout = 30 *) wire pipe_flush_bpu_outer = pred_flush_en | mret_ecall_flush;
    (* max_fanout = 30 *) wire pipe_flush_ex_mem = pred_flush_en | mret_ecall_flush;
    (* max_fanout = 30 *) wire pipe_flush_ex_bpu = pred_flush_en | mret_ecall_flush;
    (* max_fanout = 30 *) wire pipe_flush_mem_wb = mret_ecall_flush;

    // ============================================================
    // ex to bpu
    // ============================================================
    ex_bpu_data_t   ex_bpu_data_packaged_o;

    // ex_bpu to bpu
    ex_bpu_data_t   bpu_data_packaged_i;

    // ============================================================
    // PC
    // ============================================================
    pc PC(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pipe_hold          (pipe_hold_pc),

        .pred_flush         (pred_flush_en),
        .pred_flush_pc      (pred_flush_pc),

        .wb_ecall           (wb_ecall_o),
        .wb_mret            (wb_mret_o),

        .ecall_mret_addr    (csr_regs_ecall_mret_addr),

        .pc_addr_o          (pc_pc_o),

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
    // Regfile
    // ============================================================
    regs REGS(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .rd_addr_i          (wb_rd_addr_o),
        .rd_data_i          (wb_rd_data_o),
        .regs_wen           (wb_regs_wen_o),

        .rs1_addr_i         (id_data_packaged_i.rs1),
        .rs2_addr_i         (id_data_packaged_i.rs2),

        .rs1_data_o         (reg_rs1_data_o),
        .rs2_data_o         (reg_rs2_data_o)
    );

    // ============================================================
    // CSR_Regfile
    // ============================================================
    csr_regs CSR_REGS(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .csr_addr           (ex_data_packaged_i.csr_addr),
        .data_packaged_i    (ex_csr_data_packaged_o),

        .csr_rdata          (csr_regs_csr_rdata),

        .ecall              (mem_data_packaged_o.ecall),      
        .mret               (mem_data_packaged_o.mret),       
        .ecall_inst         (mem_data_packaged_o.ecall_inst),     
        .ecall_mret_addr    (csr_regs_ecall_mret_addr)
    );

    // ============================================================
    // IF
    // ============================================================
    ifetch IF(
        .clk                (cpu_clk),
        .rst                (cpu_rst),
        
        .pipe_hold          (pipe_hold_if1_if2),
        .pipe_flush         (pipe_flush_if1_if2),

        .pc_i               (pc_pc_o),

        .inst_i             (icache_inst),

        .if1_pc_o           (if1_pc_o),

        .data_packaged_o    (if_data_packaged_o)
    );

    // ============================================================
    // IF/ID
    // ============================================================
    ifetch_id IF_ID(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pipe_hold          (pipe_hold_if2_id),
        .pipe_flush         (pipe_flush_if2_id),

        .data_packaged_i    (if_data_packaged_o),

        .data_packaged_o    (id_data_packaged_i)
    );

    // ============================================================
    // ID
    // ============================================================
    wire ex_valid_req_load = (pipe_flush_ex_mem) ? 1'b0 : ex_dcache_data_packaged_o.req_load;
    id ID(
        .data_packaged_i    (id_data_packaged_i),

        .pred_taken_i       (bpu_pred_taken),
        .pred_pc_i          (bpu_pred_pc),
        .ras_ptr_i          (bpu_ras_ptr_o),

        .rs1_data_i         (reg_rs1_data_o),
        .rs2_data_i         (reg_rs2_data_o),

        .data_packaged_o    (id_data_packaged_o),
        .inst_packaged_o    (id_inst_packaged_o),
        .regs_wen_o         (id_regs_wen_o),

        .ex_regs_wen_i      (ex_mem_data_packaged_o.regs_wen),
        .ex_rd_addr_i       (ex_mem_data_packaged_o.rd_addr),
        .ex_is_load_i       (ex_valid_req_load),

        .mem1_rd_addr_i     (mem_data_packaged_i.rd_addr),
        .mem1_rd_data_i     (mem_data_packaged_i.rd_data),
        .mem1_regs_wen_i    (mem_data_packaged_i.regs_wen),
        .mem1_is_load_i     (mem_data_packaged_i.req_load),

        .mem2_rd_addr_i     (mem_data_packaged_o.rd_addr),
        .mem2_rd_data_i     (mem_data_packaged_o.rd_data),
        .mem2_regs_wen_i    (mem_data_packaged_o.regs_wen),

        .wb_rd_addr_i       (wb_rd_addr_o),
        .wb_rd_data_i       (wb_rd_data_o),
        .wb_regs_wen_i      (wb_regs_wen_o),

        .hazard_en          (hazard_hazard_en)
    );

    // ============================================================
    // ID/EX
    // ============================================================
    id_ex ID_EX(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .pipe_hold          (pipe_hold_id_ex),
        .pred_flush         (pred_flush_en),
        .hazard_en          (hazard_hazard_en),

        .data_packaged_i    (id_data_packaged_o),
        .inst_packaged_i    (id_inst_packaged_o),
        .regs_wen_i         (id_regs_wen_o),

        .data_packaged_o    (ex_data_packaged_i),
        .inst_packaged_o    (ex_inst_packaged_i),
        .regs_wen_o         (ex_regs_wen_i),
        .valid_o            (ex_valid_i)
    );

    // ============================================================
    // EX
    // ============================================================
    ex EX(
        .clk                    (cpu_clk),
        .rst                    (cpu_rst),
        .pipe_flush             (pipe_flush_ex_mem),

        // from id_ex
        .data_packaged_i        (ex_data_packaged_i),
        .inst_packaged_i        (ex_inst_packaged_i),
        .regs_wen_i             (ex_regs_wen_i),
        .valid_i                (ex_valid_i),

        // forwarding ex data
        .fwd_ex_rd_data_i       (mem_data_packaged_i.rd_data),
        
        // from csr_regs
        .csr_rdata              (csr_regs_csr_rdata),

        // from d-cache
        .dcache_load_ready_i    (dcache_load_ready),
        .dcache_store_ready_i   (dcache_load_ready),
        .dcache_rdata_i         (dcache_rdata),

        // to ex_mem & hazard
        .mem_data_packaged_o    (ex_mem_data_packaged_o),
        .valid_o                (ex_valid_o),

        // to ex_dcache & hazard
        .dcache_data_packaged_o (ex_dcache_data_packaged_o),

        // to ex_bpu
        .bpu_data_packaged_o    (ex_bpu_data_packaged_o),
        .pred_flush_en          (ex_pred_flush_en_o),
        .pred_flush_pc          (ex_pred_flush_pc_o),

        // to csr_regs
        .csr_data_packaged_o    (ex_csr_data_packaged_o),

        // ctrl_stall
        .ctrl_stall             (ex_ctrl_stall)
    );

    // ============================================================
    // EX/MEM
    // ============================================================
    ex_mem EX_MEM(
        .clk                    (cpu_clk),
        .rst                    (cpu_rst),
        .pipe_hold              (pipe_hold_ex_mem),
        .pipe_flush             (pipe_flush_ex_mem),

        .mem_data_packaged_i     (ex_mem_data_packaged_o),
        .dcache_data_packaged_i  (ex_dcache_data_packaged_o),

        .mem_data_packaged_o     (mem_data_packaged_i),
        .dcache_data_packaged_o  (dcache_data_packaged_i)
    );

    // ============================================================
    // MEM
    // ============================================================
    mem MEM(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .dcache_ack         (dcache_load_ready),
        .dcache_rdata       (dcache_rdata),
        .dcache_stall       (dcache_stall),

        .data_packaged_i    (mem_data_packaged_i),

        .mem2_is_load_o     (mem2_is_load_o),

        .data_packaged_o    (mem_data_packaged_o)
    );

    // ============================================================
    // D-cache
    // ============================================================
    dcache DCACHE(
        .clk                (cpu_clk),
        .rst                (cpu_rst),

        .data_packaged_i    (dcache_data_packaged_i),

        .mem_rdata          (dcache_rdata),
        .load_ready         (dcache_load_ready),
        .store_ready        (dcache_store_ready),

        .stall              (dcache_stall),

        .perip_addr         (perip_addr),
        .perip_we           (perip_we),
        .perip_wen          (perip_wen),
        .perip_wdata        (perip_wdata),
        .perip_rdata        (perip_rdata)
    );

    // ============================================================
    // MEM/WB
    // ============================================================
    mem_wb MEM_WB(
        .clk                (cpu_clk),
        .rst                (cpu_rst),
        .pipe_flush         (pipe_flush_mem_wb),

        .data_packaged_i    (mem_data_packaged_o),

        .rd_addr_o          (wb_rd_addr_i),
        .rd_data_o          (wb_rd_data_i),
        .regs_wen_o         (wb_regs_wen_i),
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
        .mret_o             (wb_mret_o)
    );

    // ============================================================
    // BPU
    // ============================================================
    ex_bpu EX_BPU(
        .clk                (cpu_clk),
        .rst                (cpu_rst),
        .pipe_hold          (pipe_hold_ex_bpu),
        .pipe_flush         (pipe_flush_ex_bpu),

        .data_packaged_i    (ex_bpu_data_packaged_o),
        .pred_flush_en_i    (ex_pred_flush_en_o),
        .pred_flush_pc_i    (ex_pred_flush_pc_o),

        .data_packaged_o    (bpu_data_packaged_i),

        .pred_flush_en_o    (pred_flush_en),
        .pred_flush_pc_o    (pred_flush_pc)
    );

    bpu_top #(
        .BHR_WIDTH          (`GSHARE_BHR_WIDTH),
        .PHT_IDX_WIDTH      (`GSHARE_PHT_IDX_WIDTH),
        .BTB_INDEX_WIDTH    (4),
        .RAS_DEPTH          (8)
    ) BPU(
        .clk                (cpu_clk),
        .rst                (cpu_rst),
        .pipe_hold          (pipe_hold_bpu),
        .pipe_flush         (pipe_flush_bpu),
        .outer_flush        (pipe_flush_bpu_outer),

        .pc_if1             (if1_pc_o),
        .pc_if2             (if_data_packaged_o.pc),
        .pc_inst            (if_data_packaged_o.inst),

        .pred_pc            (bpu_pred_pc),
        .pred_taken         (bpu_pred_taken),
        .ptr_o              (bpu_ras_ptr_o),

        .data_packaged_i    (bpu_data_packaged_i)
    );

endmodule
