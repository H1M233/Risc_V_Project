module mul(
    input              clk,
    input              rst,
    // 输入
    input      [31:0]  mul_1_i,          // 被乘数 (rs1)
    input      [31:0]  mul_2_i,          // 乘数   (rs2)
    input              is_mul_i,         // MUL    有符号×有符号, 低32位
    input              is_mulh_i,        // MULH   有符号×有符号, 高32位
    input              is_mulhu_i,       // MULHU  无符号×无符号, 高32位
    input              is_mulhsu_i,      // MULHSU 有符号×无符号, 高32位
    input              flush_i,          // 流水线冲刷
    // 输出
    output reg         valid_o,          // 结果有效
    output reg [31:0]  mul_result_o          // 乘法结果
);

    wire is_mul_op = is_mul_i | is_mulh_i | is_mulhsu_i | is_mulhu_i;
    // MULH: signed × signed
    (* use_dsp = "yes" *) wire [63:0] product_ss = $signed(mul_1_i) * $signed(mul_2_i);
    // MULHU: unsigned × unsigned
    (* use_dsp = "yes" *) wire [63:0] product_uu = mul_1_i * mul_2_i;
    // MULHSU: signed × unsigned
    (* use_dsp = "yes" *) wire [63:0] product_su = $signed(mul_1_i) * $signed({1'b0, mul_2_i});

    reg [31:0] mul_result;
    always @(*) begin
        (* parallel_case *)
        case (1'b1)
            is_mul_i    : mul_result_o = product_ss[31:0];    // 低32位
            is_mulh_i   : mul_result_o = product_ss[63:32];   // 高32位 (有符号×有符号)
            is_mulhsu_i : mul_result_o = product_su[63:32];   // 高32位 (有符号×无符号)
            is_mulhu_i  : mul_result_o = product_uu[63:32];   // 高32位 (无符号×无符号)
            default     : mul_result_o = 32'b0;
        endcase
    end

    // 计时器暂停三个周期算dsp
    localparam CNT_MAX = 3;
    reg [1:0] mul_cnt;

    always @(posedge clk) begin
        if (!rst || flush_i) begin
            mul_cnt <= 32'b0;
            valid_o <= 1'b0;
        end
        else if (is_mul_op) begin
            if(mul_cnt == CNT_MAX - 1) begin
                mul_cnt <= 32'b0;
                valid_o <= 1'b1;
            end
            else begin
                mul_cnt <= mul_cnt + 1;
                valid_o <= valid_o; // 保持之前的valid状态，直到乘法结果准备好
            end
        end
    end
    
endmodule
