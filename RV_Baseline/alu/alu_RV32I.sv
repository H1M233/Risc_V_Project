module alu_RV32I(
    input  logic [31:0]  value1,
    input  logic [31:0]  value2,
    input  logic [31:0]  imm,
    input  logic [31:0]  jump1,
    input  logic [31:0]  jump2,
    input  decode_t      ipkg,
    input  id_ex_data_t  dpkg,

    output ex_bpu_data_t bpkg,
    output logic         pred_flush_en,
    output logic [31:0]  pred_flush_pc,
    output logic [31:0]  result
);

    // 计算
    cmp_result_t alu_cmp;   // {ltu, lts}
    assign alu_cmp = fast_compare(value1, value2);

    wire [4:0]  shamt    = value2[4:0];
    wire [31:0] add_res  = value1 + value2;
    wire [31:0] sub_res  = value1 - value2;
    wire [31:0] xor_res  = value1 ^ value2;
    wire [31:0] or_res   = value1 | value2;
    wire [31:0] and_res  = value1 & value2;
    wire [31:0] sll_res  = value1 << shamt;
    wire [31:0] srl_res  = value1 >> shamt;
    wire [31:0] sra_res  = $signed(value1) >>> shamt;
    wire [31:0] ltu_res  = {31'b0, alu_cmp.ltu};
    wire [31:0] lts_res  = {31'b0, alu_cmp.lts};

    // 分支结果计算
    wire branch_eq_res  = (value1 == value2);
    wire branch_ltu_res = alu_cmp.ltu;
    wire branch_lts_res = alu_cmp.lts;

    logic branch_taken;
    always_comb begin
        unique case (1'b1)
            ipkg.sel_beq  : branch_taken = branch_eq_res;
            ipkg.sel_bne  : branch_taken = ~branch_eq_res;
            ipkg.sel_blt  : branch_taken = branch_lts_res;
            ipkg.sel_bge  : branch_taken = ~branch_lts_res;
            ipkg.sel_bltu : branch_taken = branch_ltu_res;
            ipkg.sel_bgeu : branch_taken = ~branch_ltu_res;
            default       : branch_taken = 1'b0;
        endcase
    end

    // 预测错误判断
    wire [31:0] jalr_target             = value1 + jump2;
    wire        jalr_pred_mispredict    = (ipkg.is_jalr & value1 != jump1);         // rs1 == pred_pc - imm
    wire        branch_pred_mispredict  = (ipkg.is_branch & dpkg.pred_taken != branch_taken);
    wire [31:0] branch_jump_addr        = (~dpkg.pred_taken) ? jump1 : jump2;       // 提前到 id 计算

    // 预测错误跳转 & 更新 BPU
    assign bpkg.update_btb_en     = jalr_pred_mispredict;        // btb 更新使能
    assign bpkg.update_gshare_en  = branch_pred_mispredict;      // gshare 更新使能
    assign bpkg.update_pc         = dpkg.pc;
    assign bpkg.update_target     = jalr_target;
    assign bpkg.actual_taken      = ~dpkg.pred_taken;
    assign bpkg.rollback_ras_ptr  = dpkg.ras_ptr;

    // 冲刷控制
    assign pred_flush_en  = (branch_pred_mispredict | jalr_pred_mispredict);
    assign pred_flush_pc  = (ipkg.is_branch) ? branch_jump_addr :
                            (ipkg.is_jalr)   ? jalr_target : 32'b0;

    // RV32I 标准结果
    always_comb begin
        unique case (1'b1)
            ipkg.sel_add            : result = add_res;
            ipkg.sel_sub            : result = sub_res;
            ipkg.sel_sll            : result = sll_res;
            ipkg.sel_slt            : result = lts_res;
            ipkg.sel_sltu           : result = ltu_res;
            ipkg.sel_xor            : result = xor_res;
            ipkg.sel_srl            : result = srl_res;
            ipkg.sel_sra            : result = sra_res;
            ipkg.sel_or             : result = or_res;
            ipkg.sel_and            : result = and_res;
            ipkg.request_value_only : result = imm;
            default                 : result = 32'b0;
        endcase
    end
endmodule