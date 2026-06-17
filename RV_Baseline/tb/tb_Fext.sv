`include "alu_def.svh"
module tb_Fext;
    logic clk;
    initial begin
        clk = 1'b0;
    end
    always #10 clk = ~clk;

    decode_t ipkg;
    rm_t rm;
    id_ex_data_t dpkg;
    assign dpkg.imm[2:0] = rm;
    logic [31:0] value1, value2;

    function automatic logic [31:0] gen_fval(input real value);
        return $shortrealtobits(value);
    endfunction

    initial begin
        ipkg = 0;
        ipkg.is_FP = 1'b1;
        ipkg.sel_fmul_s = 1'b1;

        value1 = gen_fval(1.1);
        value2 = gen_fval(2);

        # 100
        value1 = gen_fval(114514);
        value2 = gen_fval(0);

        # 100
        value2 = gen_fval(0.5);

        # 100
        value1 = gen_fval(0.114514);

    end


    
    alu_Fext alu_Fext_instance (
        .clk(clk),
        .rst(1'b1),
        .flush(1'b0),

        .value1(value1),
        .value2(value2),
        .dpkg(dpkg),
        .ipkg(ipkg),
        .fflags(),
        .ctrl(),
        .result()
    );
endmodule