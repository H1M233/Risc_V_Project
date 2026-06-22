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
    wire [7:0]  OFFEST_CONST = 8'd127;
    wire [31:0] NORMAL_QNAN  = 32'h7fc00000;
    wire [31:0] P_INF        = 32'h7f800000;
    wire [31:0] N_INF        = 32'hff800000;
    
    // F 数据解码
    fval_t fval1, fval2, fval3;
    assign fval1 = value1;
    assign fval2 = value2;
    assign fval3 = dpkg.rs3_rdata;

    rm_t rm;
    assign rm = rm_t'((dpkg.imm[2:0] == 3'b111) ? dpkg.csr_rdata[7:5] : dpkg.imm[2:0]); // 3'b111 动态舍入模式

    // 特殊值识别
    wire fval1_is_nan = (fval1.exp == 8'd255) & (fval1.mant != 0);
    wire fval2_is_nan = (fval2.exp == 8'd255) & (fval2.mant != 0);
    wire fval3_is_nan = (fval3.exp == 8'd255) & (fval3.mant != 0);

    wire fval1_is_snan = fval1_is_nan & ~fval1.mant[22];
    wire fval2_is_snan = fval2_is_nan & ~fval2.mant[22];

    wire fval1_is_qnan = fval1_is_nan & fval1.mant[22];
    wire fval2_is_qnan = fval2_is_nan & fval2.mant[22];
    
    wire fval1_is_inf = (fval1.exp == 8'd255) & (fval1.mant == 0);
    wire fval2_is_inf = (fval2.exp == 8'd255) & (fval2.mant == 0);
    wire fval3_is_inf = (fval3.exp == 8'd255) & (fval3.mant == 0);
    
    wire fval1_is_subnormal = (fval1.exp == 8'd0) & (fval1.mant != 0);
    wire fval2_is_subnormal = (fval2.exp == 8'd0) & (fval2.mant != 0);
    
    wire fval1_is_zero = (fval1.exp == 8'd0) & (fval1.mant == 0);
    wire fval2_is_zero = (fval2.exp == 8'd0) & (fval2.mant == 0);

    wire fval1_is_normal = (fval1.exp != 8'd0) & (fval1.exp != 8'd255);
    wire fval2_is_normal = (fval2.exp != 8'd0) & (fval2.exp != 8'd255);
    
    // -------------------------------------
    // fclass
    // -------------------------------------
    wire fval1_is_pinf = fval1_is_inf & ~fval1.sign;
    wire fval1_is_ninf = fval1_is_inf & fval1.sign;

    wire fval1_is_psubnormal = fval1_is_subnormal & ~fval1.sign;
    wire fval1_is_nsubnormal = fval1_is_subnormal & fval1.sign;

    wire fval1_is_pzero = fval1_is_zero & ~fval1.sign;
    wire fval1_is_nzero = fval1_is_zero & fval1.sign;

    wire fval1_is_pnormal = fval1_is_normal & ~fval1.sign;
    wire fval1_is_nnormal = fval1_is_normal & fval1.sign;

    logic [31:0] fclass_res;
    always_comb begin
        fclass_res = 0;

        fclass_res[9] = fval1_is_qnan;          // qNaN
        fclass_res[8] = fval1_is_snan;          // sNaN
        fclass_res[7] = fval1_is_pinf;          // + inf
        fclass_res[6] = fval1_is_pnormal;       // + 规格化数
        fclass_res[5] = fval1_is_psubnormal;    // + 非规格化数
        fclass_res[4] = fval1_is_pzero;         // + 0
        fclass_res[3] = fval1_is_nzero;         // - 0
        fclass_res[2] = fval1_is_nsubnormal;    // - 非规格化数
        fclass_res[1] = fval1_is_nnormal;       // - 规格化数
        fclass_res[0] = fval1_is_ninf;          // - inf
    end

    // -------------------------------------
    // fadd.s, fsub.s:
    // -------------------------------------
    wire sum_fval_nv  = (fval1_is_nan | fval2_is_nan) && (ipkg.sel_fadd_s | ipkg.sel_fsub_s);   // flags.NV: 输入其一有 NaN
    wire sum_sub_inf = fval1_is_inf & fval2_is_inf & 
                        ((ipkg.sel_fadd_s & (fval1.sign != fval2.sign)) 
                      | (ipkg.sel_fsub_s & (fval1.sign == fval2.sign))
                      );   // flags.NV: inf - inf 运算

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
    wire [7:0] exp_diff = exp_large - exp_small;

    logic [26:0] mant_small_shifted;
    logic [22:0] sum_collect_S_shift;
    assign {mant_small_shifted, sum_collect_S_shift} = {mant_small, 23'b0} >> exp_diff;
    
    wire sum_shift_S = (exp_diff >= 24) ? 1 : |sum_collect_S_shift;

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
    function automatic logic [4:0] lz27(input logic [26:0] mant);
        if (|mant) begin
            for (int i = 26; i >= 0; i--) begin
                if (mant[i]) return 5'(26 - i);
            end
        end
        else return 5'b0;
    endfunction

    assign lz_cnt = lz27(sum_mant_res);

    // 5. 溢出 & 规格化
    logic [26:0] sum_mant_norm;
    logic [7:0]  sum_exp_norm;
    logic        sum_norm_S;
    logic        sum_norm_overflow, sum_norm_underflow;
    
    wire mant_zero = ~(|sum_mant_res) && ~sum_carry_calc;
    always_comb begin
        sum_norm_S          = 0;
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
                sum_norm_S      = sum_mant_res[0];
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
    wire  sum_S   = sum_shift_S | sum_norm_S | sum_mant_norm[0];
    logic sum_roundup;
    logic sum_roundup_inexact;
    assign sum_roundup_inexact = (ipkg.sel_fadd_s | ipkg.sel_fsub_s) & (sum_G | sum_R | sum_S);

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

    wire [31:0] sum_res = (sum_sub_inf) ? NORMAL_QNAN : sum_final;

    wire sum_OF = (ipkg.sel_fadd_s | ipkg.sel_fsub_s) & (sum_roundup_overflow | sum_norm_overflow);
    wire sum_UF = (ipkg.sel_fadd_s | ipkg.sel_fsub_s) & sum_norm_underflow;

    // -------------------------------------
    // fcmp (feq.s, fle.s, flt.s):
    // -------------------------------------
    wire [31:0] fval1_unsigned = (fval1.sign) ? ~fval1 : {1'b1, fval1.exp, fval1.mant};
    wire [31:0] fval2_unsigned = (fval2.sign) ? ~fval2 : {1'b1, fval2.exp, fval2.mant};

    wire normal_eq = (fval1_unsigned == fval2_unsigned);
    wire normal_lt = (fval1_unsigned < fval2_unsigned);

    wire normal_eq_ignore_zero = normal_eq | (fval1_is_zero & fval2_is_zero);
    wire normal_lt_ignore_zero = normal_lt & ~(fval1_is_zero & fval2_is_zero);

    wire feq_s_res = (fval1_is_nan | fval2_is_nan) ? 0 : normal_eq_ignore_zero;
    wire flt_s_res = (fval1_is_nan | fval2_is_nan) ? 0 : normal_lt_ignore_zero;
    wire fle_s_res = feq_s_res | flt_s_res;

    wire fcmp_fval_nv = ((fval1_is_snan | fval2_is_snan) & ipkg.sel_feq_s) 
                      | ((fval1_is_nan | fval2_is_nan) & (ipkg.sel_flt_s | ipkg.sel_fle_s));   // flags.NV: feq.s 时输入其一有 sNaN, flt.s & fle.s 时输入其一有 NaN

    // -------------------------------------
    // fmax, fmin:
    // -------------------------------------
    wire fmaxmin_fval_nv = (fval1_is_snan | fval2_is_snan) && (ipkg.sel_fmax_s | ipkg.sel_fmin_s);  // flags.NV: 输入其一有 NaN

    logic [31:0] fmax_s_res, fmin_s_res;
    always_comb begin
        if (fval1_is_nan & fval2_is_nan) begin
            fmax_s_res = NORMAL_QNAN;
            fmin_s_res = NORMAL_QNAN;
        end
        else if (fval1_is_nan) begin
            fmax_s_res = fval2;
            fmin_s_res = fval2;
        end
        else if (fval2_is_nan) begin
            fmax_s_res = fval1;
            fmin_s_res = fval1;
        end
        else begin
            fmax_s_res = (normal_lt) ? fval2 : fval1;
            fmin_s_res = (normal_lt) ? fval1 : fval2;
        end
    end

    // -------------------------------------
    // fsgnj.s, fsgnjn.s, fsgnjx.s:
    // -------------------------------------
    wire [31:0] fsgnj_s_res  = (fval1_is_nan) ? NORMAL_QNAN : {fval2.sign, fval1.exp, fval1.mant};
    wire [31:0] fsgnjn_s_res = (fval1_is_nan) ? NORMAL_QNAN : {~fval2.sign, fval1.exp, fval1.mant};
    wire [31:0] fsgnjx_s_res = (fval1_is_nan) ? NORMAL_QNAN : {fval1.sign ^ fval2.sign, fval1.exp, fval1.mant};

    // -------------------------------------
    // fcvt.s.w, fcvt.s.wu, fcvt.wu.s: 
    // -------------------------------------
    // 整型 -> 浮点
    wire [31:0] fcvt_s_mant_ext         = (ipkg.sel_fcvt_s_w & value1[31]) ? ~value1 + 1 : value1;
    wire [4:0]  fcvt_s_mant_ext_lnz     = lnz32(fcvt_s_mant_ext);
    wire        fcvt_s_need_left_shift  = (fcvt_s_mant_ext_lnz < 5'd23);
    wire        fcvt_s_need_right_shift = (fcvt_s_mant_ext_lnz > 5'd23);
    wire [4:0]  fcvt_s_left_shift_diff  = 5'd23 - fcvt_s_mant_ext_lnz;
    wire [4:0]  fcvt_s_right_shift_diff = fcvt_s_mant_ext_lnz - 5'd23;
    wire [22:0] fcvt_s_left_shifted     = fcvt_s_mant_ext << fcvt_s_left_shift_diff;

    logic [22:0] fcvt_s_shift_collect_S;
    logic [26:0] fcvt_s_right_shifted;
    assign {fcvt_s_right_shifted, fcvt_s_shift_collect_S} = {1'b1, fcvt_s_mant_ext, 3'b0, 23'b0} >> fcvt_s_right_shift_diff;
    function automatic logic [4:0] lnz32(input logic [31:0] val);
        if (|val) begin
            for (int i = 31; i >= 0; i--) begin
                if (val[i]) return 5'(i);
            end
        end
        else return 5'b0;
    endfunction

    // 舍入
    wire  fcvt_lsb = fcvt_s_right_shifted[3];
    wire  fcvt_G   = fcvt_s_right_shifted[2];
    wire  fcvt_R   = fcvt_s_right_shifted[1];
    wire  fcvt_S   = fcvt_s_right_shifted[0] | (|fcvt_s_shift_collect_S);
    logic fcvt_roundup;
    logic fcvt_roundup_inexact;
    assign fcvt_roundup_inexact = (ipkg.sel_fcvt_s_w | ipkg.sel_fcvt_s_wu) & fcvt_s_need_right_shift & (fcvt_G | fcvt_R | fcvt_S);  // flags.NX: fcvt.s.w & fcvt.s.wu 时舍入导致不精确

    // 根据 GRS 计算进位
    always_comb begin
        case (rm)
            RNE     : fcvt_roundup = fcvt_G & (fcvt_R | fcvt_S | fcvt_lsb);
            RTZ     : fcvt_roundup = 0;
            RDN     : fcvt_roundup = ~(fcvt_G | fcvt_R | fcvt_S) & (ipkg.sel_fcvt_s_w & value1[31]);
            RUP     : fcvt_roundup = ~(fcvt_G | fcvt_R | fcvt_S) & ~(ipkg.sel_fcvt_s_w & value1[31]);
            RMM     : fcvt_roundup = fcvt_G;
            default : fcvt_roundup = 0;
        endcase
    end
    
    // 舍入后进位处理
    wire  [7:0]  fcvt_exp_roundup1 = OFFEST_CONST + fcvt_s_mant_ext_lnz;
    logic [7:0]  fcvt_exp_roundup2;
    logic [23:0] fcvt_mant_roundup1, fcvt_mant_roundup2;
    logic        fcvt_mant_roundup_carry;
    always_comb begin
        {fcvt_mant_roundup_carry, fcvt_mant_roundup1} = fcvt_s_right_shifted[26:3] + fcvt_roundup;

        if (fcvt_mant_roundup_carry) begin
            fcvt_exp_roundup2  = fcvt_exp_roundup1 + 1;
            fcvt_mant_roundup2 = {1'b1, fcvt_mant_roundup1[23:1]};
        end
        else begin
            fcvt_exp_roundup2  = fcvt_exp_roundup1;
            fcvt_mant_roundup2 = fcvt_mant_roundup1;
        end
    end

    fval_t fcvt_s_res;
    assign fcvt_s_res.sign = (ipkg.sel_fcvt_s_w & value1[31]);
    assign fcvt_s_res.exp  = (|value1) ? OFFEST_CONST + fcvt_s_mant_ext_lnz + fcvt_mant_roundup_carry: 0;
    always_comb begin
        if (value1 == 0) begin
            fcvt_s_res.exp  = 0;
            fcvt_s_res.mant = 0;
        end
        else begin
            unique case (1'b1)
                fcvt_s_need_left_shift  : begin
                    fcvt_s_res.exp  = OFFEST_CONST + fcvt_s_mant_ext_lnz;
                    fcvt_s_res.mant = fcvt_s_left_shifted;
                end 
                fcvt_s_need_right_shift : begin
                    fcvt_s_res.exp  = fcvt_exp_roundup2;
                    fcvt_s_res.mant = fcvt_mant_roundup2[22:0];
                end
                default : begin
                    fcvt_s_res.exp  = OFFEST_CONST;
                    fcvt_s_res.mant = fcvt_s_mant_ext[22:0];
                end
            endcase
        end
    end

    // 浮点 -> 整数
    wire [7:0]  fval1_true_exp          = fval1.exp - OFFEST_CONST;
    wire        fcvt_w_need_left_shift  = ($signed(fval1_true_exp - 8'd23) > 0);
    wire        fcvt_w_need_right_shift = ($signed(fval1_true_exp - 8'd23) < 0);
    wire [7:0]  fcvt_w_left_shift_diff  = fval1_true_exp - 8'd23;
    wire [7:0]  fcvt_w_right_shift_diff =  8'd23 - fval1_true_exp;

    // 考虑 INTMAX
    logic        fcvt_w_get_int_max;
    logic [31:0] fcvt_w_get_int_max_res;
    always_comb begin
        unique case (1'b1)
            ipkg.sel_fcvt_w_s : begin
                fcvt_w_get_int_max     = ((fcvt_w_left_shift_diff >= 8) | fval1_is_nan) & fcvt_w_need_left_shift;
                fcvt_w_get_int_max_res = (fval1.sign & ~fval1_is_nan) ? 32'h80000000 : 32'h7fffffff;
            end
            ipkg.sel_fcvt_wu_s : begin
                fcvt_w_get_int_max     = (((fcvt_w_left_shift_diff > 8) & ~fval1.sign) | fval1_is_nan) & fcvt_w_need_left_shift;
                fcvt_w_get_int_max_res = 32'hffffffff;
            end
            default : begin
                fcvt_w_get_int_max     = 1'b0;
                fcvt_w_get_int_max_res = 32'b0;
            end
        endcase
    end

    wire [31:0] fcvt_w_left_shifted = {1'b1, fval1.mant} << fcvt_w_left_shift_diff;

    logic [34:0] fcvt_w_right_shifted;
    logic [22:0] fcvt_w_shift_collect_S;
    assign {fcvt_w_right_shifted, fcvt_w_shift_collect_S} = {1'b1, fval1.mant, 3'b0, 23'b0} >> fcvt_w_right_shift_diff;
    wire fcvt_w_shift_S = (fcvt_w_right_shift_diff > 26) ? 1 : |fcvt_w_shift_collect_S;

    wire fcvt_w_lsb = fcvt_w_right_shifted[3];
    wire fcvt_w_G   = fcvt_w_right_shifted[2];
    wire fcvt_w_R   = fcvt_w_right_shifted[1];
    wire fcvt_w_S   = fcvt_w_right_shifted[0] | fcvt_w_shift_S;

    logic fcvt_w_roundup;
    logic fcvt_w_roundup_inexact;
    assign fcvt_w_roundup_inexact = (ipkg.sel_fcvt_w_s | ipkg.sel_fcvt_wu_s) & fcvt_w_need_right_shift & (fcvt_w_G | fcvt_w_R | fcvt_w_S);  // flags.NX: fcvt.w.s & fcvt.wu.s 时舍入导致不精确

    // 根据 GRS 计算进位
    always_comb begin
        case (rm)
            RNE     : fcvt_w_roundup = fcvt_w_G & (fcvt_w_R | fcvt_w_S | fcvt_w_lsb);
            RTZ     : fcvt_w_roundup = 0;
            RDN     : fcvt_w_roundup = ~(fcvt_w_G | fcvt_w_R | fcvt_w_S) & (ipkg.sel_fcvt_w_s & fval1.sign);
            RUP     : fcvt_w_roundup = ~(fcvt_w_G | fcvt_w_R | fcvt_w_S) & ~(ipkg.sel_fcvt_w_s & fval1.sign);
            RMM     : fcvt_w_roundup = fcvt_w_G;
            default : fcvt_w_roundup = 0;
        endcase
    end

    logic [31:0] fcvt_w_unsigned;
    always_comb begin
        unique case (1'b1)
            fcvt_w_need_left_shift  : fcvt_w_unsigned = fcvt_w_left_shifted;
            fcvt_w_need_right_shift : fcvt_w_unsigned = fcvt_w_right_shifted[34:3] + fcvt_w_roundup;
            default                 : fcvt_w_unsigned = {9'b0, fval1.mant};
        endcase
    end
    

    wire [31:0] fcvt_w_nunsigned = (ipkg.sel_fcvt_w_s) ? ~fcvt_w_unsigned + 1 : 32'h0;
    wire [31:0] fcvt_w_signed    = (fval1.sign) ? fcvt_w_nunsigned : fcvt_w_unsigned;
    wire [31:0] fcvt_w_res       = (fval1_is_zero)      ? 0 : 
                                   (fcvt_w_get_int_max) ? fcvt_w_get_int_max_res : fcvt_w_signed;

    wire fcvt_NV = ipkg.sel_fcvt_wu_s & (fval1_is_zero | (fval1.sign & ($signed(fval1_true_exp) >= 0)));   // flags.NV: fcvt.wu.s 时试图输出负值

    // -------------------------------------
    // fmul.s: 
    // -------------------------------------
    logic       fmul_exp_add_carry;
    logic [7:0] fmul_exp_add_res;
    assign {fmul_exp_add_carry, fmul_exp_add_res} = fval1.exp + fval2.exp - OFFEST_CONST;

    logic        fmul_mant_mul_carry;
    logic [26:0] fmul_mant_mul_res;
    logic [19:0] fmul_collect_S;
    assign {fmul_mant_mul_carry, fmul_mant_mul_res, fmul_collect_S} = {1'b1, fval1.mant} * {1'b1, fval2.mant};

    wire [26:0] fmul_mant_pre_roundup = (fmul_mant_mul_carry) ? {1'b1, fmul_mant_mul_res[26:1]} : fmul_mant_mul_res[26:0];

    wire fmul_lsb = fmul_mant_pre_roundup[3];
    wire fmul_G   = fmul_mant_pre_roundup[2];
    wire fmul_R   = fmul_mant_pre_roundup[1];
    wire fmul_S   = fmul_mant_pre_roundup[0] | (|fmul_collect_S);

    logic fmul_roundup;
    logic fmul_roundup_inexact;
    assign fmul_roundup_inexact = ~(fval1_is_zero | fval2_is_zero) & (fmul_G | fmul_R | fmul_S);  // flags.NX: fmul.s 时舍入导致不精确

    // 根据 GRS 计算进位
    always_comb begin
        case (rm)
            RNE     : fmul_roundup = fmul_G & (fmul_R | fmul_S | fmul_lsb);
            RTZ     : fmul_roundup = 0;
            RDN     : fmul_roundup = ~(fmul_G | fmul_R | fmul_S) & (fval1.sign ^ fval2.sign);
            RUP     : fmul_roundup = ~(fmul_G | fmul_R | fmul_S) & ~(fval1.sign ^ fval2.sign);
            RMM     : fmul_roundup = fmul_G;
            default : fmul_roundup = 0;
        endcase
    end

    logic        fmul_exp_roundup_carry;
    logic [7:0]  fmul_exp_roundup;
    logic        fmul_mant_roundup_carry;
    logic [23:0] fmul_mant_roundup;
    assign {fmul_mant_roundup_carry, fmul_mant_roundup} = fmul_mant_pre_roundup[26:3] + fmul_roundup;
    assign {fmul_exp_roundup_carry, fmul_exp_roundup}   = fmul_exp_add_res + fmul_mant_mul_carry + fmul_mant_roundup_carry;

    fval_t fmul_s_res;
    always_comb begin
        if (fval1_is_zero | fval2_is_zero) begin
            fmul_s_res = 0;
        end
        else if (fval1_is_nan | fval2_is_nan) begin
            fmul_s_res = NORMAL_QNAN;
        end
        else if (fmul_exp_add_carry | fmul_exp_roundup_carry) begin
            fmul_s_res.sign = fval1.sign ^ fval2.sign;
            fmul_s_res.exp  = 8'd255;
            fmul_s_res.mant = 0;
        end
        else begin
            fmul_s_res.sign = fval1.sign ^ fval2.sign;
            fmul_s_res.exp  = fmul_exp_roundup;
            fmul_s_res.mant = (fmul_mant_roundup_carry) ? {1'b1, fmul_mant_roundup[23:1]} : fmul_mant_roundup[22:0];
        end
    end

    wire fmul_NV = ipkg.sel_fmul_s & (fval1_is_snan | fval2_is_snan);
    wire fmul_NX = ipkg.sel_fmul_s & fmul_roundup_inexact;

    // -------------------------------------
    // fdiv.s: 
    // -------------------------------------
    // 特殊值输入判断
    logic  fdiv_div_zero;           // flags.DZ: 除 0
    logic  fdiv_zero_div_zero;      // flags.NV: 0 / 0
    logic  fdiv_special_case;
    fval_t fdiv_special_res;
    always_comb begin
        fdiv_div_zero      = 0;
        fdiv_zero_div_zero = 0;
        fdiv_special_case  = 0;
        fdiv_special_res   = 0;

        if (fval2_is_zero) begin
            fdiv_special_case = 1;
            unique case (1'b1)
                fval1_is_zero: begin
                    fdiv_zero_div_zero = 1;
                    fdiv_special_res   = NORMAL_QNAN;
                end

                fval1_is_nan: begin
                    fdiv_special_res = fval1;
                end

                default: begin
                    fdiv_div_zero         = 1;
                    fdiv_special_res.sign = fval1.sign ^ fval2.sign;
                    fdiv_special_res.exp  = 8'd255;
                    fdiv_special_res.mant = 23'b0;
                end
            endcase
        end
        else if (fval1_is_zero) begin
            fdiv_special_case = 1;
            fdiv_special_res  = 0;
        end
    end

    logic       fdiv_exp_diff_carry;    // fdiv_exp_diff_carry = 1: 下溢
    logic [7:0] fdiv_exp_diff_res;
    assign {fdiv_exp_diff_carry, fdiv_exp_diff_res} = fval1.exp - fval2.exp + OFFEST_CONST;

    logic        fdiv_divider_instance_valid;
    logic [26:0] fdiv_divider_instance_result;
    Fdivider FEXT_DIVIDER (
        .clk        (clk),
        .rst        (rst),
        .valid_i    (ipkg.sel_fdiv_s & ~fdiv_special_case),
        .dividend_i (fval1.mant),
        .divisor_i  (fval2.mant),
        .flush_i    (flush),
        .valid_o    (fdiv_divider_instance_valid),
        .result_o   (fdiv_divider_instance_result)
    );
    
    wire        fdiv_divider_res_need_left_shift = ~fdiv_divider_instance_result[26];
    wire [26:0] fdiv_divider_res_left_shifted    = (fdiv_divider_res_need_left_shift) ? fdiv_divider_instance_result << 1 : 
                                                                                        fdiv_divider_instance_result;

    wire fdiv_lsb = fdiv_divider_res_left_shifted[3];
    wire fdiv_G   = fdiv_divider_res_left_shifted[2];
    wire fdiv_R   = fdiv_divider_res_left_shifted[1];
    wire fdiv_S   = fdiv_divider_res_left_shifted[0];

    logic fdiv_roundup;
    logic fdiv_roundup_inexact;
    assign fdiv_roundup_inexact = ~(fval1_is_zero | fval2_is_zero) & (fdiv_G | fdiv_R | fdiv_S);  // flags.NX: fdiv.s 时舍入导致不精确

    // 根据 GRS 计算进位
    always_comb begin
        case (rm)
            RNE     : fdiv_roundup = fdiv_G & (fdiv_R | fdiv_S | fdiv_lsb);
            RTZ     : fdiv_roundup = 0;
            RDN     : fdiv_roundup = ~(fdiv_G | fdiv_R | fdiv_S) & (fval1.sign ^ fval2.sign);
            RUP     : fdiv_roundup = ~(fdiv_G | fdiv_R | fdiv_S) & ~(fval1.sign ^ fval2.sign);
            RMM     : fdiv_roundup = fdiv_G;
            default : fdiv_roundup = 0;
        endcase
    end

    logic        fdiv_exp_roundup_carry;
    logic [7:0]  fdiv_exp_roundup;
    logic        fdiv_mant_roundup_carry;
    logic [23:0] fdiv_mant_roundup;
    assign {fdiv_mant_roundup_carry, fdiv_mant_roundup} = fdiv_divider_res_left_shifted[26:3] + fdiv_roundup;
    assign {fdiv_exp_roundup_carry, fdiv_exp_roundup}   = fdiv_exp_diff_res - fdiv_divider_res_need_left_shift + fdiv_mant_roundup_carry;

    logic  fdiv_roundup_overflow;
    logic  fdiv_exp_diff_underflow;
    fval_t fdiv_s_res;
    always_comb begin
        fdiv_roundup_overflow   = 0;
        fdiv_exp_diff_underflow = 0;

        if (fdiv_special_case) begin
            fdiv_s_res = fdiv_special_res;
        end
        else if (fdiv_exp_diff_carry) begin         // 下溢 - 会导致不精确 同时报出 NX
            fdiv_exp_diff_underflow = 0;
            fdiv_s_res.sign         = 0;
            fdiv_s_res.exp          = 0;
            fdiv_s_res.mant         = 0;
        end
        else if  (fdiv_exp_roundup_carry) begin     // 上溢
            fdiv_roundup_overflow = 1;
            fdiv_s_res.sign       = 0;
            fdiv_s_res.exp        = 8'd255;
            fdiv_s_res.mant       = 0;
        end
        else begin
            fdiv_s_res.sign = fval1.sign ^ fval2.sign;
            fdiv_s_res.exp  = fdiv_exp_roundup;
            fdiv_s_res.mant = (fdiv_mant_roundup_carry) ? {1'b1, fdiv_mant_roundup[23:1]} : fdiv_mant_roundup[22:0];
        end
    end

    wire fdiv_NV = ipkg.sel_fdiv_s & fdiv_zero_div_zero;
    wire fdiv_DZ = ipkg.sel_fdiv_s & fdiv_div_zero;
    wire fdiv_OF = ipkg.sel_fdiv_s & fdiv_roundup_overflow;
    wire fdiv_UF = ipkg.sel_fdiv_s & fdiv_exp_diff_underflow;
    wire fdiv_NX = ipkg.sel_fdiv_s & (fdiv_roundup_inexact | fdiv_exp_diff_underflow);

    wire fdiv_ctrl = ipkg.sel_fdiv_s & ~fdiv_divider_instance_valid & ~fdiv_special_case;

    // -------------------------------------
    // fsqrt.s: 
    // -------------------------------------
    // 特殊值输入判断
    logic  fsqrt_fval_NV;
    logic  fsqrt_special_case;
    fval_t fsqrt_special_res;
    always_comb begin
        fsqrt_fval_NV       = 0;
        fsqrt_special_case  = 0;
        fsqrt_special_res   = 0;

        if (fval1.sign) begin
            fsqrt_fval_NV      = 1;
            fsqrt_special_case = 1;
            fsqrt_special_res  = NORMAL_QNAN;
        end
        else if (fval1_is_zero) begin
            fsqrt_special_case = 1;
            fsqrt_special_res  = 0;
        end
    end

    logic [7:0] fsqrt_exp_shift_res;
    logic       fsqrt_exp_shift_half;
    assign {fsqrt_exp_shift_res, fsqrt_exp_shift_half} = fval1.exp - OFFEST_CONST + {OFFEST_CONST, 1'b0};

    logic        fsqrt_instance_valid;
    logic [26:0] fsqrt_instance_result;
    Fsqrt FEXT_SQRT (
        .clk        (clk),
        .rst        (rst),
        .valid_i    (ipkg.sel_fsqrt_s & ~fsqrt_special_case),
        .S_i        (fval1.mant),
        .mul2       (fsqrt_exp_shift_half),
        .flush_i    (flush),
        .valid_o    (fsqrt_instance_valid),
        .result_o   (fsqrt_instance_result)
    );
    
    wire        fsqrt_res_need_left_shift = ~fsqrt_instance_result[26];
    wire [26:0] fsqrt_res_left_shifted    = (fsqrt_res_need_left_shift) ? fsqrt_instance_result << 1 : 
                                                                          fsqrt_instance_result;

    wire fsqrt_lsb = fsqrt_res_left_shifted[3];
    wire fsqrt_G   = fsqrt_res_left_shifted[2];
    wire fsqrt_R   = fsqrt_res_left_shifted[1];
    wire fsqrt_S   = fsqrt_res_left_shifted[0];

    logic fsqrt_roundup;
    logic fsqrt_roundup_inexact;
    assign fsqrt_roundup_inexact = ~(fval1_is_zero) & (fsqrt_G | fsqrt_R | fsqrt_S);  // flags.NX: fdiv.s 时舍入导致不精确

    // 根据 GRS 计算进位
    always_comb begin
        case (rm)
            RNE     : fsqrt_roundup = fsqrt_G & (fsqrt_R | fsqrt_S | fsqrt_lsb);
            RTZ     : fsqrt_roundup = 0;
            RDN     : fsqrt_roundup = ~(fsqrt_G | fsqrt_R | fsqrt_S) & (fval1.sign);
            RUP     : fsqrt_roundup = ~(fsqrt_G | fsqrt_R | fsqrt_S) & ~(fval1.sign);
            RMM     : fsqrt_roundup = fsqrt_G;
            default : fsqrt_roundup = 0;
        endcase
    end

    logic        fsqrt_exp_roundup_carry;
    logic [7:0]  fsqrt_exp_roundup;
    logic        fsqrt_mant_roundup_carry;
    logic [23:0] fsqrt_mant_roundup;
    assign {fsqrt_mant_roundup_carry, fsqrt_mant_roundup} = fsqrt_res_left_shifted[26:3] + fsqrt_roundup;
    assign {fsqrt_exp_roundup_carry, fsqrt_exp_roundup}   = fsqrt_exp_shift_res - fsqrt_res_need_left_shift + fsqrt_mant_roundup_carry;

    logic  fsqrt_roundup_overflow;
    logic  fsqrt_exp_diff_underflow;
    fval_t fsqrt_s_res;
    always_comb begin
        fsqrt_roundup_overflow   = 0;
        fsqrt_exp_diff_underflow = 0;

        if (fsqrt_special_case) begin
            fsqrt_s_res = fsqrt_special_res;
        end
        else if (fsqrt_exp_shift_res == 0) begin         // 下溢 - 会导致不精确 同时报出 NX
            fsqrt_exp_diff_underflow = 0;
            fsqrt_s_res.sign         = 0;
            fsqrt_s_res.exp          = 0;
            fsqrt_s_res.mant         = 0;
        end
        else if (fsqrt_exp_roundup_carry) begin     // 上溢
            fsqrt_roundup_overflow = 1;
            fsqrt_s_res.sign       = 0;
            fsqrt_s_res.exp        = 8'd255;
            fsqrt_s_res.mant       = 0;
        end
        else begin
            fsqrt_s_res.sign = 0;
            fsqrt_s_res.exp  = fsqrt_exp_roundup;
            fsqrt_s_res.mant = (fsqrt_mant_roundup_carry) ? {1'b1, fsqrt_mant_roundup[23:1]} : fsqrt_mant_roundup[22:0];
        end
    end

    wire fsqrt_NV = ipkg.sel_fsqrt_s & fsqrt_fval_NV;
    wire fsqrt_OF = ipkg.sel_fsqrt_s & fsqrt_roundup_overflow;
    wire fsqrt_UF = ipkg.sel_fsqrt_s & fsqrt_exp_diff_underflow;
    wire fsqrt_NX = ipkg.sel_fsqrt_s & (fsqrt_roundup_inexact | fsqrt_exp_diff_underflow);

    wire fsqrt_ctrl = ipkg.sel_fsqrt_s & ~fsqrt_instance_valid & ~fsqrt_special_case;

    // -------------------------------------
    // fmadd.s, fmsub.s, fnmadd.s, fnmsub.s: 
    // -------------------------------------
    // 乘法运算 - fval1 * fval2
    logic       fmsum_exp_add_carry;
    logic [7:0] fmsum_exp_add_res;
    assign {fmsum_exp_add_carry, fmsum_exp_add_res} = fval1.exp + fval2.exp - OFFEST_CONST;

    logic        fmsum_mant_mul_carry;
    logic [26:0] fmsum_mant_mul_res;
    logic [19:0] fmsum_mant_mul_res_low;
    assign {fmsum_mant_mul_carry, fmsum_mant_mul_res, fmsum_mant_mul_res_low} = {1'b1, fval1.mant} * {1'b1, fval2.mant};

    wire [47:0] fmsum_mant_mul_norm = (fmul_mant_mul_carry) ? {1'b1, fmul_mant_mul_res, fmsum_mant_mul_res_low} : {fmul_mant_mul_res, fmsum_mant_mul_res_low, 1'b0};

    logic  fmsum_mul_is_inf;
    logic  fmsum_mul_is_nan;
    logic  fmsum_pre_sum_special_case;
    fval_t fmsum_pre_sum_special_case_res;
    always_comb begin
        fmsum_mul_is_inf               = 0;
        fmsum_mul_is_nan               = 0;
        fmsum_pre_sum_special_case     = 0;
        fmsum_pre_sum_special_case_res = 0;

        if (fval1_is_zero | fval2_is_zero) begin
            fmsum_pre_sum_special_case     = 1;
            fmsum_pre_sum_special_case_res = 0;
        end
        else if (fval1_is_nan | fval2_is_nan) begin
            fmsum_mul_is_nan               = 1;
            fmsum_pre_sum_special_case     = 1;
            fmsum_pre_sum_special_case_res = NORMAL_QNAN;
        end
        else if (fmsum_exp_add_carry) begin
            fmsum_mul_is_inf                    = 1;
            fmsum_pre_sum_special_case          = 1;
            fmsum_pre_sum_special_case_res.sign = fval1.sign ^ fval2.sign;
            fmsum_pre_sum_special_case_res.exp  = 8'd255;
            fmsum_pre_sum_special_case_res.mant = 0;
        end
    end

    wire        fmsum_pre_sum_sign = (fmsum_pre_sum_special_case) ? fmsum_pre_sum_special_case_res.sign : fval1.sign ^ fval2.sign;
    wire [7:0]  fmsum_pre_sum_exp  = (fmsum_pre_sum_special_case) ? fmsum_pre_sum_special_case_res.exp  : fmsum_exp_add_res;
    wire [47:0] fmsum_pre_sum_mant = (fmsum_pre_sum_special_case) ? {fmsum_pre_sum_special_case_res.mant, 25'b0} : fmsum_mant_mul_norm;

    // 求和运算 - +-(fmsum_mul_res +- fval3)
    wire fmsum_fval_nv = (fmsum_mul_is_nan | fval3_is_nan) & ipkg.is_fM;   // flags.NV: 输入其一有 NaN
    wire fmsum_sub_inf = fmsum_mul_is_inf & fval3_is_inf & 
                         (((ipkg.sel_fmadd_s | ipkg.sel_fnmadd_s) & (fval1.sign != fval2.sign)) 
                       | ((ipkg.sel_fmsub_s | ipkg.sel_fnmsub_s) & (fval1.sign == fval2.sign)));   // flags.NV: inf - inf 运算

    // 1. 指数比较
    wire fmsum_fvalmul_exp_gt_fval3 = (fmsum_pre_sum_exp >= fval3.exp);
    
    logic [7:0]  fmsum_exp_large, fmsum_exp_small;
    logic [47:0] fmsum_mant_large, fmsum_mant_small;    // 还原最高位 1, 保留 GRS
    always_comb begin
        if (fmsum_fvalmul_exp_gt_fval3) begin
            fmsum_exp_large  = fmsum_pre_sum_exp;
            fmsum_exp_small  = fval3.exp;
            fmsum_mant_large = fmsum_pre_sum_mant;
            fmsum_mant_small = {1'b1, fval3.mant, 24'b0};
        end
        else begin
            fmsum_exp_large  = fval3.exp;
            fmsum_exp_small  = fmsum_pre_sum_exp;
            fmsum_mant_large = {1'b1, fval3.mant, 24'b0};
            fmsum_mant_small = fmsum_pre_sum_mant;
        end
    end
    
    // 2. 对阶右移
    wire [7:0] fmsum_exp_diff = fmsum_exp_large - fmsum_exp_small;

    logic [47:0] fmsum_mant_small_shifted;
    logic [22:0] fmsum_collect_S_shift;
    assign {fmsum_mant_small_shifted, fmsum_collect_S_shift} = {fmsum_mant_small, 23'b0} >> fmsum_exp_diff;
    
    wire fmsum_S_shift = (fmsum_exp_diff >= 24) ? 1 : |fmsum_collect_S_shift;

    // 3. 尾数加减
    logic [20:0] fmsum_cllect_S_sum;
    logic        fmsum_sel_add_real;
    logic        fmsum_sum_carry_calc, fmsum_sum_sign_calc;
    logic [26:0] fmsum_sum_mant_res;

    always_comb begin
        fmsum_sel_add_real = ((ipkg.sel_fmadd_s | ipkg.sel_fnmadd_s) & (fmsum_pre_sum_sign == fval3.sign)) | ((ipkg.sel_fmsub_s | ipkg.sel_fnmsub_s) & (fmsum_pre_sum_sign != fval3.sign));

        if (fmsum_sel_add_real) begin
            {fmsum_sum_carry_calc, fmsum_sum_mant_res, fmsum_cllect_S_sum} = fmsum_mant_large + fmsum_mant_small_shifted;
            fmsum_sum_sign_calc = 1'b0;
        end
        else begin
            fmsum_sum_carry_calc = 1'b0;
            if (fmsum_mant_large >= fmsum_mant_small_shifted) begin
                {fmsum_sum_mant_res, fmsum_cllect_S_sum} = fmsum_mant_large - fmsum_mant_small_shifted;
                fmsum_sum_sign_calc = 1'b0;
            end
            else begin
                {fmsum_sum_mant_res, fmsum_cllect_S_sum} = fmsum_mant_small_shifted - fmsum_mant_large;
                fmsum_sum_sign_calc = 1'b1;
            end
        end
    end

    wire fmsum_S_sum = |fmsum_cllect_S_sum;

    wire fmsum_sum_pre = (fmsum_fvalmul_exp_gt_fval3) ? 
                            fmsum_pre_sum_sign ^ (fmsum_sum_sign_calc) : 
                            fval3.sign ^ (fmsum_sum_sign_calc ^ (ipkg.sel_fmsub_s | ipkg.sel_fnmsub_s));

    wire fmsum_sign_res = (ipkg.sel_fnmadd_s | ipkg.sel_fnmsub_s) ? ~fmsum_sum_pre : fmsum_sum_pre;

    // 4. 前导零检测
    logic [4:0] fmsum_lz_cnt;
    assign fmsum_lz_cnt = lz27(fmsum_sum_mant_res);

    // 5. 溢出 & 规格化
    logic [26:0] fmsum_mant_norm;
    logic [7:0]  fmsum_exp_norm;
    logic        fmsum_norm_S;
    logic        fmsum_norm_overflow, fmsum_norm_underflow;
    
    wire fmsum_mant_zero = ~(|fmsum_sum_mant_res) & ~fmsum_sum_carry_calc;
    always_comb begin
        fmsum_norm_S          = 0;
        fmsum_norm_overflow   = 0;
        fmsum_norm_underflow  = 0;

        if (fmsum_mant_zero) begin
            fmsum_exp_norm  = 0;
            fmsum_mant_norm = 0;
        end
        else if (fmsum_sum_carry_calc) begin   // 进位
            if (fmsum_exp_large == 254) begin  // Overflow
                fmsum_norm_overflow = 1;
                fmsum_exp_norm      = 255;
                fmsum_mant_norm     = 0;
            end
            else begin
                fmsum_norm_S      = fmsum_sum_mant_res[0];
                fmsum_exp_norm    = fmsum_exp_large + 1;
                fmsum_mant_norm   = {1'b1, fmsum_sum_mant_res[26:1]};
            end
        end 
        else if (~fmsum_sum_mant_res[26]) begin         // 规格化左移
            if (fmsum_exp_large <= fmsum_lz_cnt) begin  // Underflow
                fmsum_norm_underflow = 1;
                fmsum_exp_norm       = 0;
                fmsum_mant_norm      = 0;
            end
            else begin
                fmsum_exp_norm  = fmsum_exp_large - fmsum_lz_cnt;
                fmsum_mant_norm = fmsum_sum_mant_res << fmsum_lz_cnt;
            end
        end 
        else begin  // 已规格化
            fmsum_exp_norm  = fmsum_exp_large;
            fmsum_mant_norm = fmsum_sum_mant_res;
        end
    end

    // 6. 舍入
    wire  fmsum_lsb = fmsum_mant_norm[3];
    wire  fmsum_G   = fmsum_mant_norm[2];
    wire  fmsum_R   = fmsum_mant_norm[1];
    wire  fmsum_S   = fmsum_S_shift | fmsum_S_sum | fmsum_norm_S | fmsum_mant_norm[0];
    logic fmsum_roundup;
    logic fmsum_roundup_inexact;
    assign fmsum_roundup_inexact = ipkg.is_fM & (fmsum_G | fmsum_R | fmsum_S);

    // 根据 GRS 计算进位
    always_comb begin
        case (rm)
            RNE     : fmsum_roundup = fmsum_G & (fmsum_R | fmsum_S | fmsum_lsb);
            RTZ     : fmsum_roundup = 0;
            RDN     : fmsum_roundup = ~(fmsum_G | fmsum_R | fmsum_S) & fmsum_sign_res;
            RUP     : fmsum_roundup = ~(fmsum_G | fmsum_R | fmsum_S) & ~fmsum_sign_res;
            RMM     : fmsum_roundup = fmsum_G;
            default : fmsum_roundup = 0;
        endcase
    end
    
    // 舍入后进位处理
    logic [7:0]  fmsum_exp_roundup;
    logic [23:0] fmsum_mant_roundup1, fmsum_mant_roundup2;
    logic        fmsum_mant_roundup_carry;
    logic        fmsum_roundup_overflow;
    always_comb begin
        {fmsum_mant_roundup_carry, fmsum_mant_roundup1} = fmsum_mant_norm[26:3] + fmsum_roundup;
        fmsum_roundup_overflow = 0;

        if (fmsum_mant_roundup_carry) begin
            if (fmsum_exp_norm == 254) begin
                fmsum_roundup_overflow = 1;
                fmsum_exp_roundup      = 0;
                fmsum_mant_roundup2    = 0;
            end
            else begin
                fmsum_exp_roundup   = fmsum_exp_norm + 1;
                fmsum_mant_roundup2 = {1'b1, fmsum_mant_roundup1[23:1]};
            end
        end
        else begin
            fmsum_exp_roundup   = fmsum_exp_norm;
            fmsum_mant_roundup2 = fmsum_mant_roundup1;
        end
    end
    
    
    // 7. 特殊值处理
    fval_t fmsum_final;
    assign fmsum_final.sign = fmsum_sign_res;
    assign fmsum_final.exp  = fmsum_exp_roundup;
    assign fmsum_final.mant = fmsum_mant_roundup2[22:0];

    wire [31:0] fmsum_res = (fmsum_sub_inf) ? NORMAL_QNAN : fmsum_final;

    wire fmsum_NX = ipkg.is_fM & fmsum_roundup_inexact;



    // fflags 写入
    fflags_t flags;
    assign flags.NV = sum_fval_nv | sum_sub_inf | fcmp_fval_nv | fmaxmin_fval_nv | fcvt_NV | fcvt_w_get_int_max | fdiv_NV | fsqrt_NV | fmul_NV;
    assign flags.DZ = fdiv_DZ;
    assign flags.OF = sum_OF | fdiv_OF | fsqrt_OF;
    assign flags.UF = sum_UF | fdiv_UF | fsqrt_UF;
    assign flags.NX = sum_roundup_inexact | fcvt_roundup_inexact | fcvt_w_roundup_inexact | fmul_NX | fdiv_NX | fsqrt_NX | fmsum_NX;

    assign fflags = (ipkg.is_FP | ipkg.is_fM) ? flags : 0;

    always_comb begin
        unique case (1'b1)
            ipkg.sel_fclass_s  : result = fclass_res;
            ipkg.sel_fadd_s    : result = sum_res;
            ipkg.sel_fsub_s    : result = sum_res;
            ipkg.sel_fmv_w_x   : result = value1;
            ipkg.sel_fmv_x_w   : result = value1;
            ipkg.sel_feq_s     : result = {31'b0, feq_s_res};
            ipkg.sel_fle_s     : result = {31'b0, fle_s_res};
            ipkg.sel_flt_s     : result = {31'b0, flt_s_res};
            ipkg.sel_fmax_s    : result = fmax_s_res;
            ipkg.sel_fmin_s    : result = fmin_s_res;
            ipkg.sel_fsgnj_s   : result = fsgnj_s_res;
            ipkg.sel_fsgnjn_s  : result = fsgnjn_s_res;
            ipkg.sel_fsgnjx_s  : result = fsgnjx_s_res;
            ipkg.sel_fcvt_s_w  : result = fcvt_s_res;
            ipkg.sel_fcvt_s_wu : result = fcvt_s_res;
            ipkg.sel_fcvt_w_s  : result = fcvt_w_res;
            ipkg.sel_fcvt_wu_s : result = fcvt_w_res;
            ipkg.sel_fmul_s    : result = fmul_s_res;
            ipkg.sel_fdiv_s    : result = fdiv_s_res;
            ipkg.sel_fsqrt_s   : result = fsqrt_s_res;
            ipkg.sel_fmadd_s   : result = fmsum_res;
            ipkg.sel_fmsub_s   : result = fmsum_res;
            ipkg.sel_fnmadd_s  : result = fmsum_res;
            ipkg.sel_fnmsub_s  : result = fmsum_res;
            default            : result = 32'b0;
        endcase
    end
    

    assign ctrl = fdiv_ctrl | fsqrt_ctrl;
endmodule