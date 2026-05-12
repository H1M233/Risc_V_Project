`include "rv32I.vh"

module ex_mem(
    input               clk,
    input               rst,

    // from ex
    input      [31:0]   inst_i,
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen_i,
    input               mem_req_load_i,

    // to mem
    (* max_fanout = 30 *)
    output reg [31:0]   inst_o,
    (* max_fanout = 30 *)
    output reg [4:0]    rd_addr_o,
    (* max_fanout = 30 *)
    output reg [31:0]   rd_data_o,
    (* max_fanout = 30 *)
    output reg          regs_wen_o,
    output reg          mem_req_load_o
);
    always@(posedge clk) begin
        if(!rst) begin
            inst_o      <= `NOP;
            rd_addr_o   <= 5'b0;
            rd_data_o   <= 32'b0;
            regs_wen_o  <= 1'b0;
            mem_req_load_o <= 1'b0;
        end
        else begin
            inst_o      <= inst_i;
            rd_addr_o   <= rd_addr_i;
            rd_data_o   <= rd_data_i;
            regs_wen_o  <= regs_wen_i;
            mem_req_load_o <= mem_req_load_i;
        end
    end
endmodule