module divider_tb;

    logic clk;
    initial begin
        clk = 1'b0;
    end
    
    always #10 clk <= ~clk;

    divider DIVIDER(
        .clk          (clk),
        .rst          (1'b1),
        .dividend_i   (32'h4),
        .divisor_i    (32'h4),
        .valid_i      (1'b1),
        .is_div_i     (1),
        .is_divu_i    (0),
        .is_rem_i     (0),
        .is_remu_i    (0),
        .flush_i      (1'b0),
        .valid_o      (),
        .result_o     ()
    );

endmodule