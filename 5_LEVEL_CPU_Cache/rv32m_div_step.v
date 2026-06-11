module rv32m_div_step #(
    parameter STEPS = 16
)(
    input  signed [33:0] remainder_i,
    input         [31:0] quotient_i,
    input         [31:0] divisor_i,
    output reg signed [33:0] remainder_o,
    output reg        [31:0] quotient_o
);
    integer i;
    wire signed [33:0] divisor_ext = {2'b00, divisor_i};

    always @(*) begin
        remainder_o = remainder_i;
        quotient_o  = quotient_i;

        for (i = 0; i < STEPS; i = i + 1) begin
            if (remainder_o[33]) begin
                remainder_o = {remainder_o[32:0], quotient_o[31]} + divisor_ext;
            end
            else begin
                remainder_o = {remainder_o[32:0], quotient_o[31]} - divisor_ext;
            end

            quotient_o = {quotient_o[30:0], ~remainder_o[33]};
        end
    end
endmodule
