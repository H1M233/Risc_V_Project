`include "ooo_defs.vh"

module alu_unit #(
    parameter USE_ALU_INPUT_REG = 1
)(
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

    reg          en_q;
    reg [31:0]   pc_q;
    reg [4:0]    rd_q;
    reg          wen_q;
    reg [4:0]    rob_tag_q;
    reg [3:0]    alu_op_q;
    reg [31:0]   src1_q;
    reg [31:0]   src2_q;
    reg [31:0]   imm_q;
    reg          uses_rs1_q;
    reg          uses_rs2_q;
    reg          is_branch_q;
    reg          is_jal_q;
    reg          is_jalr_q;
    reg          is_lui_q;
    reg          is_auipc_q;
    reg [2:0]    branch_type_q;
    reg          pred_taken_q;
    reg [31:0]   pred_pc_q;

    wire          op_en          = USE_ALU_INPUT_REG ? en_q          : en;
    wire [31:0]   op_pc          = USE_ALU_INPUT_REG ? pc_q          : pc;
    wire [4:0]    op_rob_tag     = USE_ALU_INPUT_REG ? rob_tag_q     : rob_tag;
    wire [3:0]    op_alu_op      = USE_ALU_INPUT_REG ? alu_op_q      : alu_op;
    wire [31:0]   op_src1        = USE_ALU_INPUT_REG ? src1_q        : src1;
    wire [31:0]   op_src2        = USE_ALU_INPUT_REG ? src2_q        : src2;
    wire [31:0]   op_imm         = USE_ALU_INPUT_REG ? imm_q         : imm;
    wire          op_uses_rs1    = USE_ALU_INPUT_REG ? uses_rs1_q    : uses_rs1;
    wire          op_uses_rs2    = USE_ALU_INPUT_REG ? uses_rs2_q    : uses_rs2;
    wire          op_is_branch   = USE_ALU_INPUT_REG ? is_branch_q   : is_branch;
    wire          op_is_jal      = USE_ALU_INPUT_REG ? is_jal_q      : is_jal;
    wire          op_is_jalr     = USE_ALU_INPUT_REG ? is_jalr_q     : is_jalr;
    wire          op_is_lui      = USE_ALU_INPUT_REG ? is_lui_q      : is_lui;
    wire          op_is_auipc    = USE_ALU_INPUT_REG ? is_auipc_q    : is_auipc;
    wire [2:0]    op_branch_type = USE_ALU_INPUT_REG ? branch_type_q : branch_type;
    wire [31:0]   op_pred_pc     = USE_ALU_INPUT_REG ? pred_pc_q     : pred_pc;

    wire [4:0] shamt = op_uses_rs2 ? op_src2[4:0] : op_imm[4:0];
    wire [31:0] val1 = op_uses_rs1 ? op_src1 : 32'b0;
    wire [31:0] val2 = op_uses_rs2 ? op_src2 : op_imm;
    wire [31:0] pc_plus4 = op_pc + 32'd4;

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

    reg [31:0] alu_result;
    always @(*) begin
        alu_result = 32'b0;
        case (op_alu_op)
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
            `ALU_LUI:   alu_result = op_imm;
            `ALU_AUIPC: alu_result = op_pc + op_imm;
            default:    alu_result = 32'b0;
        endcase
    end

    wire br_eq  = (op_src1 == op_src2);
    wire br_lt  = ($signed(op_src1) < $signed(op_src2));
    wire br_ltu = (op_src1 < op_src2);

    reg br_taken;
    always @(*) begin
        br_taken = 1'b0;
        case (op_branch_type)
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

    wire [31:0] branch_target = op_pc + op_imm;
    wire [31:0] jalr_target   = (op_src1 + op_imm) & 32'hFFFF_FFFE;

    reg [31:0] ctrl_next_pc;
    always @(*) begin
        ctrl_next_pc = pc_plus4;
        if (op_is_branch)
            ctrl_next_pc = br_taken ? branch_target : pc_plus4;
        else if (op_is_jal)
            ctrl_next_pc = branch_target;
        else if (op_is_jalr)
            ctrl_next_pc = jalr_target;
    end

    wire is_ctrl = op_is_branch || op_is_jal || op_is_jalr;
    wire mispred = is_ctrl && (ctrl_next_pc != op_pred_pc);

    always @(posedge clk) begin
        if (!rst) begin
            en_q <= 1'b0;
            pc_q <= 32'b0;
            rd_q <= 5'b0;
            wen_q <= 1'b0;
            rob_tag_q <= 5'b0;
            alu_op_q <= 4'b0;
            src1_q <= 32'b0;
            src2_q <= 32'b0;
            imm_q <= 32'b0;
            uses_rs1_q <= 1'b0;
            uses_rs2_q <= 1'b0;
            is_branch_q <= 1'b0;
            is_jal_q <= 1'b0;
            is_jalr_q <= 1'b0;
            is_lui_q <= 1'b0;
            is_auipc_q <= 1'b0;
            branch_type_q <= 3'b0;
            pred_taken_q <= 1'b0;
            pred_pc_q <= 32'b0;
            result_valid <= 1'b0;
            result_rob_tag <= 5'b0;
            result_value <= 32'b0;
            ctrl_resolved <= 1'b0;
            actual_taken <= 1'b0;
            actual_next_pc <= 32'b0;
            need_redirect <= 1'b0;
            redirect_pc <= 32'b0;
            update_btb_en <= 1'b0;
            update_gshare_en <= 1'b0;
            update_pc <= 32'b0;
            update_target <= 32'b0;
            update_actual_taken <= 1'b0;
            pred_mispredict <= 1'b0;
        end else begin
            en_q <= en;
            pc_q <= pc;
            rd_q <= rd;
            wen_q <= wen;
            rob_tag_q <= rob_tag;
            alu_op_q <= alu_op;
            src1_q <= src1;
            src2_q <= src2;
            imm_q <= imm;
            uses_rs1_q <= uses_rs1;
            uses_rs2_q <= uses_rs2;
            is_branch_q <= is_branch;
            is_jal_q <= is_jal;
            is_jalr_q <= is_jalr;
            is_lui_q <= is_lui;
            is_auipc_q <= is_auipc;
            branch_type_q <= branch_type;
            pred_taken_q <= pred_taken;
            pred_pc_q <= pred_pc;

            result_valid   <= op_en;
            result_rob_tag <= op_rob_tag;
            ctrl_resolved  <= 1'b0;
            actual_taken   <= 1'b0;
            actual_next_pc <= 32'b0;
            need_redirect  <= 1'b0;
            redirect_pc    <= 32'b0;
            update_btb_en  <= 1'b0;
            update_gshare_en <= 1'b0;
            update_pc      <= 32'b0;
            update_target  <= 32'b0;
            update_actual_taken <= 1'b0;
            pred_mispredict <= 1'b0;

            if (op_en) begin
                if (op_is_lui)
                    result_value <= op_imm;
                else if (op_is_auipc)
                    result_value <= op_pc + op_imm;
                else if (op_is_jal || op_is_jalr)
                    result_value <= pc_plus4;
                else
                    result_value <= alu_result;

                if (is_ctrl) begin
                    ctrl_resolved   <= 1'b1;
                    actual_taken    <= br_taken;
                    actual_next_pc  <= ctrl_next_pc;
                    need_redirect   <= mispred;
                    redirect_pc     <= ctrl_next_pc;
                    update_pc       <= op_pc;
                    update_target   <= ctrl_next_pc;
                    update_actual_taken <= br_taken;
                    pred_mispredict <= mispred;
                    if (op_is_branch)
                        update_gshare_en <= 1'b1;
                    if (op_is_jal || op_is_jalr)
                        update_btb_en <= 1'b1;
                end
            end
        end
    end
endmodule