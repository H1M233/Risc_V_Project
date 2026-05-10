`include "rv32I.vh"

module if2_id(
    input               clk,
    input               rst,

    // from hazard
    input               pipe_hold,

    // from if
    input      [31:0]   inst_i,
    input      [31:0]   pc_addr_i,

    input               pipe_flush,

    // to id
    output reg [31:0]   inst_o,
    output reg [31:0]   pc_addr_o

);
    always @(posedge clk) begin
        if (!rst) begin
            pc_addr_o <= 32'b0;
            inst_o    <= `NOP;
        end
        else if (pipe_hold) begin
            pc_addr_o <= pc_addr_o;
            inst_o    <= inst_o;
        end
        else if (pipe_flush) begin
            pc_addr_o <= 32'b0;
            inst_o    <= `NOP;
        end
        else begin
            pc_addr_o <= pc_addr_i;
            inst_o    <= inst_i;
        end
    end
endmodule