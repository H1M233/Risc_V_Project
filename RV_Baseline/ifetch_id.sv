`include "rv32I.vh"

module ifetch_id(
    input               clk,
    input               rst,
    
    input               pipe_hold,
    input               pipe_flush,

    // from if
    input  if_id_t      data_packaged_i,

    // to id
    output if_id_t      data_packaged_o

);
    always_ff @(posedge clk) begin
        if (!rst) begin
            data_packaged_o <= 0;
        end
        else if (pipe_hold) begin
            // ...
        end
        else if (pipe_flush) begin
            data_packaged_o <= 0;
        end
        else begin
            data_packaged_o <= data_packaged_i;
        end
    end
endmodule