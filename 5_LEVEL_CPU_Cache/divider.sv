// 不恢复余数除法器 (Non-restoring Division)
// 支持 DIV, DIVU, REM, REMU 四条 RISC-V 指令
// 32 位数据宽度，32 个执行周期 + 校正周期

module divider(
    input              clk,
    input              rst,
    // 输入
    input              valid_i,          // 启动除法
    input      [31:0]  dividend_i,       // 被除数
    input      [31:0]  divisor_i,        // 除数
    input              is_div_i,         // DIV  有符号除法
    input              is_divu_i,        // DIVU 无符号除法
    input              is_rem_i,         // REM  有符号取余
    input              is_remu_i,        // REMU 无符号取余
    input              flush_i,          // 流水线冲刷
    // 输出
    output             valid_o,          // 结果有效，解除暂停
    output     [31:0]  result_o          // 商或余数
);
    // 寄存输入
    wire InProgress = ~state_is_idle;
    logic [31:0] dividend_r, divisor_r;
    always_ff @(posedge clk) begin
        if (!rst) begin
            dividend_r  <= 32'b0;
            divisor_r   <= 32'b0;
        end
        else if (flush_i) begin
            dividend_r  <= 32'b0;
            divisor_r   <= 32'b0;
        end
        else if (InProgress) begin
            // 输入寄存
        end
        else if (valid_i) begin
            dividend_r  <= dividend_i;
            divisor_r   <= divisor_i;
        end
    end

    wire [31:0] dividend_true = (InProgress) ? dividend_r : dividend_i;
    wire [31:0] divisor_true = (InProgress) ? divisor_r : divisor_i;

    // =========================================================================
    //  指令译码
    // =========================================================================
    wire is_op_div = is_div_i | is_divu_i | is_rem_i | is_remu_i;
    wire is_signed = is_div_i | is_rem_i;
    wire want_quot = is_div_i | is_divu_i;   // 输出商
    wire want_remd = is_rem_i | is_remu_i;   // 输出余数

    // =========================================================================
    //  特殊值检测
    // =========================================================================
    wire div_by_0 = ~(|divisor_true);                                                    // 除数为 0
    wire div_ovf  = is_signed & divisor_true[31] & (&divisor_true[30:0])                    // 除数 = -1
                  & dividend_true[31] & (~(|dividend_true[30:0]));                           // 被除数 = MIN_INT
    wire special_case = is_op_div & (div_by_0 | div_ovf);

    // 特殊值结果
    wire [31:0] div_by_0_quot = 32'hFFFFFFFF;
    wire [31:0] div_by_0_remd = dividend_true;
    wire [31:0] div_ovf_quot  = 32'h80000000;
    wire [31:0] div_ovf_remd  = 32'h0;
    wire [31:0] special_result = div_by_0 ? (want_quot ? div_by_0_quot : div_by_0_remd)
                                          : (want_quot ? div_ovf_quot  : div_ovf_remd);

    // =========================================================================
    //  状态机
    // =========================================================================
    localparam S_IDLE      = 3'd0;
    localparam S_EXEC      = 3'd1;
    localparam S_CHECK     = 3'd2;
    localparam S_QUOT_CORR = 3'd3;
    localparam S_REMD_CORR = 3'd4;

    reg [2:0] state_r;

    wire state_is_idle      = (state_r == S_IDLE);
    wire state_is_exec      = (state_r == S_EXEC);
    wire state_is_check     = (state_r == S_CHECK);
    wire state_is_quot_corr = (state_r == S_QUOT_CORR);
    wire state_is_remd_corr = (state_r == S_REMD_CORR);

    // =========================================================================
    //  执行计数器 (32 周期)
    // =========================================================================
    localparam CNT_MAX = 6'd32;

    reg [5:0] exec_cnt_r;
    wire exec_last_cycle = (exec_cnt_r == CNT_MAX);

    // =========================================================================
    //  操作数符号扩展
    // =========================================================================
    wire div_rs1_sign = is_signed & dividend_true[31];
    wire div_rs2_sign = is_signed & divisor_true[31];

    wire [65:0] dividend_ext = {{33{div_rs1_sign}}, div_rs1_sign, dividend_true};   // 66 bit
    wire [33:0] divisor_ext  = {div_rs2_sign, div_rs2_sign, divisor_true};          // 34 bit

    // =========================================================================
    //  不恢复余数除法核心
    // =========================================================================
    // 部分余数 (33 bit) 和部分商 (33 bit) 寄存器
    reg [32:0] part_remd_r;
    reg [32:0] part_quot_r;
    reg        part_remd_sft1_r;    // 余数高位暂存 (adder MSB)

    // --- 第 0 周期: 初始商位 ---
    wire quot_0cycl = ~(dividend_ext[65] ^ divisor_ext[33]);   // 同号则 1，异号则 0
    wire [66:0] dividend_lsft1 = {dividend_ext[65:0], quot_0cycl};

    // --- 上一轮商位 ---
    wire prev_quot = state_is_idle ? quot_0cycl : part_quot_r[0];

    // --- 内部加/减法器 (34 bit) ---
    wire [33:0] alu_op1 = state_is_idle ? dividend_lsft1[66:33]
                                        : {part_remd_sft1_r, part_remd_r[32:0]};
    wire [33:0] alu_op2 = divisor_ext;
    wire        alu_sub = prev_quot;           // prev=1 → sub, prev=0 → add
    wire [33:0] alu_res = alu_sub ? (alu_op1 - alu_op2) : (alu_op1 + alu_op2);

    // --- 新商位 ---
    wire current_quot = ~(alu_res[33] ^ divisor_ext[33]);

    // --- 拼接部分余数 (高 34 bit = 余数，低 33 bit = 商) ---
    wire [66:0] part_remd_combined;
    assign part_remd_combined[66:33] = alu_res;
    assign part_remd_combined[32: 0] = state_is_idle ? dividend_lsft1[32:0] : part_quot_r[32:0];

    wire [67:0] part_remd_lsft1 = {part_remd_combined[66:0], current_quot};

    // =========================================================================
    //  余数校正判断
    // =========================================================================
    wire remd_is_0        = ~(|part_remd_r);
    wire remd_is_neg_divs = ~(|(part_remd_r - divisor_ext[32:0]));
    wire remd_is_divs     = (part_remd_r == divisor_ext[32:0]);

    wire div_need_corrct = is_op_div & (
                               ((part_remd_r[32] ^ dividend_ext[65]) & (~remd_is_0))
                             | remd_is_neg_divs
                             | remd_is_divs
                           );

    wire remd_inc_quot_dec = (part_remd_r[32] ^ divisor_ext[33]);

    // 校正用加法器
    wire [33:0] quot_corr_res = remd_inc_quot_dec ? ({part_quot_r[32], part_quot_r} - 34'd1)
                                                  : ({part_quot_r[32], part_quot_r} + 34'd1);

    wire [33:0] remd_corr_res = remd_inc_quot_dec ? ({part_remd_r[32], part_remd_r} + divisor_ext)
                                                  : ({part_remd_r[32], part_remd_r} - divisor_ext);

    // =========================================================================
    //  选择输出
    // =========================================================================
    wire [32:0] div_quot = state_is_check ? part_quot_r :
                           (state_is_quot_corr | state_is_remd_corr) ? quot_corr_res[32:0] :
                           {part_remd_combined[31:0], 1'b1};

    wire [32:0] div_remd = state_is_check ? part_remd_r :
                           state_is_remd_corr ? remd_corr_res[32:0] :
                           state_is_quot_corr ? part_remd_r :
                           part_remd_combined[65:33];

    wire [31:0] div_result = want_quot ? div_quot[31:0] : div_remd[31:0];

    // =========================================================================
    //  输出有效条件
    // =========================================================================
    wire normal_done = (state_is_exec & exec_last_cycle & ~is_op_div)       // 非除法（不走这里，但保留安全）
                     | (state_is_check & ~div_need_corrct)
                     | state_is_remd_corr;

    assign valid_o = (state_is_idle & valid_i & special_case)               // 特殊值直接出
                   | (state_is_idle & valid_i & ~special_case & ~is_op_div) // 安全保护
                   | normal_done;
    assign result_o = special_case ? special_result : div_result;

    // =========================================================================
    //  状态机转移
    // =========================================================================
    wire start = state_is_idle & valid_i & is_op_div & ~flush_i & ~special_case;

    always_ff @(posedge clk) begin
        if (~rst | flush_i) begin
            state_r <= S_IDLE;
        end else begin
            case (state_r)
                S_IDLE: begin
                    if (start)
                        state_r <= S_EXEC;
                end
                S_EXEC: begin
                    if (exec_last_cycle)
                        state_r <= is_op_div ? S_CHECK : S_IDLE;
                end
                S_CHECK: begin
                    if (div_need_corrct)
                        state_r <= S_QUOT_CORR;
                    else
                        state_r <= S_IDLE;
                end
                S_QUOT_CORR: begin
                    state_r <= S_REMD_CORR;
                end
                S_REMD_CORR: begin
                    state_r <= S_IDLE;
                end
                default: begin
                    state_r <= S_IDLE;
                end
            endcase
        end
    end

    // =========================================================================
    //  计数器
    // =========================================================================
    always_ff @(posedge clk) begin
        if (~rst | flush_i) begin
            exec_cnt_r <= 6'd0;
        end else if (start) begin
            exec_cnt_r <= 6'd1;
        end else if (state_is_exec & ~exec_last_cycle) begin
            exec_cnt_r <= exec_cnt_r + 1'b1;
        end
    end

    // =========================================================================
    //  部分余数 & 部分商 寄存器
    // =========================================================================
    wire update_remd = start
                     | (state_is_exec & ~exec_last_cycle)
                     | (state_is_exec & exec_last_cycle & is_op_div)
                     | state_is_remd_corr;

    wire update_quot = start
                     | (state_is_exec & ~exec_last_cycle)
                     | (state_is_exec & exec_last_cycle & is_op_div)
                     | state_is_quot_corr;

    wire [32:0] remd_nxt = state_is_remd_corr ? remd_corr_res[32:0] :
                           (state_is_exec & exec_last_cycle) ? div_remd :
                           part_remd_lsft1[65:33];

    wire [32:0] quot_nxt = state_is_quot_corr ? quot_corr_res[32:0] :
                           (state_is_exec & exec_last_cycle) ? div_quot :
                           part_remd_lsft1[32:0];

    always_ff @(posedge clk) begin
        if (~rst | flush_i) begin
            part_remd_r     <= 33'd0;
            part_remd_sft1_r <= 1'b0;
        end else if (update_remd) begin
            part_remd_r     <= remd_nxt;
            part_remd_sft1_r <= alu_res[32];   // 保存加法器 MSB 供下轮使用
        end
    end

    always_ff @(posedge clk) begin
        if (~rst | flush_i) begin
            part_quot_r <= 33'd0;
        end else if (update_quot) begin
            part_quot_r <= quot_nxt;
        end
    end

endmodule
