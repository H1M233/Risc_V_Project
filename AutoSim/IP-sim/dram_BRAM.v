module dram_BRAM(
    input               clk,
    input               rst,

    input               dram_en,
    input      [31:0]   dram_addr_i,
    input      [3:0]    dram_we_i,
    input      [31:0]   dram_wdata_i,
    output reg [31:0]   dram_rdata_o
);

    // 设置65536个32位空间
    reg [31:0] ram_mem[0:65535];

    wire [15:0] dram_word_addr = dram_addr_i[15:0];
    wire [31:0] dram_rdata_raw = ram_mem[dram_word_addr];

    always @(posedge clk) begin
        if (dram_wen_i) begin
            case (dram_mask_i)
                2'b10: ram_mem[dram_word_addr] <= dram_wdata_i;  // sw
                2'b01: begin           // sh
                    case (dram_addr_i[1])
                        1'b0: ram_mem[dram_word_addr][15:0]      <= dram_wdata_i[15:0];
                        1'b1: ram_mem[dram_word_addr][31:16]     <= dram_wdata_i[15:0];
                    endcase
                end
                2'b00: begin           // sb
                    case (dram_addr_i[1:0])
                        2'b00: ram_mem[dram_word_addr][7:0]      <= dram_wdata_i[7:0];
                        2'b01: ram_mem[dram_word_addr][15:8]     <= dram_wdata_i[7:0];
                        2'b10: ram_mem[dram_word_addr][23:16]    <= dram_wdata_i[7:0];
                        2'b11: ram_mem[dram_word_addr][31:24]    <= dram_wdata_i[7:0];
                    endcase
                end
            endcase
        end
    end

endmodule