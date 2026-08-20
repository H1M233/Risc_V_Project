`timescale 1ns / 1ps

module display_seg (
    input  logic          clk    ,
    input  logic          rst    ,
    input  logic [31:0]   s      ,
    output logic [5:0]    sel    ,
    output logic [7:0]    seg    
);
    parameter CNT_MAX = 27'd100_000_000;     // 2 s
    
    logic [26:0] cnt;
    logic        display_bit;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            cnt         <= 0;
            display_bit <= 0;
        end
        else if (cnt == CNT_MAX - 1) begin
            cnt         <= 0;
            display_bit <= display_bit + 1'b1;
        end
        else begin
            cnt         <= cnt + 1'b1;
            display_bit <= display_bit;
        end
    end

    logic [2:0] update_cnt;
    logic [3:0] digit [0:3];

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            case (display_bit)
                0       : digit[i] = s[i*4 +:4];
                1       : digit[i] = s[i*4+16 +:4];
                default : digit[i] = 4'b0;
            endcase
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst)
            update_cnt <= 0;
        else if (update_cnt == 3'd5)
            update_cnt <= 0;
        else
            update_cnt <= update_cnt + 1;
    end

    logic [5:0] digit_sel;
    logic       dot;
    logic [3:0] seg7_in;
    logic [6:0] seg7_out;

    always_comb begin
        case (update_cnt)
            0 : begin
                digit_sel   = 6'b000_001;
                seg7_in     = digit[0];
                dot         = 1'b1;
            end
            1 : begin
                digit_sel   = 6'b000_100;
                seg7_in     = digit[2];
                dot         = 1'b1;
            end
            2 : begin
                digit_sel   = 6'b010_000;
                seg7_in     = display_bit;
                dot         = 1'b0;
            end
            3 : begin
                digit_sel   = 6'b000_010;
                seg7_in     = digit[1];
                dot         = 1'b1;
            end
            4 : begin
                digit_sel   = 6'b001_000;
                seg7_in     = digit[3];
                dot         = 1'b1;
            end
            5 : begin
                digit_sel   = 6'b100_000;
                seg7_in     = 4'hb;
                dot         = 1'b1;
            end
            default : begin
                digit_sel   = 6'b000_000;
                seg7_in     = 4'b0;
                dot         = 1'b1;
            end
        endcase
    end

    seg7 SEG7(.din(seg7_in), .dout(seg7_out));

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            sel <= 6'b111_111;
            seg <= 8'b1111_1111;
        end
        else begin
            sel <= digit_sel;
            seg <= {seg7_out, dot};
        end
    end
endmodule