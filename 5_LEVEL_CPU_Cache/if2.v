`include "rv32I.vh"

module if2(
    // from if1_if2
    input               if2_valid_i,
    input      [31:0]   pc_i,

    // from icache
    input      [31:0]   inst_i,

    // to if_id & bpu
    output reg [31:0]   pc_o,
    output reg [31:0]   inst_o
);
    always @(*) begin
        pc_o    = pc_i;         // pc 处理过了
        inst_o  = (if2_valid_i) ? inst_i : `NOP;
    end
endmodule