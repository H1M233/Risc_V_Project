module dram_BRAM(
    input               clk,
    input               rst,

    input               dram_en_i,
    input      [31:0]   dram_addr_i,
    input      [3:0]    dram_we_i,
    input               dram_wen_i,
    input      [31:0]   dram_wdata_i,
    output reg [31:0]   dram_rdata_o
);

    // 设置65536个32位空间
    reg [31:0] ram_mem[0:65535];

    wire [15:0] dram_word_addr = dram_addr_i[17:2];
    wire [31:0] dram_rdata_raw = ram_mem[dram_word_addr];

    reg [31:0] dram_rdata_delay;

    wire [31:0] pre_wdata = {
        dram_we_i[3] ? dram_wdata_i[31:24] : dram_rdata_raw[31:24],
        dram_we_i[2] ? dram_wdata_i[23:16] : dram_rdata_raw[23:16],
        dram_we_i[1] ? dram_wdata_i[15:8 ] : dram_rdata_raw[15:8 ],
        dram_we_i[0] ? dram_wdata_i[7 :0 ] : dram_rdata_raw[7 :0 ]
    };
    
    always @(posedge clk) begin
        dram_rdata_delay <= (dram_en_i) ? (dram_wen_i) ? pre_wdata : dram_rdata_raw : 32'b0;
        dram_rdata_o <= (dram_en_i) ? dram_rdata_delay : 32'b0;
    end


    always @(posedge clk) begin
        if(dram_en_i && dram_wen_i) ram_mem[dram_word_addr] <= pre_wdata;
    end

endmodule