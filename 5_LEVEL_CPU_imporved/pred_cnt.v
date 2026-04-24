module pred_cnt(
    input           clk,
    input           rst,

    input           update_btb_en,
    input           update_gshare_en,
    input           pred_mispredict
);

    reg [31:0]  pred_correct;
    reg [31:0]  pred_uncorrect;
    reg [31:0]  ras_btb_correct;
    reg [31:0]  ras_btb_uncorrect;

    always@(posedge clk) begin
        if(!rst) begin
            pred_correct        <= 32'b0;
            pred_uncorrect      <= 32'b0;
            ras_btb_correct     <= 32'b0;
            ras_btb_uncorrect   <= 32'b0;
        end
        else begin
            if(update_gshare_en) begin
                if(!pred_mispredict)    pred_correct        <= pred_correct + 1;
                else                    pred_uncorrect      <= pred_uncorrect + 1;
            end
            else if(update_btb_en) begin
                if(!pred_mispredict)    ras_btb_correct     <= ras_btb_correct + 1;
                else                    ras_btb_uncorrect   <= ras_btb_uncorrect + 1;
            end
        end
    end
endmodule