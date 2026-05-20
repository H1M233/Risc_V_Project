`include "rv32I.vh"
`include "alu.vh"
                        //打拍器
module wb_pc(
    input               clk,
    input               rst,

    // from wb
    input               wb_ecall,
    input               wb_mret,

    // to pc
    output reg          pc_ecall,
    output reg          pc_mret
);
    always@(posedge clk) begin
        if (!rst) begin
            pc_ecall <= 0;
            pc_mret <= 0;
        end
        else begin
            pc_ecall <= wb_ecall;
            pc_mret <= wb_mret;
        end
    end
endmodule