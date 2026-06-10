module mul(
    input              clk,
    input              rst,
    
    // 输入
    input      [31:0]  mul_1_i,         // 被乘数 (rs1)
    input      [31:0]  mul_2_i,         // 乘数   (rs2)
    input              is_mul_i,        // MUL    有符号×有符号, 低32位
    input              is_mulh_i,       // MULH   有符号×有符号, 高32位
    input              is_mulhu_i,      // MULHU  无符号×无符号, 高32位
    input              is_mulhsu_i,     // MULHSU 有符号×无符号, 高32位
    input              flush_i,         // 流水线冲刷

    // 输出
    output logic        finished_o,     // 结果有效
    output logic [31:0] mul_result_o    // 乘法结果
);
    typedef enum {IDLE, WAIT, RET} state_t;
    state_t mul_state;

    wire is_mul_op = is_mul_i | is_mulh_i | is_mulhsu_i | is_mulhu_i;

    // 输入寄存器
    logic [31:0] sent_value1, sent_value2;
    always_ff @(posedge clk) begin
        if (!rst) begin
            mul_state   <= IDLE;
        end
        else begin
            case (mul_state)
                IDLE: begin
                    if (is_mul_op && !flush_i) begin
                        mul_state   <= WAIT;
                        sent_value1 <= mul_1_i;
                        sent_value2 <= mul_2_i;
                    end
                    else begin
                        sent_value1 <= 32'b0;
                        sent_value2 <= 32'b0;
                    end
                end
                
                WAIT    : mul_state <= RET;
                RET     : mul_state <= IDLE;
                default : mul_state <= IDLE;
            endcase
        end
    end
    
    assign finished_o = (mul_state == RET);
    
    // 输出寄存器
    (* use_dsp = "yes" *) 
    logic [63:0] dsp_result_ss, dsp_result_uu, dsp_result_su;
    always_ff @(posedge clk) begin: dsp_access
        // MULH: signed × signed
        dsp_result_ss   <= $signed(sent_value1) * $signed(sent_value2);

        // MULHU: unsigned × unsigned
        dsp_result_uu   <= sent_value1 * sent_value2;

        // MULHSU: signed × unsigned
        dsp_result_su   <= $signed(sent_value1) * $signed({1'b0, sent_value2});
    end

    always_comb begin
        unique case (1'b1)
            is_mul_i    : mul_result_o = dsp_result_ss[31:0];    // 低32位
            is_mulh_i   : mul_result_o = dsp_result_ss[63:32];   // 高32位 (有符号×有符号)
            is_mulhsu_i : mul_result_o = dsp_result_su[63:32];   // 高32位 (有符号×无符号)
            is_mulhu_i  : mul_result_o = dsp_result_uu[63:32];   // 高32位 (无符号×无符号)
            default     : mul_result_o = 32'b0;
        endcase
    end
endmodule
