`include "rv32I.vh"

module mem_wb(
    input               clk,
    input               rst,

    // from mem
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen_i,

    // to wb
    output reg [4:0]    rd_addr_o,
    output reg [31:0]   rd_data_o,
    output reg          regs_wen_o
);

    always @(posedge clk) begin
        if (!rst) begin
            rd_data_o   <= 32'b0;
            rd_addr_o   <= 5'b0;
            regs_wen_o  <= 1'b0;
        end 
        else begin
            rd_data_o   <= rd_data_i;
            rd_addr_o   <= rd_addr_i;
            regs_wen_o  <= regs_wen_i;
        end
    end

endmodule