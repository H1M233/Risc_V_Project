`include "../def/alu_def.svh"
module alu_Mext(
    input  logic        clk,
    input  logic        rst,
    input  logic        flush,

    input  logic [31:0] value1,
    input  logic [31:0] value2,
    input  decode_t     ipkg,

    output logic        ctrl,
    output logic [31:0] result
);
    logic [31:0] mul_res;
    logic using_multiplier, multiplier_finished, multiplier_ctrl;
    assign using_multiplier = (ipkg.sel_mul | ipkg.sel_mulh | ipkg.sel_mulhu | ipkg.sel_mulhsu);
    assign multiplier_ctrl = using_multiplier & !multiplier_finished;

    mul MULTIPLIER(
        .clk          (clk),
        .rst          (rst),
        .mul_1_i      (value1),
        .mul_2_i      (value2),
        .is_mul_i     (ipkg.sel_mul),
        .is_mulh_i    (ipkg.sel_mulh),
        .is_mulhu_i   (ipkg.sel_mulhu),
        .is_mulhsu_i  (ipkg.sel_mulhsu),
        .flush_i      (flush),
        .finished_o   (multiplier_finished), 
        .mul_result_o (mul_res)
    );

    logic [31:0] div_res;
    logic using_divider, divider_finished, divider_ctrl;
    assign using_divider = (ipkg.sel_div | ipkg.sel_divu | ipkg.sel_rem | ipkg.sel_remu);
    assign divider_ctrl = using_divider & !divider_finished;
    
    divider DIVIDER(
        .clk          (clk),
        .rst          (rst),
        .dividend_i   (value1),
        .divisor_i    (value2),
        .valid_i      (using_divider),
        .is_div_i     (ipkg.sel_div),
        .is_divu_i    (ipkg.sel_divu),
        .is_rem_i     (ipkg.sel_rem),
        .is_remu_i    (ipkg.sel_remu),
        .flush_i      (flush),
        .valid_o      (divider_finished),
        .result_o     (div_res)
    );

    assign ctrl = (multiplier_ctrl | divider_ctrl);
    always_comb begin
        unique case (1'b1)
            using_multiplier : result = mul_res;
            using_divider    : result = div_res;
            default          : result = 32'b0;
        endcase
    end
endmodule