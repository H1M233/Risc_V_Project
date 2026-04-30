`include "rv32I.vh"

module wb(
    // from mem_wb
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen_i,

    // to regs
    output reg [4:0]    rd_addr_o,
    output reg [31:0]   rd_data_o,
    output reg          regs_wen_o
);

    always @(*) begin
        rd_data_o   = rd_data_i;
        rd_addr_o   = rd_addr_i;
        regs_wen_o  = regs_wen_i;
    end

endmodule