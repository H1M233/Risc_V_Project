module rom(
    input   wire[31:0]  inst_addr_i,
    output  reg[31:0]   inst_o
);

    // 设置4096个32位空间
    reg[31:0] rom_mem[0:4095];

    always@(*) begin
        // 存储单元已分好32位一组，索引值仅需+1
        inst_o = rom_mem[inst_addr_i >> 2];
    end

endmodule