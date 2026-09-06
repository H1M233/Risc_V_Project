module IROM(
    input  logic        clka    ,
    input  logic [11:0] addra   ,
    output logic [31:0] douta   ,
    input  logic        ena     ,

    input  logic        clkb    ,
    input  logic [11:0] addrb   ,
    output logic [31:0] doutb   ,
    input  logic        enb     
);
    // 设置4096个32位空间
    reg [31:0] rom_mem[0:4095];

    logic [31:0] douta_d1;
    always_ff @(posedge clka) begin
        douta_d1    <= (ena) ? rom_mem[addra] : 0;
        douta       <= (ena) ? douta_d1 : 0;
    end

    logic [31:0] doutb_d1;
    always_ff @(posedge clkb) begin
        doutb_d1    <= (enb) ? rom_mem[addrb] : 0;
        doutb       <= (enb) ? doutb_d1 : 0;
    end

endmodule