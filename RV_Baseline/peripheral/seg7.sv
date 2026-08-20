`timescale 1ns / 1ps

module seg7(
    input  logic [3:0]      din     ,
    output logic [6:0]      dout    
);
    always_comb begin
        case(din)
            4'h0    : dout = 7'b000_0001;
            4'h1    : dout = 7'b100_1111;
            4'h2    : dout = 7'b001_0010;
            4'h3    : dout = 7'b000_0110;
            4'h4    : dout = 7'b100_1100;
            4'h5    : dout = 7'b010_0100;
            4'h6    : dout = 7'b010_0000;
            4'h7    : dout = 7'b000_1111;
            4'h8    : dout = 7'b000_0000;
            4'h9    : dout = 7'b000_0100;
            4'ha    : dout = 7'b000_1000;
            4'hb    : dout = 7'b110_0000;
            4'hc    : dout = 7'b011_0001;
            4'hd    : dout = 7'b100_0010;
            4'he    : dout = 7'b011_0000;
            4'hf    : dout = 7'b011_1000;
            default : dout = 7'b111_1111;
        endcase
    end
endmodule