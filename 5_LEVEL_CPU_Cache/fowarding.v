module forwarding(
    input clk, rst,
    input dcache_stall, jump_en, hazard_en,

    // ex
    input [31:0] ex_regs_wen,
    input [4:0] ex_rd_addr,
    input [31:0] ex_rd_data,

    // mem
    input [31:0] mem_regs_wen,
    input [4:0] mem_rd_addr,
    input [31:0] mem_rd_data,

    // wb


);

endmodule