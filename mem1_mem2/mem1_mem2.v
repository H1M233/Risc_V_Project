`include "rv32I.vh"

module mem1_mem2(
    input               clk,
    input               rst,

    input      [31:0]   inst_i,
    input      [4:0]    rd_addr_i,
    input      [31:0]   alu_data_i,
    input      [31:0]   mem_data_i,
    input               regs_wen_i,

    output reg [31:0]   inst_o,
    output reg [4:0]    rd_addr_o,
    output reg [31:0]   alu_data_o,
    output reg [31:0]   mem_data_o,
    output reg          regs_wen_o
);

    always @(posedge clk) begin
        if (!rst) begin
            inst_o      <= `NOP;
            rd_addr_o   <= 5'b0;
            alu_data_o  <= 32'b0;
            mem_data_o  <= 32'b0;
            regs_wen_o  <= 1'b0;
        end
        else begin
            inst_o      <= inst_i;
            rd_addr_o   <= rd_addr_i;
            alu_data_o  <= alu_data_i;
            mem_data_o  <= mem_data_i;
            regs_wen_o  <= regs_wen_i;
        end
    end

endmodule