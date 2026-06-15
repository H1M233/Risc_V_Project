`include "alu_def.svh"
module tb_Fext;
    logic clk;
    initial begin
        clk = 1'b0;
    end
    always #10 clk = ~clk;

    decode_t ipkg;
    rm_t rm;
    logic [31:0] value1, value2;

    function automatic logic [31:0] gen_fval(input real value);
        return $shortrealtobits(value);
    endfunction

    initial begin
        ipkg = 0;
        ipkg.sel_fadd_s = 1'b1;
        // ipkg.sel_fsub_s = 1;

        rm = RNE;

        value1 = gen_fval(1.0);
        value2 = gen_fval(0.0001);

        // # 100
        // value1 = gen_fval(1.0);
        // value2 = gen_fval(1.2);

        // # 100
        // value1 = gen_fval(1.2);
        // value2 = gen_fval(1.0);

        // # 100
        // value1 = gen_fval(3.1415926);
        // value2 = gen_fval(3.1415926);

        # 100
        rm = RTZ;

        # 100
        rm = RDN;

        # 100
        rm = RUP;

        # 100
        rm = RMM;

        // # 100
        // value1 = gen_fval(1.0);
        // value2 = gen_fval(-2.0);

        // # 100
        // value1 = gen_fval(-1.0);
        // value2 = gen_fval(2.0);

        // # 100
        // value1 = gen_fval(-1.0);
        // value2 = gen_fval(-2.0);

        // # 100
        // value1 = gen_fval(100.0);
        // value2 = gen_fval(-2.0);

        // # 100
        // value1 = gen_fval(-100.0);
        // value2 = gen_fval(2.0);

        // # 100
        // value1 = gen_fval(-100.0);
        // value2 = gen_fval(-2.0);
    end
    
    alu_Fext alu_Fext_instance (
        .clk(clk),
        .rst(1'b1),
        .flush(1'b0),
        .funct3(rm),
        .value1(value1),
        .value2(value2),
        .ipkg(ipkg),
        .flags(),
        .ctrl(),
        .result()
    );
endmodule