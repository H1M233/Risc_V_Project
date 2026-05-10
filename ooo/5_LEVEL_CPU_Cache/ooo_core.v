`include "ooo_defs.vh"

// Conservative out-of-order dual-issue RV32I core.
// Key design:
// - OOO_USE_BPU=0 default: static not-taken
// - Control redirect at ALU resolve (frontend flush only)
// - RAT has busy/tag/ready/value + CDB monitoring
// - ROB store: store_commit_req protocol
// - CDB: ALU0>ALU1>LSU, LSU has pending buffer
// - Dispatch: IQ/LSQ compact push, resource check per slot
module ooo_core #(
    parameter OOO_USE_BPU = 0
)(
    input           cpu_rst,
    input           cpu_clk,
    output  [31:0]  irom_addr,
    input   [31:0]  irom_data,
    output  [31:0]  perip_addr,
    output  [3:0]   perip_we,
    output          perip_wen,
    output  [31:0]  perip_wdata,
    input   [31:0]  perip_rdata
);

    // ========================================================================
    // PC
    // ========================================================================
    reg [31:0] pc_reg;
    wire frontend_flush;
    wire [31:0] flush_target_pc;

    // icache
    wire [31:0] ic_inst;
    wire        ic_stall;

    // BPU (disabled when OOO_USE_BPU=0)
    wire [31:0] bpu_pred_pc;
    wire        bpu_pred_taken;
    wire [31:0] use_pred_pc    = (OOO_USE_BPU) ? bpu_pred_pc    : (pc_reg + 32'd4);
    wire        use_pred_taken = (OOO_USE_BPU) ? bpu_pred_taken : 1'b0;

    // fetch queue
    wire fq_empty, fq_full, fq_almost_full;
    wire [31:0] fq_pc_0,   fq_pc_1;
    wire [31:0] fq_inst_0, fq_inst_1;
    wire        fq_valid_0, fq_valid_1;
    wire        fq_pt_0,   fq_pt_1;
    wire [31:0] fq_ppc_0,  fq_ppc_1;

    wire        disp_en_0, disp_en_1;

    wire [4:0]  rob_tag_0, rob_tag_1;
    wire        rob_full, rob_almost_full;
    wire [`ROB_IDX_WIDTH:0] rob_count, rob_free_count;
    wire        commit_en_0, commit_en_1;
    wire [4:0]  commit_tag_0, commit_tag_1;
    wire [4:0]  commit_rd_0, commit_rd_1;
    wire [31:0] commit_val_0, commit_val_1;
    wire        commit_wen_0, commit_wen_1;
    wire        commit_is_store_0, commit_is_store_1;
    wire [31:0] commit_pc_0, commit_pc_1;
    wire        store_commit_req;
    wire [4:0]  store_commit_tag;
    wire        lsu_store_done;
    wire [4:0]  lsu_store_done_tag;

    wire [4:0] iq_free_count;
    wire [4:0] lsq_free_count;

    wire        alu0_ctrl_resolved, alu1_ctrl_resolved;
    wire        alu0_need_redirect, alu1_need_redirect;
    wire [31:0] alu0_redirect_pc, alu1_redirect_pc;
    wire        alu0_upd_btb, alu1_upd_btb;
    wire        alu0_upd_gs, alu1_upd_gs;
    wire [31:0] alu0_upd_pc, alu1_upd_pc;
    wire [31:0] alu0_upd_target, alu1_upd_target;
    wire        alu0_upd_taken, alu1_upd_taken;
    wire        alu0_mispred, alu1_mispred;

    // PC logic
    wire fetch_stall = fq_almost_full || ic_stall;
    wire fq_push = !ic_stall && !fq_almost_full && !frontend_flush;

    always @(posedge cpu_clk) begin
        if (!cpu_rst)
            pc_reg <= 32'h8000_0000;
        else if (frontend_flush)
            pc_reg <= flush_target_pc;
        else if (!fetch_stall)
            pc_reg <= use_pred_pc;
    end

    // ========================================================================
    // ICache
    // ========================================================================
    icache ICACHE (
        .clk(cpu_clk), .rst(cpu_rst),
        .cpu_addr(pc_reg), .cpu_inst(ic_inst),
        .flush(frontend_flush), .stall(ic_stall),
        .mem_addr(irom_addr), .mem_inst(irom_data)
    );

    // ========================================================================
    // BPU
    // ========================================================================
    reg        bpu_upd_btb, bpu_upd_gs;
    reg [31:0] bpu_upd_pc, bpu_upd_target;
    reg        bpu_upd_taken, bpu_upd_mispred;

    generate
        if (OOO_USE_BPU) begin : gen_bpu
            bpu_top #(.BHR_WIDTH(10), .PHT_SIZE(1024), .RAS_DEPTH(8)) BPU (
                .clk(cpu_clk), .rst(cpu_rst),
                .pc_addr(pc_reg), .pc_inst(ic_inst),
                .pred_pc(bpu_pred_pc), .pred_taken(bpu_pred_taken),
                .update_btb_en(bpu_upd_btb), .update_gshare_en(bpu_upd_gs),
                .update_pc(bpu_upd_pc), .update_target(bpu_upd_target),
                .actual_taken(bpu_upd_taken), .pred_mispredict(bpu_upd_mispred),
                .hazard_en(1'b0), .dcache_stall(1'b0)
            );
        end else begin : gen_no_bpu
            assign bpu_pred_pc = 32'b0;
            assign bpu_pred_taken = 1'b0;
        end
    endgenerate

    // BPU update mux
    always @(*) begin
        bpu_upd_btb = 0; bpu_upd_gs = 0;
        bpu_upd_pc = 0; bpu_upd_target = 0;
        bpu_upd_taken = 0; bpu_upd_mispred = 0;
        if (alu0_ctrl_resolved) begin
            bpu_upd_btb = alu0_upd_btb; bpu_upd_gs = alu0_upd_gs;
            bpu_upd_pc = alu0_upd_pc; bpu_upd_target = alu0_upd_target;
            bpu_upd_taken = alu0_upd_taken; bpu_upd_mispred = alu0_mispred;
        end else if (alu1_ctrl_resolved) begin
            bpu_upd_btb = alu1_upd_btb; bpu_upd_gs = alu1_upd_gs;
            bpu_upd_pc = alu1_upd_pc; bpu_upd_target = alu1_upd_target;
            bpu_upd_taken = alu1_upd_taken; bpu_upd_mispred = alu1_mispred;
        end
    end

    // ========================================================================
    // Fetch Queue
    // ========================================================================
    wire [1:0] fq_pop_count = {1'b0, disp_en_0} + {1'b0, disp_en_1};

    fetch_queue FQ (
        .clk(cpu_clk), .rst(cpu_rst),
        .push_en(fq_push), .push_pc(pc_reg), .push_inst(ic_inst),
        .push_pred_taken(use_pred_taken), .push_pred_pc(use_pred_pc),
        .pop_count(fq_pop_count),
        .pop_pc_0(fq_pc_0), .pop_inst_0(fq_inst_0), .pop_valid_0(fq_valid_0),
        .pop_pred_taken_0(fq_pt_0), .pop_pred_pc_0(fq_ppc_0),
        .pop_pc_1(fq_pc_1), .pop_inst_1(fq_inst_1), .pop_valid_1(fq_valid_1),
        .pop_pred_taken_1(fq_pt_1), .pop_pred_pc_1(fq_ppc_1),
        .empty(fq_empty), .almost_full(fq_almost_full), .full(fq_full),
        .flush(frontend_flush)
    );

    // ========================================================================
    // Decode
    // ========================================================================
    wire [6:0]  d_op_0, d_op_1;
    wire [2:0]  d_f3_0, d_f3_1;
    wire [6:0]  d_f7_0, d_f7_1;
    wire [4:0]  d_rs1_0, d_rs2_0, d_rd_0;
    wire [4:0]  d_rs1_1, d_rs2_1, d_rd_1;
    wire        d_ur1_0, d_ur2_0, d_wen_0;
    wire        d_ur1_1, d_ur2_1, d_wen_1;
    wire        d_load_0, d_store_0, d_br_0, d_jal_0, d_jalr_0, d_lui_0, d_auipc_0;
    wire        d_load_1, d_store_1, d_br_1, d_jal_1, d_jalr_1, d_lui_1, d_auipc_1;
    wire        d_ctrl_0, d_mem_0;
    wire        d_ctrl_1, d_mem_1;
    wire [31:0] d_imm_0, d_imm_1;
    wire [3:0]  d_alu_0, d_alu_1;
    wire [1:0]  d_msz_0, d_msz_1;
    wire        d_mun_0, d_mun_1;
    wire [1:0]  d_oc_0, d_oc_1;
    wire [2:0]  d_bt_0, d_bt_1;

    decode_ooo DEC0 (
        .inst(fq_inst_0), .pc(fq_pc_0), .pred_taken(fq_pt_0), .pred_pc(fq_ppc_0),
        .opcode(d_op_0), .funct3(d_f3_0), .funct7(d_f7_0),
        .rs1(d_rs1_0), .rs2(d_rs2_0), .rd(d_rd_0),
        .uses_rs1(d_ur1_0), .uses_rs2(d_ur2_0), .reg_wen(d_wen_0),
        .is_load(d_load_0), .is_store(d_store_0),
        .is_branch(d_br_0), .is_jal(d_jal_0), .is_jalr(d_jalr_0),
        .is_lui(d_lui_0), .is_auipc(d_auipc_0),
        .is_control(d_ctrl_0), .is_mem(d_mem_0),
        .imm(d_imm_0), .alu_op(d_alu_0),
        .mem_size(d_msz_0), .mem_unsigned(d_mun_0),
        .op_class(d_oc_0), .branch_type(d_bt_0)
    );

    decode_ooo DEC1 (
        .inst(fq_inst_1), .pc(fq_pc_1), .pred_taken(fq_pt_1), .pred_pc(fq_ppc_1),
        .opcode(d_op_1), .funct3(d_f3_1), .funct7(d_f7_1),
        .rs1(d_rs1_1), .rs2(d_rs2_1), .rd(d_rd_1),
        .uses_rs1(d_ur1_1), .uses_rs2(d_ur2_1), .reg_wen(d_wen_1),
        .is_load(d_load_1), .is_store(d_store_1),
        .is_branch(d_br_1), .is_jal(d_jal_1), .is_jalr(d_jalr_1),
        .is_lui(d_lui_1), .is_auipc(d_auipc_1),
        .is_control(d_ctrl_1), .is_mem(d_mem_1),
        .imm(d_imm_1), .alu_op(d_alu_1),
        .mem_size(d_msz_1), .mem_unsigned(d_mun_1),
        .op_class(d_oc_1), .branch_type(d_bt_1)
    );

    // ========================================================================
    // Unresolved control tracking
    // ========================================================================
    reg        unresolved_ctrl;
    reg [4:0]  unresolved_rob_tag;

    wire ctrl_resolved_any = alu0_ctrl_resolved || alu1_ctrl_resolved;
    wire need_frontend_redirect = (alu0_ctrl_resolved && alu0_need_redirect) ||
                                  (alu1_ctrl_resolved && alu1_need_redirect);
    wire [31:0] redirect_pc_w = alu0_need_redirect ? alu0_redirect_pc : alu1_redirect_pc;

    assign frontend_flush = need_frontend_redirect;
    assign flush_target_pc = redirect_pc_w;

    always @(posedge cpu_clk) begin
        if (!cpu_rst || frontend_flush)
            unresolved_ctrl <= 0;
        else if (disp_en_0 && d_ctrl_0) begin
            unresolved_ctrl <= 1;
            unresolved_rob_tag <= rob_tag_0;
        end else if (disp_en_1 && d_ctrl_1) begin
            unresolved_ctrl <= 1;
            unresolved_rob_tag <= rob_tag_1;
        end else if (ctrl_resolved_any)
            unresolved_ctrl <= 0;
    end

    // ========================================================================
    // Dispatch: resource checking
    // ========================================================================
    wire slot0_candidate = fq_valid_0 && !unresolved_ctrl && !frontend_flush;
    wire slot1_candidate = fq_valid_1 && slot0_candidate && !d_ctrl_0;

    wire [4:0] need_iq_1  = {4'b0, !d_mem_0};
    wire [4:0] need_lsq_1 = {4'b0,  d_mem_0};
    wire [4:0] need_iq_2  = {4'b0, !d_mem_0} + {4'b0, !d_mem_1};
    wire [4:0] need_lsq_2 = {4'b0,  d_mem_0} + {4'b0,  d_mem_1};

    wire can_dispatch_2 = slot1_candidate &&
                          (rob_free_count >= 6'd2) &&
                          (iq_free_count >= need_iq_2) &&
                          (lsq_free_count >= need_lsq_2);

    wire can_dispatch_1 = slot0_candidate &&
                          (rob_free_count >= 6'd1) &&
                          (iq_free_count >= need_iq_1) &&
                          (lsq_free_count >= need_lsq_1);

    assign disp_en_0 = can_dispatch_2 || can_dispatch_1;
    assign disp_en_1 = can_dispatch_2;

    wire d_wen_eff_0 = d_wen_0 && (d_rd_0 != 5'b0);
    wire d_wen_eff_1 = d_wen_1 && (d_rd_1 != 5'b0);

    // ========================================================================
    // RAT
    // ========================================================================
    wire        cdb_valid_0;
    wire [4:0]  cdb_tag_0;
    wire [31:0] cdb_value_0;
    wire        cdb_valid_1;
    wire [4:0]  cdb_tag_1;
    wire [31:0] cdb_value_1;

    wire [31:0] arch_r1_0, arch_r2_0, arch_r1_1, arch_r2_1;

    wire        r1_busy_0, r2_busy_0, r1_rdy_0, r2_rdy_0;
    wire [31:0] r1_val_0, r2_val_0;
    wire [4:0]  r1_tag_0, r2_tag_0;
    wire        r1_busy_1, r2_busy_1, r1_rdy_1, r2_rdy_1;
    wire [31:0] r1_val_1, r2_val_1;
    wire [4:0]  r1_tag_1, r2_tag_1;

    rat RAT (
        .clk(cpu_clk), .rst(cpu_rst),
        .rs1_0(d_rs1_0), .rs2_0(d_rs2_0), .rd_0(d_rd_0),
        .rs1_arch_value_0(arch_r1_0), .rs2_arch_value_0(arch_r2_0),
        .rd_wen_0(d_wen_eff_0), .rob_tag_0(rob_tag_0), .alloc_0(disp_en_0),
        .rs1_1(d_rs1_1), .rs2_1(d_rs2_1), .rd_1(d_rd_1),
        .rs1_arch_value_1(arch_r1_1), .rs2_arch_value_1(arch_r2_1),
        .rd_wen_1(d_wen_eff_1), .rob_tag_1(rob_tag_1), .alloc_1(disp_en_1),
        .rs1_busy_0(r1_busy_0), .rs1_ready_0(r1_rdy_0), .rs1_value_0(r1_val_0), .rs1_tag_0(r1_tag_0),
        .rs2_busy_0(r2_busy_0), .rs2_ready_0(r2_rdy_0), .rs2_value_0(r2_val_0), .rs2_tag_0(r2_tag_0),
        .rs1_busy_1(r1_busy_1), .rs1_ready_1(r1_rdy_1), .rs1_value_1(r1_val_1), .rs1_tag_1(r1_tag_1),
        .rs2_busy_1(r2_busy_1), .rs2_ready_1(r2_rdy_1), .rs2_value_1(r2_val_1), .rs2_tag_1(r2_tag_1),
        .commit_0(commit_en_0), .commit_rd_0(commit_rd_0),
        .commit_tag_0(commit_tag_0), .commit_wen_0(commit_wen_0),
        .commit_value_0(commit_val_0),
        .commit_1(commit_en_1), .commit_rd_1(commit_rd_1),
        .commit_tag_1(commit_tag_1), .commit_wen_1(commit_wen_1),
        .commit_value_1(commit_val_1),
        .cdb_valid_0(cdb_valid_0), .cdb_tag_0(cdb_tag_0), .cdb_value_0(cdb_value_0),
        .cdb_valid_1(cdb_valid_1), .cdb_tag_1(cdb_tag_1), .cdb_value_1(cdb_value_1),
        .flush(1'b0)
    );

    // ========================================================================
    // Arch Regfile
    // ========================================================================
    arch_regfile_2w4r REGS (
        .clk(cpu_clk), .rst(cpu_rst),
        .rs1_addr_0(d_rs1_0), .rs2_addr_0(d_rs2_0),
        .rs1_addr_1(d_rs1_1), .rs2_addr_1(d_rs2_1),
        .rs1_data_0(arch_r1_0), .rs2_data_0(arch_r2_0),
        .rs1_data_1(arch_r1_1), .rs2_data_1(arch_r2_1),
        .wen_0(commit_en_0 && commit_wen_0), .waddr_0(commit_rd_0), .wdata_0(commit_val_0),
        .wen_1(commit_en_1 && commit_wen_1), .waddr_1(commit_rd_1), .wdata_1(commit_val_1)
    );

    wire src1_ready_0 = !d_ur1_0 || r1_rdy_0;
    wire src2_ready_0 = !d_ur2_0 || r2_rdy_0;
    wire src1_ready_1 = !d_ur1_1 || r1_rdy_1;
    wire src2_ready_1 = !d_ur2_1 || r2_rdy_1;

    wire [31:0] src1_val_0 = d_ur1_0 ? r1_val_0 : 32'b0;
    wire [31:0] src2_val_0 = d_ur2_0 ? r2_val_0 : 32'b0;
    wire [31:0] src1_val_1 = d_ur1_1 ? r1_val_1 : 32'b0;
    wire [31:0] src2_val_1 = d_ur2_1 ? r2_val_1 : 32'b0;

    // ========================================================================
    // ROB
    // ========================================================================
    rob ROB (
        .clk(cpu_clk), .rst(cpu_rst),
        .alloc_0(disp_en_0), .alloc_1(disp_en_1),
        .alloc_pc_0(fq_pc_0), .alloc_pc_1(fq_pc_1),
        .alloc_inst_0(fq_inst_0), .alloc_inst_1(fq_inst_1),
        .alloc_rd_0(d_rd_0), .alloc_rd_1(d_rd_1),
        .alloc_wen_0(d_wen_eff_0), .alloc_wen_1(d_wen_eff_1),
        .alloc_is_store_0(d_store_0), .alloc_is_store_1(d_store_1),
        .alloc_is_load_0(d_load_0), .alloc_is_load_1(d_load_1),
        .alloc_tag_0(rob_tag_0), .alloc_tag_1(rob_tag_1),
        .rob_full(rob_full), .rob_almost_full(rob_almost_full),
        .rob_count(rob_count), .rob_free_count(rob_free_count),
        .wb_en_0(cdb_valid_0), .wb_tag_0(cdb_tag_0), .wb_value_0(cdb_value_0),
        .wb_en_1(cdb_valid_1), .wb_tag_1(cdb_tag_1), .wb_value_1(cdb_value_1),
        .commit_en_0(commit_en_0), .commit_tag_0(commit_tag_0),
        .commit_rd_0(commit_rd_0), .commit_value_0(commit_val_0),
        .commit_wen_0(commit_wen_0), .commit_is_store_0(commit_is_store_0),
        .commit_pc_0(commit_pc_0),
        .commit_en_1(commit_en_1), .commit_tag_1(commit_tag_1),
        .commit_rd_1(commit_rd_1), .commit_value_1(commit_val_1),
        .commit_wen_1(commit_wen_1), .commit_is_store_1(commit_is_store_1),
        .commit_pc_1(commit_pc_1),
        .store_commit_req(store_commit_req), .store_commit_tag(store_commit_tag),
        .store_done(lsu_store_done), .store_done_tag(lsu_store_done_tag),
        .flush(1'b0)
    );

    // ========================================================================
    // Issue Queue
    // ========================================================================
    wire       iq_en_0, iq_en_1;
    wire [31:0] iq_pc_0, iq_pc_1;
    wire [4:0]  iq_rd_0, iq_rd_1;
    wire        iq_wen_0, iq_wen_1;
    wire [4:0]  iq_rtag_0, iq_rtag_1;
    wire [3:0]  iq_alu_0, iq_alu_1;
    wire [31:0] iq_s1_0, iq_s2_0, iq_imm_0;
    wire [31:0] iq_s1_1, iq_s2_1, iq_imm_1;
    wire        iq_ur1_0, iq_ur2_0;
    wire        iq_ur1_1, iq_ur2_1;
    wire        iq_isb_0, iq_isj_0, iq_isjr_0, iq_ilui_0, iq_iau_0;
    wire        iq_isb_1, iq_isj_1, iq_isjr_1, iq_ilui_1, iq_iau_1;
    wire [2:0]  iq_bt_0, iq_bt_1;
    wire [1:0]  iq_oc_0, iq_oc_1;
    wire        iq_pt_0, iq_pt_1;
    wire [31:0] iq_ppc_0, iq_ppc_1;

    issue_queue IQ (
        .clk(cpu_clk), .rst(cpu_rst),
        .iq_push_0(disp_en_0 && !d_mem_0),
        .push_pc_0(fq_pc_0), .push_rd_0(d_rd_0), .push_wen_0(d_wen_eff_0),
        .push_rob_tag_0(rob_tag_0), .push_alu_op_0(d_alu_0), .push_imm_0(d_imm_0),
        .push_src1_ready_0(src1_ready_0), .push_src1_val_0(src1_val_0), .push_src1_tag_0(r1_tag_0),
        .push_src2_ready_0(src2_ready_0), .push_src2_val_0(src2_val_0), .push_src2_tag_0(r2_tag_0),
        .push_uses_rs1_0(d_ur1_0), .push_uses_rs2_0(d_ur2_0),
        .push_is_branch_0(d_br_0), .push_is_jal_0(d_jal_0), .push_is_jalr_0(d_jalr_0),
        .push_is_lui_0(d_lui_0), .push_is_auipc_0(d_auipc_0),
        .push_branch_type_0(d_bt_0), .push_op_class_0(d_oc_0),
        .push_pred_taken_0(fq_pt_0), .push_pred_pc_0(fq_ppc_0),
        .iq_push_1(disp_en_1 && !d_mem_1),
        .push_pc_1(fq_pc_1), .push_rd_1(d_rd_1), .push_wen_1(d_wen_eff_1),
        .push_rob_tag_1(rob_tag_1), .push_alu_op_1(d_alu_1), .push_imm_1(d_imm_1),
        .push_src1_ready_1(src1_ready_1), .push_src1_val_1(src1_val_1), .push_src1_tag_1(r1_tag_1),
        .push_src2_ready_1(src2_ready_1), .push_src2_val_1(src2_val_1), .push_src2_tag_1(r2_tag_1),
        .push_uses_rs1_1(d_ur1_1), .push_uses_rs2_1(d_ur2_1),
        .push_is_branch_1(d_br_1), .push_is_jal_1(d_jal_1), .push_is_jalr_1(d_jalr_1),
        .push_is_lui_1(d_lui_1), .push_is_auipc_1(d_auipc_1),
        .push_branch_type_1(d_bt_1), .push_op_class_1(d_oc_1),
        .push_pred_taken_1(fq_pt_1), .push_pred_pc_1(fq_ppc_1),
        .cdb_valid_0(cdb_valid_0), .cdb_tag_0(cdb_tag_0), .cdb_value_0(cdb_value_0),
        .cdb_valid_1(cdb_valid_1), .cdb_tag_1(cdb_tag_1), .cdb_value_1(cdb_value_1),
        .issue_en_0(iq_en_0), .issue_pc_0(iq_pc_0),
        .issue_rd_0(iq_rd_0), .issue_wen_0(iq_wen_0),
        .issue_rob_tag_0(iq_rtag_0), .issue_alu_op_0(iq_alu_0),
        .issue_src1_0(iq_s1_0), .issue_src2_0(iq_s2_0), .issue_imm_0(iq_imm_0),
        .issue_uses_rs1_0(iq_ur1_0), .issue_uses_rs2_0(iq_ur2_0),
        .issue_is_branch_0(iq_isb_0), .issue_is_jal_0(iq_isj_0), .issue_is_jalr_0(iq_isjr_0),
        .issue_is_lui_0(iq_ilui_0), .issue_is_auipc_0(iq_iau_0),
        .issue_branch_type_0(iq_bt_0), .issue_op_class_0(iq_oc_0),
        .issue_pred_taken_0(iq_pt_0), .issue_pred_pc_0(iq_ppc_0),
        .issue_en_1(iq_en_1), .issue_pc_1(iq_pc_1),
        .issue_rd_1(iq_rd_1), .issue_wen_1(iq_wen_1),
        .issue_rob_tag_1(iq_rtag_1), .issue_alu_op_1(iq_alu_1),
        .issue_src1_1(iq_s1_1), .issue_src2_1(iq_s2_1), .issue_imm_1(iq_imm_1),
        .issue_uses_rs1_1(iq_ur1_1), .issue_uses_rs2_1(iq_ur2_1),
        .issue_is_branch_1(iq_isb_1), .issue_is_jal_1(iq_isj_1), .issue_is_jalr_1(iq_isjr_1),
        .issue_is_lui_1(iq_ilui_1), .issue_is_auipc_1(iq_iau_1),
        .issue_branch_type_1(iq_bt_1), .issue_op_class_1(iq_oc_1),
        .issue_pred_taken_1(iq_pt_1), .issue_pred_pc_1(iq_ppc_1),
        .free_count(iq_free_count),
        .flush(1'b0)
    );

    // ========================================================================
    // ALU Units (2x)
    // ========================================================================
    wire        alu0_valid, alu1_valid;
    wire [4:0]  alu0_tag, alu1_tag;
    wire [31:0] alu0_val, alu1_val;
    wire        alu0_act_taken, alu1_act_taken;
    wire [31:0] alu0_act_npc, alu1_act_npc;

    alu_unit ALU0 (
        .clk(cpu_clk), .rst(cpu_rst), .en(iq_en_0),
        .pc(iq_pc_0), .rd(iq_rd_0), .wen(iq_wen_0), .rob_tag(iq_rtag_0),
        .alu_op(iq_alu_0), .src1(iq_s1_0), .src2(iq_s2_0), .imm(iq_imm_0),
        .uses_rs1(iq_ur1_0), .uses_rs2(iq_ur2_0),
        .is_branch(iq_isb_0), .is_jal(iq_isj_0), .is_jalr(iq_isjr_0),
        .is_lui(iq_ilui_0), .is_auipc(iq_iau_0), .branch_type(iq_bt_0),
        .pred_taken(iq_pt_0), .pred_pc(iq_ppc_0),
        .result_valid(alu0_valid), .result_rob_tag(alu0_tag), .result_value(alu0_val),
        .ctrl_resolved(alu0_ctrl_resolved), .actual_taken(alu0_act_taken),
        .actual_next_pc(alu0_act_npc),
        .need_redirect(alu0_need_redirect), .redirect_pc(alu0_redirect_pc),
        .update_btb_en(alu0_upd_btb), .update_gshare_en(alu0_upd_gs),
        .update_pc(alu0_upd_pc), .update_target(alu0_upd_target),
        .update_actual_taken(alu0_upd_taken), .pred_mispredict(alu0_mispred)
    );

    alu_unit ALU1 (
        .clk(cpu_clk), .rst(cpu_rst), .en(iq_en_1),
        .pc(iq_pc_1), .rd(iq_rd_1), .wen(iq_wen_1), .rob_tag(iq_rtag_1),
        .alu_op(iq_alu_1), .src1(iq_s1_1), .src2(iq_s2_1), .imm(iq_imm_1),
        .uses_rs1(iq_ur1_1), .uses_rs2(iq_ur2_1),
        .is_branch(iq_isb_1), .is_jal(iq_isj_1), .is_jalr(iq_isjr_1),
        .is_lui(iq_ilui_1), .is_auipc(iq_iau_1), .branch_type(iq_bt_1),
        .pred_taken(iq_pt_1), .pred_pc(iq_ppc_1),
        .result_valid(alu1_valid), .result_rob_tag(alu1_tag), .result_value(alu1_val),
        .ctrl_resolved(alu1_ctrl_resolved), .actual_taken(alu1_act_taken),
        .actual_next_pc(alu1_act_npc),
        .need_redirect(alu1_need_redirect), .redirect_pc(alu1_redirect_pc),
        .update_btb_en(alu1_upd_btb), .update_gshare_en(alu1_upd_gs),
        .update_pc(alu1_upd_pc), .update_target(alu1_upd_target),
        .update_actual_taken(alu1_upd_taken), .pred_mispredict(alu1_mispred)
    );

    // ========================================================================
    // CDB Arbitration: ALU0 > ALU1 > LSU (with pending buffer)
    // ========================================================================
    wire        lsu_wb_valid;
    wire [4:0]  lsu_wb_tag;
    wire [31:0] lsu_wb_val;
    wire        lsu_wb_grant;

    wire take_alu0_p0 = alu0_valid;
    wire take_alu1_p0 = !take_alu0_p0 && alu1_valid;
    wire take_lsu_p0  = !take_alu0_p0 && !take_alu1_p0 && lsu_wb_valid;

    wire used_alu1 = take_alu1_p0;
    wire used_lsu  = take_lsu_p0;

    wire take_alu1_p1 = !used_alu1 && alu1_valid;
    wire take_lsu_p1  = !used_lsu && lsu_wb_valid && !take_alu1_p1;

    assign cdb_valid_0 = take_alu0_p0 || take_alu1_p0 || take_lsu_p0;
    assign cdb_tag_0   = take_alu0_p0 ? alu0_tag :
                         take_alu1_p0 ? alu1_tag :
                         take_lsu_p0  ? lsu_wb_tag : 5'b0;
    assign cdb_value_0 = take_alu0_p0 ? alu0_val :
                         take_alu1_p0 ? alu1_val :
                         take_lsu_p0  ? lsu_wb_val : 32'b0;

    assign cdb_valid_1 = take_alu1_p1 || take_lsu_p1;
    assign cdb_tag_1   = take_alu1_p1 ? alu1_tag :
                         take_lsu_p1  ? lsu_wb_tag : 5'b0;
    assign cdb_value_1 = take_alu1_p1 ? alu1_val :
                         take_lsu_p1  ? lsu_wb_val : 32'b0;

    assign lsu_wb_grant = take_lsu_p0 || take_lsu_p1;

    // ========================================================================
    // LSU
    // ========================================================================
    wire       dc_req_load, dc_req_store;
    wire [1:0] dc_mask;
    wire [31:0] dc_addr, dc_wdata;
    wire [31:0] dc_rdata;
    wire       dc_stall, dc_ack;

    lsu_ooo LSU (
        .clk(cpu_clk), .rst(cpu_rst),
        .mem_push_0(disp_en_0 && d_mem_0),
        .push_rd_0(d_rd_0), .push_wen_0(d_wen_eff_0), .push_rob_tag_0(rob_tag_0),
        .push_is_load_0(d_load_0), .push_is_store_0(d_store_0),
        .push_rs1_val_0(src1_val_0), .push_rs1_ready_0(src1_ready_0), .push_rs1_tag_0(r1_tag_0),
        .push_rs2_val_0(src2_val_0), .push_rs2_ready_0(src2_ready_0), .push_rs2_tag_0(r2_tag_0),
        .push_imm_0(d_imm_0), .push_mem_size_0(d_msz_0), .push_mem_unsigned_0(d_mun_0),
        .mem_push_1(disp_en_1 && d_mem_1),
        .push_rd_1(d_rd_1), .push_wen_1(d_wen_eff_1), .push_rob_tag_1(rob_tag_1),
        .push_is_load_1(d_load_1), .push_is_store_1(d_store_1),
        .push_rs1_val_1(src1_val_1), .push_rs1_ready_1(src1_ready_1), .push_rs1_tag_1(r1_tag_1),
        .push_rs2_val_1(src2_val_1), .push_rs2_ready_1(src2_ready_1), .push_rs2_tag_1(r2_tag_1),
        .push_imm_1(d_imm_1), .push_mem_size_1(d_msz_1), .push_mem_unsigned_1(d_mun_1),
        .cdb_valid_0(cdb_valid_0), .cdb_tag_0(cdb_tag_0), .cdb_value_0(cdb_value_0),
        .cdb_valid_1(cdb_valid_1), .cdb_tag_1(cdb_tag_1), .cdb_value_1(cdb_value_1),
        .dcache_req_load(dc_req_load), .dcache_req_store(dc_req_store),
        .dcache_mask(dc_mask), .dcache_addr(dc_addr), .dcache_wdata(dc_wdata),
        .dcache_rdata(dc_rdata), .dcache_stall(dc_stall), .dcache_ack(dc_ack),
        .load_wb_valid(lsu_wb_valid), .load_wb_tag(lsu_wb_tag), .load_wb_value(lsu_wb_val),
        .load_wb_grant(lsu_wb_grant),
        .store_commit_req(store_commit_req), .store_commit_rob_tag(store_commit_tag),
        .store_done(lsu_store_done), .store_done_tag(lsu_store_done_tag),
        .free_count(lsq_free_count),
        .flush(1'b0)
    );

    // ========================================================================
    // DCache
    // ========================================================================
    dcache DCACHE (
        .clk(cpu_clk), .rst(cpu_rst),
        .cpu_req_load(dc_req_load), .cpu_req_store(dc_req_store),
        .cpu_mask(dc_mask), .cpu_addr(dc_addr),
        .cpu_wdata(dc_wdata), .cpu_rdata(dc_rdata),
        .stall(dc_stall),
        .mem_addr(perip_addr), .mem_we(perip_we),
        .mem_wen(perip_wen), .mem_wdata(perip_wdata),
        .mem_rdata(perip_rdata), .mem_ack(dc_ack)
    );

endmodule
