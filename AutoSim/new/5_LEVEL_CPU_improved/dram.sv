module dram_LUTRAM(
    input               clk,

    input      [15:0]   dram_addr_i,
    input               dram_wen_i,
    input      [31:0]   dram_wdata_i,
    output reg [31:0]   dram_rdata_o
);

    // 设置65536个32位空间
    reg [31:0] ram_mem[0:65535];

    always @(*) begin
        dram_rdata_o = ram_mem[dram_addr_i];
    end

    always @(posedge clk) begin
        if (dram_wen_i) begin
            ram_mem[dram_addr_i] <= dram_wdata_i;
        end
    end
endmodule


module DRAM(
    input               clk,

    input      [15:0]   a,
    output reg [31:0]   spo,
    input               we,
    input      [31:0]   d
);

    dram_LUTRAM dram_inst(
        .clk            (clk),
        .dram_addr_i    (a),
        .dram_wen_i     (we),
        .dram_wdata_i   (d),
        .dram_rdata_o   (spo)
    );

endmodule