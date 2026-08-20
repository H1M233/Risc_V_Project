module divider(
    input  logic        clk,
    input  logic        rst,

    input  logic        valid_i,          // 启动除法
    input  logic [31:0] dividend_i,       // 被除数
    input  logic [31:0] divisor_i,        // 除数
    input  logic        is_div_i,         // DIV  有符号除法
    input  logic        is_divu_i,        // DIVU 无符号除法
    input  logic        is_rem_i,         // REM  有符号取余
    input  logic        is_remu_i,        // REMU 无符号取余
    input  logic        flush_i,

    output logic        valid_o,          // 结果有效
    output logic [31:0] result_o
);
    // =========================================================================
    //  指令译码
    // =========================================================================
    wire is_signed = is_div_i | is_rem_i;
    wire want_quot = is_div_i | is_divu_i;   // 输出商
    wire want_remd = is_rem_i | is_remu_i;   // 输出余数

    // =========================================================================
    //  输入寄存
    // =========================================================================
    logic        valid_r;
    logic [65:0] dividend_ext;
    logic [33:0] divisor_ext;
    logic        div_by_0, div_ovf;    // 除 0 & 溢出判断
    always_ff @(posedge clk) begin
        if (rst) begin
            valid_r      <= 1'b0;

            dividend_ext <= 66'b0;
            divisor_ext  <= 34'b0;

            div_by_0     <= 1'b0;
            div_ovf      <= 1'b0;
        end
        else if (flush_i | valid_o) begin
            valid_r      <= 1'b0;

            dividend_ext <= 66'b0;
            divisor_ext  <= 34'b0;

            div_by_0     <= 1'b0;
            div_ovf      <= 1'b0;
        end
        else if (valid_i & ~valid_r) begin
            valid_r      <= 1'b1;

            dividend_ext <= {{34{is_signed & dividend_i[31]}}, dividend_i};
            divisor_ext  <= {{2{is_signed & divisor_i[31]}}, divisor_i};

            div_by_0     <= (divisor_i == 32'b0);
            div_ovf      <= is_signed && ((divisor_i == 32'hFFFFFFFF) || (divisor_i == 32'h1)) && (dividend_i == 32'h80000000);
        end
    end

    // =========================================================================
    //  特殊值处理
    // =========================================================================
    wire special_case = div_by_0 | div_ovf;

    // 特殊值结果
    wire [31:0] div_by_0_quot = 32'hFFFFFFFF;
    wire [31:0] div_by_0_remd = dividend_ext[31:0];
    wire [31:0] div_ovf_quot  = 32'h80000000;
    wire [31:0] div_ovf_remd  = 32'h0;
    wire [31:0] special_result = (div_by_0) ? ((want_quot) ? div_by_0_quot : div_by_0_remd) :
                                              ((want_quot) ? div_ovf_quot  : div_ovf_remd);

    // =========================================================================
    //  状态机
    // =========================================================================
    typedef enum {IDLE, EXEC, CHECK, QUOT_CORR, REMD_CORR} state_t;
    state_t divider_state;

    wire state_is_idle      = (divider_state == IDLE);
    wire state_is_exec      = (divider_state == EXEC);
    wire state_is_check     = (divider_state == CHECK);
    wire state_is_quot_corr = (divider_state == QUOT_CORR);
    wire state_is_remd_corr = (divider_state == REMD_CORR);

    // =========================================================================
    //  执行计数器 (32 周期)
    // =========================================================================
    localparam CNT_MAX = 6'd32;

    reg [5:0] exec_cnt_r;
    wire exec_last_cycle = (exec_cnt_r == CNT_MAX);

    // =========================================================================
    //  不恢复余数除法核心
    // =========================================================================
    // 部分余数 (33 bit) 和部分商 (33 bit) 寄存器
    reg [32:0] part_remd_r;
    reg [32:0] part_quot_r;
    reg        part_remd_sft1_r;    // 余数高位暂存 (adder MSB)

    // --- 第 0 周期: 初始商位 ---
    wire quot_0cycl = ~(dividend_ext[65] ^ divisor_ext[33]);   // 同号则 1，异号则 0
    wire [66:0] dividend_lsft1 = {dividend_ext, quot_0cycl};

    // --- 上一轮商位 ---
    wire prev_quot = (state_is_idle) ? quot_0cycl : part_quot_r[0];

    // --- 内部加/减法器 (34 bit) ---
    wire [33:0] alu_op1 = (state_is_idle) ? dividend_lsft1[66:33] : 
                                            {part_remd_sft1_r, part_remd_r[32:0]};
    wire [33:0] alu_op2 = divisor_ext;
    wire        alu_sub = prev_quot;           // prev=1 → sub, prev=0 → add
    wire [33:0] alu_res = (alu_sub) ? (alu_op1 - alu_op2) : (alu_op1 + alu_op2);

    // --- 新商位 ---
    wire current_quot = ~(alu_res[33] ^ divisor_ext[33]);

    // --- 拼接部分余数 (高 34 bit = 余数，低 33 bit = 商) ---
    wire [66:0] part_remd_combined;
    assign part_remd_combined[66:33] = alu_res;
    assign part_remd_combined[32: 0] = (state_is_idle) ? dividend_lsft1[32:0] : part_quot_r[32:0];

    wire [67:0] part_remd_lsft1 = {part_remd_combined[66:0], current_quot};

    // =========================================================================
    //  余数校正判断
    // =========================================================================
    wire remd_is_0        = ~(|part_remd_r);
    wire remd_is_neg_divs = ~(|(part_remd_r - divisor_ext[32:0]));
    wire remd_is_divs     = (part_remd_r == divisor_ext[32:0]);

    wire div_need_corrct = ((part_remd_r[32] ^ dividend_ext[65]) & (~remd_is_0))
                         | remd_is_neg_divs
                         | remd_is_divs;

    wire remd_inc_quot_dec = (part_remd_r[32] ^ divisor_ext[33]);

    // 校正用加法器
    wire [33:0] quot_corr_res = (remd_inc_quot_dec) ? ({part_quot_r[32], part_quot_r} - 34'd1) :
                                                      ({part_quot_r[32], part_quot_r} + 34'd1);

    wire [33:0] remd_corr_res = (remd_inc_quot_dec) ? ({part_remd_r[32], part_remd_r} + divisor_ext) :
                                                      ({part_remd_r[32], part_remd_r} - divisor_ext);

    // =========================================================================
    //  选择输出
    // =========================================================================
    logic [32:0] div_quot, div_remd;
    always_comb begin
        unique case (1'b1)
            state_is_check     : div_quot = part_quot_r;
            state_is_remd_corr : div_quot = quot_corr_res[32:0];
            state_is_quot_corr : div_quot = quot_corr_res[32:0];
            default            : div_quot = {part_remd_combined[31:0], 1'b1};
        endcase

        unique case (1'b1)
            state_is_check     : div_remd = part_remd_r;
            state_is_remd_corr : div_remd = remd_corr_res[32:0];
            state_is_quot_corr : div_remd = part_remd_r;
            default            : div_remd = part_remd_combined[65:33];
        endcase
    end

    wire [31:0] div_result = (want_quot) ? div_quot[31:0] : div_remd[31:0];

    // =========================================================================
    //  输出有效条件
    // =========================================================================
    wire normal_done = (state_is_check & ~div_need_corrct)
                     | (state_is_quot_corr & want_quot)
                     | (state_is_remd_corr & want_remd);

    always_ff @(posedge clk) begin
        if (rst) begin
            valid_o     <= 1'b0;
            result_o    <= 32'b0;
        end
        else begin
            valid_o     <= (state_is_idle & valid_r & special_case) | normal_done;
            result_o    <= (special_case) ? special_result : div_result;
        end
    end

    // =========================================================================
    //  状态机转移
    // =========================================================================
    wire start = state_is_idle & valid_r & ~valid_o & ~special_case;

    always_ff @(posedge clk) begin
        if (rst) begin
            divider_state <= IDLE;
        end 
        else if (flush_i) begin
            divider_state <= IDLE;
        end
        else begin
            case (divider_state)
                IDLE: begin
                    if (start) begin
                        divider_state <= EXEC;
                    end
                end
                EXEC: begin
                    if (exec_last_cycle) begin
                        divider_state <= CHECK;
                    end
                end
                CHECK: begin
                    if (div_need_corrct) begin
                        divider_state <= QUOT_CORR;
                    end
                    else begin
                        divider_state <= IDLE;
                    end
                end
                QUOT_CORR: begin
                    divider_state <= REMD_CORR;
                end
                REMD_CORR: begin
                    divider_state <= IDLE;
                end
                default: begin
                    divider_state <= IDLE;
                end
            endcase
        end
    end

    // =========================================================================
    //  计数器
    // =========================================================================
    always_ff @(posedge clk) begin
        if (rst) begin
            exec_cnt_r <= 6'd0;
        end 
        else if (flush_i) begin
            exec_cnt_r <= 6'd0;
        end
        else if (start) begin
            exec_cnt_r <= 6'd1;
        end 
        else if (state_is_exec & ~exec_last_cycle) begin
            exec_cnt_r <= exec_cnt_r + 1'b1;
        end
    end

    // =========================================================================
    //  部分余数 & 部分商 寄存器
    // =========================================================================
    wire update_remd = start | state_is_exec | state_is_remd_corr;
    wire update_quot = start | state_is_exec | state_is_quot_corr;

    logic [32:0] remd_nxt, quot_nxt;
    always_comb begin
        unique case (1'b1)
            state_is_remd_corr              : remd_nxt = remd_corr_res[32:0];
            state_is_exec & exec_last_cycle : remd_nxt = div_remd;
            default                         : remd_nxt = part_remd_lsft1[65:33];
        endcase

        unique case (1'b1)
            state_is_quot_corr              : quot_nxt = quot_corr_res[32:0];
            state_is_exec & exec_last_cycle : quot_nxt = div_quot;
            default                         : quot_nxt = part_remd_lsft1[32:0];
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            part_remd_r      <= 33'd0;
            part_remd_sft1_r <= 1'b0;
        end 
        else if (update_remd) begin
            part_remd_r      <= remd_nxt;
            part_remd_sft1_r <= alu_res[32];   // 保存加法器 MSB 供下轮使用
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            part_quot_r <= 33'd0;
        end 
        else if (update_quot) begin
            part_quot_r <= quot_nxt;
        end
    end

endmodule
