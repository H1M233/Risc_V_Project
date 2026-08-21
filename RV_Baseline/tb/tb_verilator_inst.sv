`include "tb_def.svh"

module tb_verilator_inst(
    input  logic    clk_50MHz,
    input  logic    rst,

    output logic    x3,
    output logic    x26,
    output logic    x27
);
    top uut (
        .w_clk_50Mhz(clk_50MHz), .cpu_clk (clk_50MHz), .w_clk_rst(rst), 
        .i_uart_rx(), .o_uart_tx(),
        .i_key(), .o_seg_digit(), .o_seg_sel(), .o_led()
    );
    initial begin
            $readmemh("./mem_init/inst_test.txt", `IROM_PATH);
            $readmemh("./mem_init/inst_test.txt", `DRAM_PATH);
        end

    `define VERILATOR_INST_TEST
    `ifdef PROJECT_RV_SUPERSCALAR
    `elsif PROJECT_RV_BASELINE
        assign x3  = `CPU_PATH.RF.RF_p1[3];   // 进行的test序号
        assign x26 = `CPU_PATH.RF.RF_p1[26];  // 测试结束信号
        assign x27 = `CPU_PATH.RF.RF_p1[27];  // 0: fail, 1: pass
    `endif

    logic [31:0] cycle_count;
    always_ff @(posedge clk_50MHz) begin
        if (x26 == 1'b1) begin
            if (cycle_count >= 32'd20)  // 等待 20 个时钟周期
                $finish();
            else
                cycle_count <= cycle_count + 1'd1;
        end
    end
endmodule
