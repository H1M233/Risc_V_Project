module ex_bpu(
    input  logic clk,
    input  logic rst,
    input  logic pipe_hold,
    input  logic pipe_flush,

    input  ex_bpu_data_t data_packaged_i,
    input  logic         pred_flush_en_i,
    input  logic [31:0]  pred_flush_pc_i,

    output ex_bpu_data_t data_packaged_o,
    output logic         pred_flush_en_o,
    output logic [31:0]  pred_flush_pc_o
);
    always_ff @(posedge clk) begin
        if (!rst) begin
            data_packaged_o <= 0;

            pred_flush_en_o <= 0;
            pred_flush_pc_o <= 0;

        end
        else if (pipe_hold) begin
            // ...
        end
        else if (pipe_flush) begin
            data_packaged_o <= 0;

            pred_flush_en_o <= 0;
            pred_flush_pc_o <= 0;
        end
        else begin
            data_packaged_o <= data_packaged_i;

            pred_flush_en_o <= pred_flush_en_i;
            pred_flush_pc_o <= pred_flush_pc_i;
        end
    end
endmodule