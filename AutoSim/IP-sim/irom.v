module irom(
    input       [31:0]  inst_addr_i,
    output  reg [31:0]  inst_o
);

    // 设置4096个32位空间
    reg[31:0] rom_mem[0:4095];

    always@(*) begin
        inst_o = rom_mem[inst_addr_i[13:2]];
    end

endmodule