`include "rv32I.vh"

module pc(
    input               clk,
    input               rst,

    // from D-cache stall
    input               dcache_stall,

    // from hazard
    input               hazard_en,

    // from jump
    input      [31:0]   jump_addr_i,
    input               jump_en,

    // to if
    (* max_fanout = 30 *)
    output reg [31:0]   pc_addr_o,

    // from bpu
    input      [31:0]   pred_pc,
    input               pred_taken
);
    always @(posedge clk) begin
        if(!rst) begin
            pc_addr_o <= 32'h8000_0000;
        end
        else if(jump_en) begin
            pc_addr_o <= jump_addr_i;
        end
        else if(hazard_en) begin
            pc_addr_o <= pc_addr_o;
        end
        else if(dcache_stall) begin
            pc_addr_o <= pc_addr_o;
        end
        else if(pred_taken) begin
            pc_addr_o <= pred_pc;
        end
        else begin
            pc_addr_o <= pc_addr_o + 4;
        end
    end
endmodule