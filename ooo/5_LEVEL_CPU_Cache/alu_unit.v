`include "ooo_defs.vh"

module alu_unit (
    input               clk,
    input               rst,
    input               en,
    input  [31:0]       pc,
    input  [4:0]        rd,
    input               wen,
    input  [4:0]        rob_tag,
    input  [3:0]        alu_op,
    input  [31:0]       src1,
    input  [31:0]       src2,
    input  [31:0]       imm,
    input               uses_rs1,
    input               uses_rs2,
    input               is_branch,
    input               is_jal,
    input               is_jalr,
    input               is_lui,
    input               is_auipc,
    input  [2:0]        branch_type,
    input               pred_taken,
    input  [31:0]       pred_pc,

    output reg          result_valid,
    output reg [4:0]    result_rob_tag,
    output reg [31:0]   result_value,
    output reg          ctrl_resolved,
    output reg          actual_taken,
    output reg [31:0]   actual_next_pc,
    output reg          need_redirect,
    output reg [31:0]   redirect_pc,
    output reg          update_btb_en,
    output reg          update_gshare_en,
    output reg [31:0]   update_pc,
    output reg [31:0]   update_target,
    output reg          update_actual_taken,
    output reg          pred_mispredict
);

    wire [4:0] shamt = uses_rs2 ? src2[4:0] : imm[4:0];
    wire [31:0] val1 = uses_rs1 ? src1 : 32'b0;
    wire [31:0] val2 = uses_rs2 ? src2 : imm;
    wire [31:0] pc_plus4 = pc + 32'd4;

    // ALU compute
    wire [31:0] add_res  = val1 + val2;
    wire [31:0] sub_res  = val1 - val2;
    wire [31:0] and_res  = val1 & val2;
    wire [31:0] or_res   = val1 | val2;
    wire [31:0] xor_res  = val1 ^ val2;
    wire [31:0] sll_res  = val1 << shamt;
    wire [31:0] srl_res  = val1 >> shamt;
    wire [31:0] sra_res  = $signed(val1) >>> shamt;
    wire ltu = (val1 < val2);
    wire sign_diff = val1[31] ^ val2[31];
    wire lts = sign_diff ? val1[31] : (val1[30:0] < val2[30:0]);

    // ALU result
    reg [31:0] alu_result;
    always @(*) begin
        alu_result = 32'b0;
        case (alu_op)
            `ALU_ADD:   alu_result = add_res;
            `ALU_SUB:   alu_result = sub_res;
            `ALU_AND:   alu_result = and_res;
            `ALU_OR:    alu_result = or_res;
            `ALU_XOR:   alu_result = xor_res;
            `ALU_SLL:   alu_result = sll_res;
            `ALU_SRL:   alu_result = srl_res;
            `ALU_SRA:   alu_result = sra_res;
            `ALU_SLT:   alu_result = {31'b0, lts};
            `ALU_SLTU:  alu_result = {31'b0, ltu};
            `ALU_LUI:   alu_result = imm;
            `ALU_AUIPC: alu_result = pc + imm;
            default:    alu_result = 32'b0;
        endcase
    end

    // Branch comparison
    wire br_eq  = (src1 == src2);
    wire br_lt  = ($signed(src1) < $signed(src2));
    wire br_ltu = (src1 < src2);

    reg br_taken;
    always @(*) begin
        br_taken = 1'b0;
        case (branch_type)
            `BEQ:  br_taken = br_eq;
            `BNE:  br_taken = !br_eq;
            `BLT:  br_taken = br_lt;
            `BGE:  br_taken = !br_lt;
            `BLTU: br_taken = br_ltu;
            `BGEU: br_taken = !br_ltu;
            `BR_JAL:  br_taken = 1'b1;
            `BR_JALR: br_taken = 1'b1;
            default:  br_taken = 1'b0;
        endcase
    end

    // Target / next PC
    wire [31:0] branch_target = pc + imm;
    wire [31:0] jalr_target   = (src1 + imm) & 32'hFFFFFFFE;

    reg [31:0] ctrl_next_pc;
    always @(*) begin
        ctrl_next_pc = pc_plus4;
        if (is_branch)
            ctrl_next_pc = br_taken ? branch_target : pc_plus4;
        else if (is_jal)
            ctrl_next_pc = branch_target;
        else if (is_jalr)
            ctrl_next_pc = jalr_target;
    end

    wire is_ctrl = is_branch || is_jal || is_jalr;
    wire mispred = is_ctrl && (ctrl_next_pc != pred_pc);

    always @(posedge clk) begin
        if (!rst) begin
            result_valid    <= 0;
            result_rob_tag  <= 0;
            result_value    <= 0;
            ctrl_resolved   <= 0;
            actual_taken    <= 0;
            actual_next_pc  <= 0;
            need_redirect   <= 0;
            redirect_pc     <= 0;
            update_btb_en   <= 0;
            update_gshare_en<= 0;
            update_pc       <= 0;
            update_target   <= 0;
            update_actual_taken <= 0;
            pred_mispredict <= 0;
        end else begin
            result_valid   <= en;
            result_rob_tag <= rob_tag;
            ctrl_resolved  <= 0;
            actual_taken   <= 0;
            actual_next_pc <= 0;
            need_redirect  <= 0;
            redirect_pc    <= 0;
            update_btb_en  <= 0;
            update_gshare_en <= 0;
            update_pc      <= 0;
            update_target  <= 0;
            update_actual_taken <= 0;
            pred_mispredict <= 0;

            if (en) begin
                if (is_lui) begin
                    result_value <= imm;
                end else if (is_auipc) begin
                    result_value <= pc + imm;
                end else if (is_jal || is_jalr) begin
                    result_value <= pc_plus4;
                end else begin
                    result_value <= alu_result;
                end

                if (is_ctrl) begin
                    ctrl_resolved   <= 1;
                    actual_taken    <= br_taken;
                    actual_next_pc  <= ctrl_next_pc;
                    need_redirect   <= mispred;
                    redirect_pc     <= ctrl_next_pc;
                    update_pc       <= pc;
                    update_target   <= ctrl_next_pc;
                    update_actual_taken <= br_taken;
                    pred_mispredict <= mispred;
                    if (is_branch)
                        update_gshare_en <= 1;
                    if (is_jal || is_jalr)
                        update_btb_en <= 1;
                end
            end
        end
    end
endmodule
