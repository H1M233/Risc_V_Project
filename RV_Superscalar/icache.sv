`include "rv32I.vh"
`include "switch.vh"

module icache #(
    parameter INDEX_WIDTH   = 6,        // 索引宽度
    parameter TAG_WIDTH     = 24,       // tag 宽度
    parameter WAYS          = 2         // 路数
)(
    input               clk,
    input               rst,
    input               pipe_hold,
    input               pipe_flush,

    // CPU / IF side
    (* max_fanout = 30 *) input        [31:0]  slot0_cpu_pc,
    (* max_fanout = 30 *) input        [31:0]  slot1_cpu_pc,

    (* max_fanout = 30 *) output logic [31:0]  slot0_cpu_inst,
    (* max_fanout = 30 *) output logic [31:0]  slot1_cpu_inst,

    // IROM side
    (* max_fanout = 30 *) output       [31:0]  slot0_mem_addr,
    (* max_fanout = 30 *) output       [31:0]  slot1_mem_addr,

    (* max_fanout = 30 *) input        [31:0]  slot0_mem_inst,
    (* max_fanout = 30 *) input        [31:0]  slot1_mem_inst
);
    assign slot0_mem_addr = slot0_cpu_pc;
    assign slot1_mem_addr = slot1_cpu_pc;

    always_ff @(posedge clk) begin
        if (!rst) begin
            slot0_cpu_inst <= `NOP;
            slot1_cpu_inst <= `NOP;
        end
        else if (pipe_hold) begin
            // ...
        end
        else if (pipe_flush) begin
            slot0_cpu_inst <= `NOP;
            slot1_cpu_inst <= `NOP;
        end
        else begin
            slot0_cpu_inst <= slot0_mem_inst;
            slot1_cpu_inst <= slot1_mem_inst;
        end
    end
endmodule