`include "ooo_defs.vh"

module issue_queue #(
    parameter USE_IQ_PIPELINE = 1
)(
    input               clk,
    input               rst,

    input               iq_push_0,
    input  [31:0]       push_pc_0,
    input  [4:0]        push_rd_0,
    input               push_wen_0,
    input  [4:0]        push_rob_tag_0,
    input  [3:0]        push_alu_op_0,
    input  [31:0]       push_imm_0,
    input               push_src1_ready_0,
    input  [31:0]       push_src1_val_0,
    input  [4:0]        push_src1_tag_0,
    input               push_src2_ready_0,
    input  [31:0]       push_src2_val_0,
    input  [4:0]        push_src2_tag_0,
    input               push_uses_rs1_0,
    input               push_uses_rs2_0,
    input               push_is_branch_0,
    input               push_is_jal_0,
    input               push_is_jalr_0,
    input               push_is_lui_0,
    input               push_is_auipc_0,
    input  [2:0]        push_branch_type_0,
    input  [1:0]        push_op_class_0,
    input               push_pred_taken_0,
    input  [31:0]       push_pred_pc_0,

    input               iq_push_1,
    input  [31:0]       push_pc_1,
    input  [4:0]        push_rd_1,
    input               push_wen_1,
    input  [4:0]        push_rob_tag_1,
    input  [3:0]        push_alu_op_1,
    input  [31:0]       push_imm_1,
    input               push_src1_ready_1,
    input  [31:0]       push_src1_val_1,
    input  [4:0]        push_src1_tag_1,
    input               push_src2_ready_1,
    input  [31:0]       push_src2_val_1,
    input  [4:0]        push_src2_tag_1,
    input               push_uses_rs1_1,
    input               push_uses_rs2_1,
    input               push_is_branch_1,
    input               push_is_jal_1,
    input               push_is_jalr_1,
    input               push_is_lui_1,
    input               push_is_auipc_1,
    input  [2:0]        push_branch_type_1,
    input  [1:0]        push_op_class_1,
    input               push_pred_taken_1,
    input  [31:0]       push_pred_pc_1,

    input               cdb_valid_0,
    input  [4:0]        cdb_tag_0,
    input  [31:0]       cdb_value_0,
    input               cdb_valid_1,
    input  [4:0]        cdb_tag_1,
    input  [31:0]       cdb_value_1,

    output reg          issue_en_0,
    output reg [31:0]   issue_pc_0,
    output reg [4:0]    issue_rd_0,
    output reg          issue_wen_0,
    output reg [4:0]    issue_rob_tag_0,
    output reg [3:0]    issue_alu_op_0,
    output reg [31:0]   issue_src1_0,
    output reg [31:0]   issue_src2_0,
    output reg [31:0]   issue_imm_0,
    output reg          issue_uses_rs1_0,
    output reg          issue_uses_rs2_0,
    output reg          issue_is_branch_0,
    output reg          issue_is_jal_0,
    output reg          issue_is_jalr_0,
    output reg          issue_is_lui_0,
    output reg          issue_is_auipc_0,
    output reg [2:0]    issue_branch_type_0,
    output reg [1:0]    issue_op_class_0,
    output reg          issue_pred_taken_0,
    output reg [31:0]   issue_pred_pc_0,

    output reg          issue_en_1,
    output reg [31:0]   issue_pc_1,
    output reg [4:0]    issue_rd_1,
    output reg          issue_wen_1,
    output reg [4:0]    issue_rob_tag_1,
    output reg [3:0]    issue_alu_op_1,
    output reg [31:0]   issue_src1_1,
    output reg [31:0]   issue_src2_1,
    output reg [31:0]   issue_imm_1,
    output reg          issue_uses_rs1_1,
    output reg          issue_uses_rs2_1,
    output reg          issue_is_branch_1,
    output reg          issue_is_jal_1,
    output reg          issue_is_jalr_1,
    output reg          issue_is_lui_1,
    output reg          issue_is_auipc_1,
    output reg [2:0]    issue_branch_type_1,
    output reg [1:0]    issue_op_class_1,
    output reg          issue_pred_taken_1,
    output reg [31:0]   issue_pred_pc_1,

    output [4:0]        free_count,
    input               flush
);

    localparam DEPTH = `IQ_SIZE;
    localparam [4:0] DEPTH_COUNT = `IQ_SIZE;

    reg         v   [0:DEPTH-1];
    reg  [31:0] pc_r[0:DEPTH-1];
    reg  [4:0]  rd_r[0:DEPTH-1];
    reg         wn  [0:DEPTH-1];
    reg  [4:0]  rt  [0:DEPTH-1];
    reg  [3:0]  ao  [0:DEPTH-1];
    reg  [31:0] im  [0:DEPTH-1];
    reg         s1r [0:DEPTH-1];
    reg  [31:0] s1v [0:DEPTH-1];
    reg  [4:0]  s1t [0:DEPTH-1];
    reg         s2r [0:DEPTH-1];
    reg  [31:0] s2v [0:DEPTH-1];
    reg  [4:0]  s2t [0:DEPTH-1];
    reg         u1  [0:DEPTH-1];
    reg         u2  [0:DEPTH-1];
    reg         ib  [0:DEPTH-1];
    reg         ij  [0:DEPTH-1];
    reg         ijr [0:DEPTH-1];
    reg         ilui[0:DEPTH-1];
    reg         iau [0:DEPTH-1];
    reg  [2:0]  bt  [0:DEPTH-1];
    reg  [1:0]  oc  [0:DEPTH-1];
    reg         pt  [0:DEPTH-1];
    reg  [31:0] ppc [0:DEPTH-1];
    reg         ready_q [0:DEPTH-1];
    reg  [4:0]  cnt;
    reg  [4:0]  rr_ptr;

    assign free_count = DEPTH_COUNT - cnt;

    reg [4:0] fs0, fs1;
    reg       ff0, ff1;
    integer fi;
    always @(*) begin
        ff0 = 1'b0;
        ff1 = 1'b0;
        fs0 = 5'b0;
        fs1 = 5'b0;
        for (fi = 0; fi < DEPTH; fi = fi + 1) begin
            if (!v[fi]) begin
                if (!ff0) begin
                    ff0 = 1'b1;
                    fs0 = fi[4:0];
                end else if (!ff1) begin
                    ff1 = 1'b1;
                    fs1 = fi[4:0];
                end
            end
        end
    end

    wire pushA_valid = iq_push_0 || iq_push_1;
    wire pushB_valid = iq_push_0 && iq_push_1;

    wire [31:0] pushA_pc      = iq_push_0 ? push_pc_0 : push_pc_1;
    wire [4:0]  pushA_rd      = iq_push_0 ? push_rd_0 : push_rd_1;
    wire        pushA_wen     = iq_push_0 ? push_wen_0 : push_wen_1;
    wire [4:0]  pushA_rob_tag = iq_push_0 ? push_rob_tag_0 : push_rob_tag_1;
    wire [3:0]  pushA_alu_op  = iq_push_0 ? push_alu_op_0 : push_alu_op_1;
    wire [31:0] pushA_imm     = iq_push_0 ? push_imm_0 : push_imm_1;
    wire        pushA_s1_ready= iq_push_0 ? push_src1_ready_0 : push_src1_ready_1;
    wire [31:0] pushA_s1_val  = iq_push_0 ? push_src1_val_0 : push_src1_val_1;
    wire [4:0]  pushA_s1_tag  = iq_push_0 ? push_src1_tag_0 : push_src1_tag_1;
    wire        pushA_s2_ready= iq_push_0 ? push_src2_ready_0 : push_src2_ready_1;
    wire [31:0] pushA_s2_val  = iq_push_0 ? push_src2_val_0 : push_src2_val_1;
    wire [4:0]  pushA_s2_tag  = iq_push_0 ? push_src2_tag_0 : push_src2_tag_1;
    wire        pushA_u1      = iq_push_0 ? push_uses_rs1_0 : push_uses_rs1_1;
    wire        pushA_u2      = iq_push_0 ? push_uses_rs2_0 : push_uses_rs2_1;
    wire        pushA_ib      = iq_push_0 ? push_is_branch_0 : push_is_branch_1;
    wire        pushA_ij      = iq_push_0 ? push_is_jal_0 : push_is_jal_1;
    wire        pushA_ijr     = iq_push_0 ? push_is_jalr_0 : push_is_jalr_1;
    wire        pushA_ilui    = iq_push_0 ? push_is_lui_0 : push_is_lui_1;
    wire        pushA_iau     = iq_push_0 ? push_is_auipc_0 : push_is_auipc_1;
    wire [2:0]  pushA_bt      = iq_push_0 ? push_branch_type_0 : push_branch_type_1;
    wire [1:0]  pushA_oc      = iq_push_0 ? push_op_class_0 : push_op_class_1;
    wire        pushA_pt      = iq_push_0 ? push_pred_taken_0 : push_pred_taken_1;
    wire [31:0] pushA_ppc     = iq_push_0 ? push_pred_pc_0 : push_pred_pc_1;

    wire pushA_s1_cdb0 = pushA_u1 && !pushA_s1_ready && cdb_valid_0 && (pushA_s1_tag == cdb_tag_0);
    wire pushA_s1_cdb1 = pushA_u1 && !pushA_s1_ready && cdb_valid_1 && (pushA_s1_tag == cdb_tag_1);
    wire pushA_s2_cdb0 = pushA_u2 && !pushA_s2_ready && cdb_valid_0 && (pushA_s2_tag == cdb_tag_0);
    wire pushA_s2_cdb1 = pushA_u2 && !pushA_s2_ready && cdb_valid_1 && (pushA_s2_tag == cdb_tag_1);

    wire pushB_s1_cdb0 = push_uses_rs1_1 && !push_src1_ready_1 && cdb_valid_0 && (push_src1_tag_1 == cdb_tag_0);
    wire pushB_s1_cdb1 = push_uses_rs1_1 && !push_src1_ready_1 && cdb_valid_1 && (push_src1_tag_1 == cdb_tag_1);
    wire pushB_s2_cdb0 = push_uses_rs2_1 && !push_src2_ready_1 && cdb_valid_0 && (push_src2_tag_1 == cdb_tag_0);
    wire pushB_s2_cdb1 = push_uses_rs2_1 && !push_src2_ready_1 && cdb_valid_1 && (push_src2_tag_1 == cdb_tag_1);

    reg ready_sel [0:DEPTH-1];
    reg grant0_valid, grant1_valid;
    reg [4:0] grant0_idx, grant1_idx;
    reg [4:0] scan_idx;
    reg [4:0] second_start;
    integer ri, si;
    always @(*) begin
        for (ri = 0; ri < DEPTH; ri = ri + 1) begin
            if (USE_IQ_PIPELINE)
                ready_sel[ri] = v[ri] && ready_q[ri];
            else
                ready_sel[ri] = v[ri] && (!u1[ri] || s1r[ri]) && (!u2[ri] || s2r[ri]);
        end

        grant0_valid = 1'b0;
        grant1_valid = 1'b0;
        grant0_idx = 5'b0;
        grant1_idx = 5'b0;

        for (si = 0; si < DEPTH; si = si + 1) begin
            scan_idx = rr_ptr + si[4:0];
            if (scan_idx >= DEPTH)
                scan_idx = scan_idx - DEPTH;
            if (!grant0_valid && ready_sel[scan_idx] && (ib[scan_idx] || ij[scan_idx] || ijr[scan_idx])) begin
                grant0_valid = 1'b1;
                grant0_idx = scan_idx;
            end
        end

        for (si = 0; si < DEPTH; si = si + 1) begin
            scan_idx = rr_ptr + si[4:0];
            if (scan_idx >= DEPTH)
                scan_idx = scan_idx - DEPTH;
            if (!grant0_valid && ready_sel[scan_idx]) begin
                grant0_valid = 1'b1;
                grant0_idx = scan_idx;
            end
        end

        if (grant0_valid && !(ib[grant0_idx] || ij[grant0_idx] || ijr[grant0_idx])) begin
            second_start = grant0_idx + 5'd1;
            if (second_start >= DEPTH)
                second_start = second_start - DEPTH;
            for (si = 0; si < DEPTH; si = si + 1) begin
                scan_idx = second_start + si[4:0];
                if (scan_idx >= DEPTH)
                    scan_idx = scan_idx - DEPTH;
                if (!grant1_valid && (scan_idx != grant0_idx) && ready_sel[scan_idx]) begin
                    grant1_valid = 1'b1;
                    grant1_idx = scan_idx;
                end
            end
        end
    end

    integer ei;
    always @(posedge clk) begin
        if (!rst || flush) begin
            for (ei = 0; ei < DEPTH; ei = ei + 1) begin
                v[ei] <= 1'b0;
                s1r[ei] <= 1'b0;
                s2r[ei] <= 1'b0;
                ready_q[ei] <= 1'b0;
            end
            cnt <= 5'b0;
            rr_ptr <= 5'b0;
            issue_en_0 <= 1'b0;
            issue_en_1 <= 1'b0;
            issue_pc_0 <= 32'b0;
            issue_pc_1 <= 32'b0;
            issue_rd_0 <= 5'b0;
            issue_rd_1 <= 5'b0;
            issue_wen_0 <= 1'b0;
            issue_wen_1 <= 1'b0;
            issue_rob_tag_0 <= 5'b0;
            issue_rob_tag_1 <= 5'b0;
            issue_alu_op_0 <= 4'b0;
            issue_alu_op_1 <= 4'b0;
            issue_src1_0 <= 32'b0;
            issue_src1_1 <= 32'b0;
            issue_src2_0 <= 32'b0;
            issue_src2_1 <= 32'b0;
            issue_imm_0 <= 32'b0;
            issue_imm_1 <= 32'b0;
            issue_uses_rs1_0 <= 1'b0;
            issue_uses_rs1_1 <= 1'b0;
            issue_uses_rs2_0 <= 1'b0;
            issue_uses_rs2_1 <= 1'b0;
            issue_is_branch_0 <= 1'b0;
            issue_is_branch_1 <= 1'b0;
            issue_is_jal_0 <= 1'b0;
            issue_is_jal_1 <= 1'b0;
            issue_is_jalr_0 <= 1'b0;
            issue_is_jalr_1 <= 1'b0;
            issue_is_lui_0 <= 1'b0;
            issue_is_lui_1 <= 1'b0;
            issue_is_auipc_0 <= 1'b0;
            issue_is_auipc_1 <= 1'b0;
            issue_branch_type_0 <= 3'b0;
            issue_branch_type_1 <= 3'b0;
            issue_op_class_0 <= 2'b0;
            issue_op_class_1 <= 2'b0;
            issue_pred_taken_0 <= 1'b0;
            issue_pred_taken_1 <= 1'b0;
            issue_pred_pc_0 <= 32'b0;
            issue_pred_pc_1 <= 32'b0;
        end else begin
            for (ei = 0; ei < DEPTH; ei = ei + 1) begin
                ready_q[ei] <= v[ei] && (!u1[ei] || s1r[ei]) && (!u2[ei] || s2r[ei]);
                if (v[ei]) begin
                    if (u1[ei] && !s1r[ei]) begin
                        if (cdb_valid_0 && (cdb_tag_0 == s1t[ei])) begin
                            s1r[ei] <= 1'b1;
                            s1v[ei] <= cdb_value_0;
                        end else if (cdb_valid_1 && (cdb_tag_1 == s1t[ei])) begin
                            s1r[ei] <= 1'b1;
                            s1v[ei] <= cdb_value_1;
                        end
                    end
                    if (u2[ei] && !s2r[ei]) begin
                        if (cdb_valid_0 && (cdb_tag_0 == s2t[ei])) begin
                            s2r[ei] <= 1'b1;
                            s2v[ei] <= cdb_value_0;
                        end else if (cdb_valid_1 && (cdb_tag_1 == s2t[ei])) begin
                            s2r[ei] <= 1'b1;
                            s2v[ei] <= cdb_value_1;
                        end
                    end
                end
            end

            issue_en_0 <= grant0_valid;
            issue_en_1 <= grant1_valid;

            if (grant0_valid) begin
                issue_pc_0 <= pc_r[grant0_idx];
                issue_rd_0 <= rd_r[grant0_idx];
                issue_wen_0 <= wn[grant0_idx];
                issue_rob_tag_0 <= rt[grant0_idx];
                issue_alu_op_0 <= ao[grant0_idx];
                issue_src1_0 <= s1v[grant0_idx];
                issue_src2_0 <= s2v[grant0_idx];
                issue_imm_0 <= im[grant0_idx];
                issue_uses_rs1_0 <= u1[grant0_idx];
                issue_uses_rs2_0 <= u2[grant0_idx];
                issue_is_branch_0 <= ib[grant0_idx];
                issue_is_jal_0 <= ij[grant0_idx];
                issue_is_jalr_0 <= ijr[grant0_idx];
                issue_is_lui_0 <= ilui[grant0_idx];
                issue_is_auipc_0 <= iau[grant0_idx];
                issue_branch_type_0 <= bt[grant0_idx];
                issue_op_class_0 <= oc[grant0_idx];
                issue_pred_taken_0 <= pt[grant0_idx];
                issue_pred_pc_0 <= ppc[grant0_idx];
                v[grant0_idx] <= 1'b0;
            end else begin
                issue_pc_0 <= 32'b0;
                issue_rd_0 <= 5'b0;
                issue_wen_0 <= 1'b0;
                issue_rob_tag_0 <= 5'b0;
                issue_alu_op_0 <= 4'b0;
                issue_src1_0 <= 32'b0;
                issue_src2_0 <= 32'b0;
                issue_imm_0 <= 32'b0;
                issue_uses_rs1_0 <= 1'b0;
                issue_uses_rs2_0 <= 1'b0;
                issue_is_branch_0 <= 1'b0;
                issue_is_jal_0 <= 1'b0;
                issue_is_jalr_0 <= 1'b0;
                issue_is_lui_0 <= 1'b0;
                issue_is_auipc_0 <= 1'b0;
                issue_branch_type_0 <= 3'b0;
                issue_op_class_0 <= 2'b0;
                issue_pred_taken_0 <= 1'b0;
                issue_pred_pc_0 <= 32'b0;
            end

            if (grant1_valid) begin
                issue_pc_1 <= pc_r[grant1_idx];
                issue_rd_1 <= rd_r[grant1_idx];
                issue_wen_1 <= wn[grant1_idx];
                issue_rob_tag_1 <= rt[grant1_idx];
                issue_alu_op_1 <= ao[grant1_idx];
                issue_src1_1 <= s1v[grant1_idx];
                issue_src2_1 <= s2v[grant1_idx];
                issue_imm_1 <= im[grant1_idx];
                issue_uses_rs1_1 <= u1[grant1_idx];
                issue_uses_rs2_1 <= u2[grant1_idx];
                issue_is_branch_1 <= ib[grant1_idx];
                issue_is_jal_1 <= ij[grant1_idx];
                issue_is_jalr_1 <= ijr[grant1_idx];
                issue_is_lui_1 <= ilui[grant1_idx];
                issue_is_auipc_1 <= iau[grant1_idx];
                issue_branch_type_1 <= bt[grant1_idx];
                issue_op_class_1 <= oc[grant1_idx];
                issue_pred_taken_1 <= pt[grant1_idx];
                issue_pred_pc_1 <= ppc[grant1_idx];
                v[grant1_idx] <= 1'b0;
            end else begin
                issue_pc_1 <= 32'b0;
                issue_rd_1 <= 5'b0;
                issue_wen_1 <= 1'b0;
                issue_rob_tag_1 <= 5'b0;
                issue_alu_op_1 <= 4'b0;
                issue_src1_1 <= 32'b0;
                issue_src2_1 <= 32'b0;
                issue_imm_1 <= 32'b0;
                issue_uses_rs1_1 <= 1'b0;
                issue_uses_rs2_1 <= 1'b0;
                issue_is_branch_1 <= 1'b0;
                issue_is_jal_1 <= 1'b0;
                issue_is_jalr_1 <= 1'b0;
                issue_is_lui_1 <= 1'b0;
                issue_is_auipc_1 <= 1'b0;
                issue_branch_type_1 <= 3'b0;
                issue_op_class_1 <= 2'b0;
                issue_pred_taken_1 <= 1'b0;
                issue_pred_pc_1 <= 32'b0;
            end

            if (grant1_valid)
                rr_ptr <= (grant1_idx == DEPTH_COUNT - 5'd1) ? 5'b0 : grant1_idx + 5'd1;
            else if (grant0_valid)
                rr_ptr <= (grant0_idx == DEPTH_COUNT - 5'd1) ? 5'b0 : grant0_idx + 5'd1;

            if (pushA_valid && ff0) begin
                v[fs0] <= 1'b1;
                pc_r[fs0] <= pushA_pc;
                rd_r[fs0] <= pushA_rd;
                wn[fs0] <= pushA_wen && (pushA_rd != 5'b0);
                rt[fs0] <= pushA_rob_tag;
                ao[fs0] <= pushA_alu_op;
                im[fs0] <= pushA_imm;
                s1r[fs0] <= !pushA_u1 || pushA_s1_ready || pushA_s1_cdb0 || pushA_s1_cdb1;
                s1v[fs0] <= pushA_s1_cdb0 ? cdb_value_0 :
                             pushA_s1_cdb1 ? cdb_value_1 : pushA_s1_val;
                s1t[fs0] <= pushA_s1_tag;
                s2r[fs0] <= !pushA_u2 || pushA_s2_ready || pushA_s2_cdb0 || pushA_s2_cdb1;
                s2v[fs0] <= pushA_s2_cdb0 ? cdb_value_0 :
                             pushA_s2_cdb1 ? cdb_value_1 : pushA_s2_val;
                s2t[fs0] <= pushA_s2_tag;
                u1[fs0] <= pushA_u1;
                u2[fs0] <= pushA_u2;
                ib[fs0] <= pushA_ib;
                ij[fs0] <= pushA_ij;
                ijr[fs0] <= pushA_ijr;
                ilui[fs0] <= pushA_ilui;
                iau[fs0] <= pushA_iau;
                bt[fs0] <= pushA_bt;
                oc[fs0] <= pushA_oc;
                pt[fs0] <= pushA_pt;
                ppc[fs0] <= pushA_ppc;
                ready_q[fs0] <= (!pushA_u1 || pushA_s1_ready || pushA_s1_cdb0 || pushA_s1_cdb1) &&
                                (!pushA_u2 || pushA_s2_ready || pushA_s2_cdb0 || pushA_s2_cdb1);
            end

            if (pushB_valid && ff1) begin
                v[fs1] <= 1'b1;
                pc_r[fs1] <= push_pc_1;
                rd_r[fs1] <= push_rd_1;
                wn[fs1] <= push_wen_1 && (push_rd_1 != 5'b0);
                rt[fs1] <= push_rob_tag_1;
                ao[fs1] <= push_alu_op_1;
                im[fs1] <= push_imm_1;
                s1r[fs1] <= !push_uses_rs1_1 || push_src1_ready_1 || pushB_s1_cdb0 || pushB_s1_cdb1;
                s1v[fs1] <= pushB_s1_cdb0 ? cdb_value_0 :
                             pushB_s1_cdb1 ? cdb_value_1 : push_src1_val_1;
                s1t[fs1] <= push_src1_tag_1;
                s2r[fs1] <= !push_uses_rs2_1 || push_src2_ready_1 || pushB_s2_cdb0 || pushB_s2_cdb1;
                s2v[fs1] <= pushB_s2_cdb0 ? cdb_value_0 :
                             pushB_s2_cdb1 ? cdb_value_1 : push_src2_val_1;
                s2t[fs1] <= push_src2_tag_1;
                u1[fs1] <= push_uses_rs1_1;
                u2[fs1] <= push_uses_rs2_1;
                ib[fs1] <= push_is_branch_1;
                ij[fs1] <= push_is_jal_1;
                ijr[fs1] <= push_is_jalr_1;
                ilui[fs1] <= push_is_lui_1;
                iau[fs1] <= push_is_auipc_1;
                bt[fs1] <= push_branch_type_1;
                oc[fs1] <= push_op_class_1;
                pt[fs1] <= push_pred_taken_1;
                ppc[fs1] <= push_pred_pc_1;
                ready_q[fs1] <= (!push_uses_rs1_1 || push_src1_ready_1 || pushB_s1_cdb0 || pushB_s1_cdb1) &&
                                (!push_uses_rs2_1 || push_src2_ready_1 || pushB_s2_cdb0 || pushB_s2_cdb1);
            end

            cnt <= cnt
                 - {4'b0, grant0_valid}
                 - {4'b0, grant1_valid}
                 + {4'b0, pushA_valid && ff0}
                 + {4'b0, pushB_valid && ff1};
        end
    end
endmodule
