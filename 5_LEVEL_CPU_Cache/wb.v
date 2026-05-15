`include "rv32I.vh"
`include "alu.vh"

module wb(
    // from mem_wb
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen_i,
    input               is_load,

    // to wb_regs
    output reg [4:0]    rd_addr_o,
    output reg [31:0]   rd_data_o,
    output reg          regs_wen_o,

    // from dcache
    input               dcache_ack,
    input      [31:0]   perip_rdata
);

    always@(*) begin
        rd_addr_o   = rd_addr_i;
        regs_wen_o  = (is_load) ? dcache_ack : regs_wen_i;        // 添加与 Dcache 的握手机制来保证 LOAD 正确
        rd_data_o   = (is_load) ? perip_rdata : rd_data_i;
    end
    
endmodule