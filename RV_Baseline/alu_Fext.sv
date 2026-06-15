`include "alu_def.svh"
module alu_Fext(
    input  logic        clk,
    input  logic        rst,
    input  logic        flush,

    input  logic [31:0] value1,
    input  logic [31:0] value2,
    input  id_ex_data_t dpkg,
    input  decode_t     ipkg,

    output logic [4:0]  fflags,

    output logic        ctrl,
    output logic [31:0] result
);
    localparam offest_const = 7'd127;
    
    // F 数据解码
    fval_t fval1, fval2;
    assign fval1 = value1;
    assign fval2 = value2;

    rm_t rm;
    assign rm = rm_t'((dpkg.imm[2:0] == 3'b111) ? dpkg.csr_rdata[7:5] : dpkg.imm[2:0]); // 3'b111 动态舍入模式

    wire value1_is_fval = ipkg.is_FP & ~ipkg.sel_fmv_w_x;
    wire value2_is_fval = ipkg.is_FP;

    wire fval1_is_nan = (fval1.exp == 255) & (fval1.mant != 0) & value1_is_fval;
    wire fval2_is_nan = (fval2.exp == 255) & (fval2.mant != 0) & value2_is_fval;

    wire fval1_is_inf = (fval1.exp == 255) & (fval1.mant == 0) & value1_is_fval;
    wire fval2_is_inf = (fval2.exp == 255) & (fval2.mant == 0) & value2_is_fval;

    // -------------------------------------
    // fadd.s, fsub.s:
    // -------------------------------------

    wire sum_diff_inf = fval1_is_inf & fval2_is_inf & ((ipkg.sel_fadd_s & (fval1.sign != fval2.sign)) || (ipkg.sel_fsub_s & (fval1.sign == fval2.sign)));

    // 1. 指数比较
    wire fval1_exp_gt_fval2 = (fval1.exp >= fval2.exp);
    
    logic [7:0]  exp_large, exp_small;
    logic [26:0] mant_large, mant_small;    // 还原最高位 1, 保留 GRS
    always_comb begin
        if (fval1_exp_gt_fval2) begin
            exp_large  = fval1.exp;
            exp_small  = fval2.exp;
            mant_large = {1'b1, fval1.mant, 3'b0};
            mant_small = {1'b1, fval2.mant, 3'b0};
        end
        else begin
            exp_large  = fval2.exp;
            exp_small  = fval1.exp;
            mant_large = {1'b1, fval2.mant, 3'b0};
            mant_small = {1'b1, fval1.mant, 3'b0};
        end
    end
    
    // 2. 对阶右移
    wire [7:0]  exp_diff            = exp_large - exp_small;
    wire [26:0] mant_small_shifted  = mant_small >> exp_diff;

    logic [24:0] sum_collect_S_shift_pre;
    generate
        assign sum_collect_S_shift_pre[2:0] = 0;
        for (genvar i = 3; i <= 24; i++) begin
            assign sum_collect_S_shift_pre[i] = |mant_small[i - 3:0];
        end
    endgenerate
    
    wire sum_collect_S_shift = (exp_diff >= 24) ? sum_collect_S_shift_pre[24] : sum_collect_S_shift_pre[exp_diff];

    // 3. 尾数加减
    logic        sel_add_real;
    logic        sum_carry_calc, sum_sign_calc;
    logic [26:0] sum_mant_res;

    always_comb begin
        sel_add_real = (ipkg.sel_fadd_s & (fval1.sign == fval2.sign)) || (ipkg.sel_fsub_s & (fval1.sign != fval2.sign));

        if (sel_add_real) begin
            {sum_carry_calc, sum_mant_res} = mant_large + mant_small_shifted;
            sum_sign_calc = 1'b0;
        end
        else begin
            sum_carry_calc = 1'b0;
            if (mant_large >= mant_small_shifted) begin
                sum_mant_res = mant_large - mant_small_shifted;
                sum_sign_calc = 1'b0;
            end
            else begin
                sum_mant_res = mant_small_shifted - mant_large;
                sum_sign_calc = 1'b1;
            end
        end
    end

    wire sum_sign_res = (fval1_exp_gt_fval2) ? 
                        fval1.sign ^ (sum_sign_calc) : 
                        fval2.sign ^ (sum_sign_calc ^ ipkg.sel_fsub_s);

    // 4. 前导零检测
    logic [4:0] lz_cnt;
    function automatic logic [4:0] lz(input logic [26:0] mant);
        if (|mant) begin
            for (int i = 26; i >= 0; i--) begin
                if (mant[i]) return 5'(26 - i);
            end
        end
        else return 5'b0;
    endfunction

    assign lz_cnt = lz(sum_mant_res);

    // 5. 溢出 & 规格化
    logic [26:0] sum_mant_norm;
    logic [7:0]  sum_exp_norm;
    logic        sum_collect_S_norm;
    logic        sum_norm_overflow, sum_norm_underflow;
    
    wire mant_zero = ~(|sum_mant_res) && ~sum_carry_calc;
    always_comb begin
        sum_collect_S_norm  = 0;
        sum_norm_overflow   = 0;
        sum_norm_underflow  = 0;

        if (mant_zero) begin
            sum_exp_norm  = 0;
            sum_mant_norm = 0;
        end
        else if (sum_carry_calc) begin   // 进位
            if (exp_large == 254) begin  // Overflow
                sum_norm_overflow = 1;
                sum_exp_norm      = 255;
                sum_mant_norm     = 0;
            end
            else begin
                sum_collect_S_norm = sum_mant_res[0];
                sum_exp_norm    = exp_large + 1;
                sum_mant_norm   = {1'b1, sum_mant_res[26:1]};
            end
        end 
        else if (~sum_mant_res[26]) begin       // 规格化左移
            if (exp_large <= lz_cnt) begin      // Underflow
                sum_norm_underflow = 1;
                sum_exp_norm       = 0;
                sum_mant_norm      = 0;
            end
            else begin
                sum_exp_norm  = exp_large - lz_cnt;
                sum_mant_norm = sum_mant_res << lz_cnt;
            end
        end 
        else begin  // 已规格化
            sum_exp_norm  = exp_large;
            sum_mant_norm = sum_mant_res;
        end
    end

    // 6. 舍入
    wire  sum_lsb = sum_mant_norm[3];
    wire  sum_G   = sum_mant_norm[2];
    wire  sum_R   = sum_mant_norm[1];
    wire  sum_S   = sum_collect_S_shift | sum_collect_S_norm | sum_mant_norm[0];
    logic sum_roundup;
    logic sum_roundup_inexact;
    assign sum_roundup_inexact = (sum_G | sum_R | sum_S);

    // 根据 GRS 计算进位
    always_comb begin
        case (rm)
            RNE     : sum_roundup = sum_G & (sum_R | sum_S | sum_lsb);
            RTZ     : sum_roundup = 0;
            RDN     : sum_roundup = ~(sum_G | sum_R | sum_S) & sum_sign_res;
            RUP     : sum_roundup = ~(sum_G | sum_R | sum_S) & ~sum_sign_res;
            RMM     : sum_roundup = sum_G;
            default : sum_roundup = 0;
        endcase
    end
    
    // 舍入后进位处理
    logic [7:0]  sum_exp_roundup;
    logic [23:0] sum_mant_roundup1, sum_mant_roundup2;
    logic        sum_mant_roundup_carry;
    logic        sum_roundup_overflow;
    always_comb begin
        {sum_mant_roundup_carry, sum_mant_roundup1} = sum_mant_norm[26:3] + sum_roundup;
        sum_roundup_overflow = 0;

        if (sum_mant_roundup_carry) begin
            if (sum_exp_norm == 254) begin
                sum_roundup_overflow = 1;
                sum_exp_roundup      = 0;
                sum_mant_roundup2    = 0;
            end
            else begin
                sum_exp_roundup   = sum_exp_norm + 1;
                sum_mant_roundup2 = {1'b1, sum_mant_roundup1[23:1]};
            end
        end
        else begin
            sum_exp_roundup   = sum_exp_norm;
            sum_mant_roundup2 = sum_mant_roundup1;
        end
    end
    
    
    // 7. 特殊值处理
    fval_t sum_final;
    assign sum_final.sign = sum_sign_res;
    assign sum_final.exp  = sum_exp_roundup;
    assign sum_final.mant = sum_mant_roundup2[22:0];

    wire [31:0] sum_res = sum_final;

    // fflags 写入
    fflags_t flags;
    assign flags.NV = fval1_is_nan | fval2_is_nan | sum_diff_inf;
    assign flags.OF = sum_norm_overflow | sum_roundup_overflow;
    assign flags.UF = sum_norm_underflow;
    assign flags.NX = sum_roundup_inexact;

    assign fflags = (ipkg.is_FP) ? flags : 0;



    // fclass
    // fcmp
    // fmax, min
    // fmv, fcvt
    // fsgnj
    // fmul, fdiv

    always_comb begin
        unique case (1'b1)
            ipkg.sel_fadd_s, ipkg.sel_fsub_s   : result = sum_res;
            ipkg.sel_fmv_w_x, ipkg.sel_fmv_x_w : result = value1;
            default                            : result = 32'b0;
        endcase
    end
    

    assign ctrl = 1'b0;
endmodule