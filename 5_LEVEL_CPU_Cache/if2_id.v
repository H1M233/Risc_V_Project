`include "rv32I.vh"

module if2_id(
    input               clk,
    input               rst,

    // from hazard
    (* max_fanout = 30 *)
    input               pipe_hold,

    // from if
    input      [31:0]   inst_i,
    input      [31:0]   pc_i,

    // to id
    (* max_fanout = 30 *)
    output reg [31:0]   inst_o,
    output reg [31:0]   pc_o

);
    always @(posedge clk) begin
        if (!rst) begin
            pc_o    <= 32'b0;
            inst_o  <= `NOP;
        end
        else if (!pipe_hold) begin
            pc_o    <= pc_i;
            inst_o  <= inst_i;
        end
    end
endmodule