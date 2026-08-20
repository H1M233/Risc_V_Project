`include "alu_def.svh"
module tb_Fext;
    logic clk, rst;
    initial begin
        clk = 1'b0;
        rst = 1'b0;

        # 40
        rst = 1'b1;
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
        dpkg = 0;

        ipkg.is_FM = 1'b1;
        ipkg.sel_fmadd_s = 1'b1;

        value1 = gen_fval(1.2);
        value2 = gen_fval(1.2);

        dpkg.rs3_rdata = 0;

        # 100
        dpkg.rs3_rdata = gen_fval(1.0);

    end
    
    alu_Fext alu_Fext_instance (
        .clk(clk),
        .rst(rst),
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