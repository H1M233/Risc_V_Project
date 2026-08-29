`include "tb_def.svh"

module tb_verilator_MySystem(
    input  logic            clk_50MHz,
    input  logic            clk_cpu,
    input  logic            rst,

    output logic [31:0]     LED, SEG,
    output logic [1:0]      commit,
    output logic            pred_total, pred_miss, pred_total_b, pred_total_jr, pred_miss_b, pred_miss_jr,
    output logic [31:0]     pc0, pc1,
    output logic [31:0]     func_block_pc0, func_block_pc1,
    output logic            hold_signal, flush_signal,
    output logic [31:0]     branch1, branch2,

    // uart
    input  logic            uart_rx,
    output logic            uart_tx
);
`define VERILATOR_MYSYSTEM

    top uut (
        .w_clk_50Mhz        (clk_50MHz),
        .cpu_clk            (clk_cpu),
        .w_clk_rst          (rst),
        .i_uart_rx          (uart_rx),
        .o_uart_tx          (uart_tx),

        .i_key              (),
        .o_seg_digit        (),
        .o_seg_sel          (),
        .o_led              ()
    );
        initial begin
            $readmemh("./mem_init/MySystem_irom.txt", `IROM_PATH);
            $readmemh("./mem_init/MySystem_dram.txt", `DRAM_PATH);
        end
        assign LED = `LED_PATH;
        assign SEG = `SEG_PATH;

    `ifdef PROJECT_RV_BASELINE
        wire EX_valid = `EX_PATH.valid_o;
        assign commit = EX_valid;

        assign pc0 = `EX_PATH.pc_o;
        assign pc1 = 0;

        assign hold_signal = `HOLD_PATH;
        assign flush_signal = `FLUSH_PATH;

        wire EX_is_jal = `EX_PATH.ipkg.is_jal & EX_valid;
        wire EX_is_jalr = `EX_PATH.ipkg.is_jalr & EX_valid;
        wire EX_is_branch = `EX_PATH.ipkg.is_branch & EX_valid;
        wire EX_is_mispred = `EX_PATH.mispred_flush_o.en;
        assign pred_total = (EX_is_jal | EX_is_branch);
        assign pred_miss = EX_is_mispred;
        assign pred_total_b = EX_is_branch;
        assign pred_total_jr = EX_is_jalr;
        assign pred_miss_b = EX_is_branch & EX_is_mispred;
        assign pred_miss_jr = EX_is_jalr & EX_is_mispred;

        always_ff @(posedge clk_cpu) begin
            if (EX_is_jal)
                func_block_pc0 <= `EX_PATH.dpkg.imm;
            else if (EX_is_jalr)
                func_block_pc0 <= `EX_PATH.ALU_RV32I.jalr_target;
            else if (EX_is_branch & `EX_PATH.ALU_RV32I.branch_taken == 1'b1)
                func_block_pc0 <= `EX_PATH.ALU_RV32I.branch_target;
        end

    `endif
endmodule