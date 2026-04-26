`include "rv32I.vh"

module regs(
    input               clk,
    input               rst,

    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen,

    input      [4:0]    rs1_addr_i,
    input      [4:0]    rs2_addr_i,

    output reg [31:0]   rs1_data_o,
    output reg [31:0]   rs2_data_o
);

    reg [31:0] regs[31:0];

    integer i;

    always @(*) begin
        if (!rst) begin
            rs1_data_o = 32'b0;
        end
        else if (rs1_addr_i == 5'b0) begin
            rs1_data_o = 32'b0;
        end
        else begin
            rs1_data_o = regs[rs1_addr_i];
        end
    end

    always @(*) begin
        if (!rst) begin
            rs2_data_o = 32'b0;
        end
        else if (rs2_addr_i == 5'b0) begin
            rs2_data_o = 32'b0;
        end
        else begin
            rs2_data_o = regs[rs2_addr_i];
        end
    end

    always @(posedge clk) begin
        if (!rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'b0;
            end
        end
        else if (regs_wen && (rd_addr_i != 5'b0)) begin
            regs[rd_addr_i] <= rd_data_i;
        end
    end

endmodule