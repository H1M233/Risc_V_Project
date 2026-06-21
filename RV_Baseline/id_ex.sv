`include "rv32I.svh"
`include "alu_def.svh"

module id_ex(
    input  logic        clk,
    input  logic        rst,
    input  logic        pipe_flush,
    input  logic        pipe_hold,

    // from id
    input  id_ex_data_t data_packaged_i,
    input  decode_t     inst_packaged_i,
    input  logic        regs_wen_i,

    // to ex
    output id_ex_data_t data_packaged_o,
    output decode_t     inst_packaged_o,
    output logic        regs_wen_o,
    output logic        valid_o
);
    always_ff @(posedge clk) begin
        if (!rst) begin
            data_packaged_o     <= 0;
            inst_packaged_o     <= 0;
            regs_wen_o          <= 0;
            valid_o             <= 1'b0;
        end
        else if (pipe_hold) begin
            // ..
        end
        else if (pipe_flush) begin
            data_packaged_o     <= 0;
            inst_packaged_o     <= 0;
            regs_wen_o          <= 0;
            valid_o             <= 0;
        end
        else begin
            data_packaged_o     <= data_packaged_i;
            inst_packaged_o     <= inst_packaged_i;
            regs_wen_o          <= regs_wen_i;
            valid_o             <= 1'b1;
        end
    end
endmodule