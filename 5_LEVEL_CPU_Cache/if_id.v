`include "rv32I.vh"

module if_id(
    input               clk,
    input               rst,

    // from D-cache stall
    input               dcache_stall,

    // from I-cache front stall
    input               icache_block,

    // from hazard
    input               hazard_en,

    // from if
    input      [31:0]   inst_i,
    input      [31:0]   pc_addr_i,

    // from jump
    input               jump_en,

    // to id
    output reg [31:0]   inst_o,
    output reg [31:0]   pc_addr_o,

    // from bpu
    input               pred_taken
);
    always @(posedge clk) begin
        if(!rst) begin
            pc_addr_o <= 32'b0;
            inst_o    <= `NOP;
        end
        else if(dcache_stall) begin
            pc_addr_o <= pc_addr_o;
            inst_o    <= inst_o;
        end
        else if(jump_en) begin
            pc_addr_o <= 32'b0;
            inst_o    <= `NOP;
        end
        else if(hazard_en) begin
            pc_addr_o <= pc_addr_o;
            inst_o    <= inst_o;
        end
        else if(pred_taken) begin
            pc_addr_o <= 32'b0;
            inst_o    <= `NOP;
        end
        else if(icache_block) begin
            pc_addr_o <= pc_addr_o;
            inst_o    <= inst_o;
        end
        else begin
            pc_addr_o <= pc_addr_i;
            inst_o    <= inst_i;
        end
    end
endmodule