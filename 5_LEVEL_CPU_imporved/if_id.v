`include "rv32I.vh"

module if_id(
    input               clk,
    input               rst,

    // from hazrd
    input               hazard_en,

    // from if
    input      [31:0]   inst_i,
    input      [31:0]   pc_addr_i,

    // from jump
    input               jump_en,

    // to id
    output reg [31:0]   inst_o,         // 传递指令内容
    output reg [31:0]   pc_addr_o       // 传递指令地址
);
    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            pc_addr_o   <= 32'b0;
            inst_o      <= `NOP;
        end
        else if(jump_en) begin
            pc_addr_o   <= pc_addr_i;
            inst_o      <= `NOP;
        end
        else if(hazard_en) begin
            pc_addr_o   <= pc_addr_o;
            inst_o      <= inst_o;
        end
        else begin
            pc_addr_o   <= pc_addr_i;
            inst_o      <= inst_i;
        end
    end
endmodule