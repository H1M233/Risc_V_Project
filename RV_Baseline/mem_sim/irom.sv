module IROM(
    input  logic        clka    ,
    input  logic [11:0] addra   ,
    output logic [31:0] douta   ,
    input  logic        ena     
);
    // 设置4096个32位空间
    reg [31:0] rom_mem[0:4095];

    logic [31:0] irom_rdata_d1;
    always_ff @(posedge clka) begin
        irom_rdata_d1   <= (ena) ? rom_mem[addra] : 0;
        douta           <= (ena) ? irom_rdata_d1 : 0;
    end

endmodule