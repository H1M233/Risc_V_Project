module IROM(
    input       [11:0]  a,
    output  reg [31:0]  spo
);

    // 设置4096个32位空间
    reg[31:0] rom_mem[0:4095];

    always@(*) begin
        spo = rom_mem[a];
    end

endmodule