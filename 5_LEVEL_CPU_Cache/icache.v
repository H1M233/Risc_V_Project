`include "rv32I.vh"
`include "switch.vh"

module icache #(
    parameter INDEX_WIDTH   = 6,        // 索引宽度
    parameter TAG_WIDTH     = 24,       // tag 宽度
    parameter WAYS          = 2         // 路数
)(
    input               clk,
    input               rst,

    // CPU / IF side
    (* max_fanout = 30 *)
    input      [31:0]   cpu_pc,
    (* max_fanout = 30 *)
    output reg [31:0]   cpu_inst,
    (* max_fanout = 30 *)
    input               pipe_hold,

    // IROM side
    (* max_fanout = 30 *)
    output     [31:0]   mem_addr,
    (* max_fanout = 30 *)
    input      [31:0]   mem_inst
);
    assign mem_addr = cpu_pc;

    always @(posedge clk) begin
        if (!rst) begin
            cpu_inst <= `NOP;
        end
        else if (pipe_hold) begin
            // ...
        end
        else begin
            cpu_inst <= mem_inst;
        end
    end
endmodule