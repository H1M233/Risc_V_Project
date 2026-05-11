`include "ooo_defs.vh"

module rat (
    input               clk,
    input               rst,
    input  [4:0]        rs1_0,
    input  [4:0]        rs2_0,
    input  [31:0]       rs1_arch_value_0,
    input  [31:0]       rs2_arch_value_0,
    input  [4:0]        rd_0,
    input               rd_wen_0,
    input  [4:0]        rob_tag_0,
    input               alloc_0,
    input  [4:0]        rs1_1,
    input  [4:0]        rs2_1,
    input  [31:0]       rs1_arch_value_1,
    input  [31:0]       rs2_arch_value_1,
    input  [4:0]        rd_1,
    input               rd_wen_1,
    input  [4:0]        rob_tag_1,
    input               alloc_1,
    output              rs1_busy_0,
    output              rs1_ready_0,
    output [31:0]       rs1_value_0,
    output [4:0]        rs1_tag_0,
    output              rs2_busy_0,
    output              rs2_ready_0,
    output [31:0]       rs2_value_0,
    output [4:0]        rs2_tag_0,
    output              rs1_busy_1,
    output              rs1_ready_1,
    output [31:0]       rs1_value_1,
    output [4:0]        rs1_tag_1,
    output              rs2_busy_1,
    output              rs2_ready_1,
    output [31:0]       rs2_value_1,
    output [4:0]        rs2_tag_1,
    input               commit_0,
    input  [4:0]        commit_rd_0,
    input  [4:0]        commit_tag_0,
    input               commit_wen_0,
    input  [31:0]       commit_value_0,
    input               commit_1,
    input  [4:0]        commit_rd_1,
    input  [4:0]        commit_tag_1,
    input               commit_wen_1,
    input  [31:0]       commit_value_1,
    input               cdb_valid_0,
    input  [4:0]        cdb_tag_0,
    input  [31:0]       cdb_value_0,
    input               cdb_valid_1,
    input  [4:0]        cdb_tag_1,
    input  [31:0]       cdb_value_1,
    input               flush
);

    reg        busy  [0:31];
    reg [4:0]  tag   [0:31];
    reg        ready [0:31];
    reg [31:0] value [0:31];

    reg        nb [0:31];
    reg [4:0]  nt [0:31];
    reg        nr [0:31];
    reg [31:0] nv [0:31];

    integer i;

    always @(*) begin
        for (i = 0; i < 32; i = i + 1) begin
            nb[i] = busy[i]; nt[i] = tag[i];
            nr[i] = ready[i]; nv[i] = value[i];
        end
        nb[0] = 0; nt[0] = 0; nr[0] = 1; nv[0] = 0;

        // CDB ready updates
        for (i = 1; i < 32; i = i + 1) begin
            if (nb[i] && !nr[i]) begin
                if (cdb_valid_0 && nt[i] == cdb_tag_0) begin nr[i] = 1; nv[i] = cdb_value_0; end
                else if (cdb_valid_1 && nt[i] == cdb_tag_1) begin nr[i] = 1; nv[i] = cdb_value_1; end
            end
        end

        // Commit clear
        if (commit_0 && commit_wen_0 && commit_rd_0 != 0) begin
            if (nb[commit_rd_0] && nt[commit_rd_0] == commit_tag_0) begin
                nb[commit_rd_0] = 0;
                nt[commit_rd_0] = 0;
                nr[commit_rd_0] = 1;
                nv[commit_rd_0] = commit_value_0;
            end
        end
        if (commit_1 && commit_wen_1 && commit_rd_1 != 0) begin
            if (nb[commit_rd_1] && nt[commit_rd_1] == commit_tag_1) begin
                nb[commit_rd_1] = 0;
                nt[commit_rd_1] = 0;
                nr[commit_rd_1] = 1;
                nv[commit_rd_1] = commit_value_1;
            end
        end

        // Dispatch slot0
        if (alloc_0 && rd_wen_0 && rd_0 != 0) begin
            nb[rd_0] = 1; nt[rd_0] = rob_tag_0; nr[rd_0] = 0; nv[rd_0] = 0;
        end
        // Dispatch slot1 (overwrites slot0 same rd)
        if (alloc_1 && rd_wen_1 && rd_1 != 0) begin
            nb[rd_1] = 1; nt[rd_1] = rob_tag_1; nr[rd_1] = 0; nv[rd_1] = 0;
        end
        nb[0] = 0; nt[0] = 0; nr[0] = 1; nv[0] = 0;
    end

    always @(posedge clk) begin
        if (!rst || flush) begin
            for (i = 0; i < 32; i = i + 1) begin busy[i] <= 0; tag[i] <= 0; ready[i] <= 0; value[i] <= 0; end
        end else begin
            for (i = 0; i < 32; i = i + 1) begin
                busy[i] <= nb[i]; tag[i] <= nt[i]; ready[i] <= nr[i]; value[i] <= nv[i];
            end
        end
    end

    // Slot0 reads: CDB bypass at read time
    wire s0_r1_cdb = cdb_valid_0 && busy[rs1_0] && tag[rs1_0] == cdb_tag_0 && rs1_0 != 0;
    wire s0_r1_cdb1= cdb_valid_1 && busy[rs1_0] && tag[rs1_0] == cdb_tag_1 && rs1_0 != 0;
    wire s0_r2_cdb = cdb_valid_0 && busy[rs2_0] && tag[rs2_0] == cdb_tag_0 && rs2_0 != 0;
    wire s0_r2_cdb1= cdb_valid_1 && busy[rs2_0] && tag[rs2_0] == cdb_tag_1 && rs2_0 != 0;

    assign rs1_busy_0  = (rs1_0 != 0) && busy[rs1_0];
    assign rs1_ready_0 = (rs1_0 == 0) ? 1'b1 :
                         s0_r1_cdb ? 1'b1 :
                         s0_r1_cdb1 ? 1'b1 :
                         busy[rs1_0] ? ready[rs1_0] : 1'b1;
    assign rs1_value_0 = (rs1_0 == 0) ? 32'b0 :
                         s0_r1_cdb ? cdb_value_0 :
                         s0_r1_cdb1 ? cdb_value_1 :
                         busy[rs1_0] ? (ready[rs1_0] ? value[rs1_0] : 32'b0) : rs1_arch_value_0;
    assign rs1_tag_0   = (rs1_0 == 0) ? 5'b0 :
                         busy[rs1_0] ? tag[rs1_0] : 5'b0;

    assign rs2_busy_0  = (rs2_0 != 0) && busy[rs2_0];
    assign rs2_ready_0 = (rs2_0 == 0) ? 1'b1 :
                         s0_r2_cdb ? 1'b1 :
                         s0_r2_cdb1 ? 1'b1 :
                         busy[rs2_0] ? ready[rs2_0] : 1'b1;
    assign rs2_value_0 = (rs2_0 == 0) ? 32'b0 :
                         s0_r2_cdb ? cdb_value_0 :
                         s0_r2_cdb1 ? cdb_value_1 :
                         busy[rs2_0] ? (ready[rs2_0] ? value[rs2_0] : 32'b0) : rs2_arch_value_0;
    assign rs2_tag_0   = (rs2_0 == 0) ? 5'b0 :
                         busy[rs2_0] ? tag[rs2_0] : 5'b0;

    // Slot1 reads: slot0 forward + CDB bypass
    wire s1_r1_fwd = alloc_0 && rd_wen_0 && rd_0 != 0 && rd_0 == rs1_1;
    wire s1_r2_fwd = alloc_0 && rd_wen_0 && rd_0 != 0 && rd_0 == rs2_1;
    wire s1_r1_cdb = !s1_r1_fwd && cdb_valid_0 && busy[rs1_1] && tag[rs1_1] == cdb_tag_0 && rs1_1 != 0;
    wire s1_r1_cdb1= !s1_r1_fwd && cdb_valid_1 && busy[rs1_1] && tag[rs1_1] == cdb_tag_1 && rs1_1 != 0;
    wire s1_r2_cdb = !s1_r2_fwd && cdb_valid_0 && busy[rs2_1] && tag[rs2_1] == cdb_tag_0 && rs2_1 != 0;
    wire s1_r2_cdb1= !s1_r2_fwd && cdb_valid_1 && busy[rs2_1] && tag[rs2_1] == cdb_tag_1 && rs2_1 != 0;

    assign rs1_busy_1  = (rs1_1 == 0) ? 0 : s1_r1_fwd ? 1 : (busy[rs1_1] ? 1 : 0);
    assign rs1_ready_1 = (rs1_1 == 0) ? 1'b1 :
                         s1_r1_fwd ? 1'b0 :
                         s1_r1_cdb ? 1'b1 :
                         s1_r1_cdb1 ? 1'b1 :
                         busy[rs1_1] ? ready[rs1_1] : 1'b1;
    assign rs1_value_1 = (rs1_1 == 0) ? 32'b0 :
                         s1_r1_fwd ? 32'b0 :
                         s1_r1_cdb ? cdb_value_0 :
                         s1_r1_cdb1 ? cdb_value_1 :
                         busy[rs1_1] ? (ready[rs1_1] ? value[rs1_1] : 32'b0) : rs1_arch_value_1;
    assign rs1_tag_1   = (rs1_1 == 0) ? 5'b0 :
                         s1_r1_fwd ? rob_tag_0 :
                         busy[rs1_1] ? tag[rs1_1] : 5'b0;

    assign rs2_busy_1  = (rs2_1 == 0) ? 0 : s1_r2_fwd ? 1 : (busy[rs2_1] ? 1 : 0);
    assign rs2_ready_1 = (rs2_1 == 0) ? 1'b1 :
                         s1_r2_fwd ? 1'b0 :
                         s1_r2_cdb ? 1'b1 :
                         s1_r2_cdb1 ? 1'b1 :
                         busy[rs2_1] ? ready[rs2_1] : 1'b1;
    assign rs2_value_1 = (rs2_1 == 0) ? 32'b0 :
                         s1_r2_fwd ? 32'b0 :
                         s1_r2_cdb ? cdb_value_0 :
                         s1_r2_cdb1 ? cdb_value_1 :
                         busy[rs2_1] ? (ready[rs2_1] ? value[rs2_1] : 32'b0) : rs2_arch_value_1;
    assign rs2_tag_1   = (rs2_1 == 0) ? 5'b0 :
                         s1_r2_fwd ? rob_tag_0 :
                         busy[rs2_1] ? tag[rs2_1] : 5'b0;

endmodule
