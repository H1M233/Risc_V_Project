module ifetch(
    // from pc
    input   wire[31:0]  pc_addr_i,
    // from ROM
    input   wire[31:0]  rom_inst_i,
    // to ROM
    output  wire[31:0]  if2rom_addr_o,
    // to if_id
    output  wire[31:0]  inst_addr_o,
    output  wire[31:0]  inst_o
);

    // 将pc输入的指令地址发往rom
    assign if2rom_addr_o    = pc_addr_i;

    // 将pc输入的指令地址发往if_id
    assign inst_addr_o      = pc_addr_i;

    // 将rom返回的指令发往if_id
    assign inst_o           = rom_inst_i;

endmodule