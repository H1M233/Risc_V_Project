`include "rv32I.vh"
`include "alu.vh"

module id_ex(
    input               clk,
    input               rst,

    input               pipe_hold,
    input               pred_flush,
    input               hazard_en,

    // from id
    input  id_ex_data_t data_packaged_i,
    input  decode_t     inst_packaged_i,
    input               regs_wen_i,

    // to ex
    output id_ex_data_t data_packaged_o,
    output decode_t     inst_packaged_o,
    output logic        regs_wen_o,
    output logic        valid_o
);
    wire id_ex_flush_en_n = ~(pred_flush | hazard_en);
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
        else begin
            data_packaged_o     <= data_packaged_i;
            inst_packaged_o     <= (id_ex_flush_en_n) ? inst_packaged_i : 0;
            regs_wen_o          <= id_ex_flush_en_n && regs_wen_i;
            valid_o             <= id_ex_flush_en_n;
        end
    end
endmodule