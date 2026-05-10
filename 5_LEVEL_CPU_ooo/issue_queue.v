`include "ooo_defs.vh"

module issue_queue (
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

    output              issue_en_0,
    output [31:0]       issue_pc_0,
    output [4:0]        issue_rd_0,
    output              issue_wen_0,
    output [4:0]        issue_rob_tag_0,
    output [3:0]        issue_alu_op_0,
    output [31:0]       issue_src1_0,
    output [31:0]       issue_src2_0,
    output [31:0]       issue_imm_0,
    output              issue_uses_rs1_0,
    output              issue_uses_rs2_0,
    output              issue_is_branch_0,
    output              issue_is_jal_0,
    output              issue_is_jalr_0,
    output              issue_is_lui_0,
    output              issue_is_auipc_0,
    output [2:0]        issue_branch_type_0,
    output [1:0]        issue_op_class_0,
    output              issue_pred_taken_0,
    output [31:0]       issue_pred_pc_0,

    output              issue_en_1,
    output [31:0]       issue_pc_1,
    output [4:0]        issue_rd_1,
    output              issue_wen_1,
    output [4:0]        issue_rob_tag_1,
    output [3:0]        issue_alu_op_1,
    output [31:0]       issue_src1_1,
    output [31:0]       issue_src2_1,
    output [31:0]       issue_imm_1,
    output              issue_uses_rs1_1,
    output              issue_uses_rs2_1,
    output              issue_is_branch_1,
    output              issue_is_jal_1,
    output              issue_is_jalr_1,
    output              issue_is_lui_1,
    output              issue_is_auipc_1,
    output [2:0]        issue_branch_type_1,
    output [1:0]        issue_op_class_1,
    output              issue_pred_taken_1,
    output [31:0]       issue_pred_pc_1,

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
    reg  [15:0] age [0:DEPTH-1];
    reg  [15:0] age_cnt;
    reg  [4:0]  cnt;

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

    reg [4:0] s0i, s1i;
    reg       s0f, s1f;
    reg [15:0] ma0, ma1;
    integer si;
    always @(*) begin
        s0f = 1'b0;
        s1f = 1'b0;
        s0i = 5'b0;
        s1i = 5'b0;
        ma0 = 16'hFFFF;
        ma1 = 16'hFFFF;
        for (si = 0; si < DEPTH; si = si + 1) begin
            if (v[si] && (!u1[si] || s1r[si]) && (!u2[si] || s2r[si])) begin
                if (!s0f || (age[si] < ma0)) begin
                    if (s0f) begin
                        s1f = 1'b1;
                        s1i = s0i;
                        ma1 = ma0;
                    end
                    s0f = 1'b1;
                    s0i = si[4:0];
                    ma0 = age[si];
                end else if (!s1f || (age[si] < ma1)) begin
                    s1f = 1'b1;
                    s1i = si[4:0];
                    ma1 = age[si];
                end
            end
        end

        if (s0f && s1f && (ib[s0i] || ij[s0i] || ijr[s0i]) &&
            (ib[s1i] || ij[s1i] || ijr[s1i]))
            s1f = 1'b0;
    end

    assign issue_en_0 = s0f;
    assign issue_pc_0 = pc_r[s0i];
    assign issue_rd_0 = rd_r[s0i];
    assign issue_wen_0 = wn[s0i];
    assign issue_rob_tag_0 = rt[s0i];
    assign issue_alu_op_0 = ao[s0i];
    assign issue_src1_0 = s1v[s0i];
    assign issue_src2_0 = s2v[s0i];
    assign issue_imm_0 = im[s0i];
    assign issue_uses_rs1_0 = u1[s0i];
    assign issue_uses_rs2_0 = u2[s0i];
    assign issue_is_branch_0 = ib[s0i];
    assign issue_is_jal_0 = ij[s0i];
    assign issue_is_jalr_0 = ijr[s0i];
    assign issue_is_lui_0 = ilui[s0i];
    assign issue_is_auipc_0 = iau[s0i];
    assign issue_branch_type_0 = bt[s0i];
    assign issue_op_class_0 = oc[s0i];
    assign issue_pred_taken_0 = pt[s0i];
    assign issue_pred_pc_0 = ppc[s0i];

    assign issue_en_1 = s1f;
    assign issue_pc_1 = pc_r[s1i];
    assign issue_rd_1 = rd_r[s1i];
    assign issue_wen_1 = wn[s1i];
    assign issue_rob_tag_1 = rt[s1i];
    assign issue_alu_op_1 = ao[s1i];
    assign issue_src1_1 = s1v[s1i];
    assign issue_src2_1 = s2v[s1i];
    assign issue_imm_1 = im[s1i];
    assign issue_uses_rs1_1 = u1[s1i];
    assign issue_uses_rs2_1 = u2[s1i];
    assign issue_is_branch_1 = ib[s1i];
    assign issue_is_jal_1 = ij[s1i];
    assign issue_is_jalr_1 = ijr[s1i];
    assign issue_is_lui_1 = ilui[s1i];
    assign issue_is_auipc_1 = iau[s1i];
    assign issue_branch_type_1 = bt[s1i];
    assign issue_op_class_1 = oc[s1i];
    assign issue_pred_taken_1 = pt[s1i];
    assign issue_pred_pc_1 = ppc[s1i];

    integer ei;
    always @(posedge clk) begin
        if (!rst || flush) begin
            for (ei = 0; ei < DEPTH; ei = ei + 1) begin
                v[ei] <= 1'b0;
                s1r[ei] <= 1'b0;
                s2r[ei] <= 1'b0;
            end
            cnt <= 5'b0;
            age_cnt <= 16'b0;
        end else begin
            for (ei = 0; ei < DEPTH; ei = ei + 1) begin
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

            if (s0f)
                v[s0i] <= 1'b0;
            if (s1f)
                v[s1i] <= 1'b0;

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
                age[fs0] <= age_cnt;
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
                age[fs1] <= age_cnt + 16'd1;
            end

            age_cnt <= age_cnt + {15'b0, pushA_valid && ff0} + {15'b0, pushB_valid && ff1};
            cnt <= cnt
                 - {4'b0, s0f}
                 - {4'b0, s1f}
                 + {4'b0, pushA_valid && ff0}
                 + {4'b0, pushB_valid && ff1};
        end
    end
endmodule
