module pred_cnt(
    input           clk,
    input           rst,

    input [1:0]     update_en,
    input           pred_mispredict
);

    reg [31:0]  pred_correct;
    reg [31:0]  pred_uncorrect;
    reg [31:0]  ras_btb_correct;
    reg [31:0]  ras_btb_uncorrect;

    always@(posedge clk or negedge rst) begin
        if(!rst) begin
            pred_correct        <= 32'b0;
            pred_uncorrect      <= 32'b0;
            ras_btb_correct     <= 32'b0;
            ras_btb_uncorrect   <= 32'b0;
        end
        else begin
            if(update_en[0]) begin
                if(!pred_mispredict)    pred_correct        <= pred_correct + 1;
                else                    pred_uncorrect      <= pred_uncorrect + 1;
            end
            else if(update_en[1]) begin
                if(!pred_mispredict)    ras_btb_correct     <= ras_btb_correct + 1;
                else                    ras_btb_uncorrect   <= ras_btb_uncorrect + 1;
            end
        end
    end
endmodule