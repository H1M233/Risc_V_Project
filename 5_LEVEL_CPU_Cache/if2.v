`include "rv32I.vh"

module if2(
    // from if1_if2
    input               if2_valid_i,
    input      [31:0]   pc_i,
    input               pred_flush,
    input               pred_taken,

    // from icache
    input      [31:0]   inst_i,

    // to if_id & bpu
    (* max_fanout = 30 *)
    output reg [31:0]   pc_o,
    (* max_fanout = 30 *)
    output reg [31:0]   inst_o
);
    always @(*) begin
        pc_o    = (pred_flush) ? 32'b0 : pc_i;
        inst_o  = (if2_valid_i & !pred_flush & !pred_taken) ? inst_i : `NOP;
    end
endmodule