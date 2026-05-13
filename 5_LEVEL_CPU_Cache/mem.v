`include "rv32I.vh"
`include "alu.vh"

module mem(
    // from ex_mem
    input      [31:0]   inst_i,
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen,
    input               mem_req_load_i,
    input      [4:0]    load_packaged_i,

    // from DRAM
    (* max_fanout = 30 *)
    input      [31:0]   perip_rdata,

    // to mem_wb
    (* max_fanout = 30 *)
    output reg [31:0]   rd_data_o,
    (* max_fanout = 30 *)
    output reg          regs_wen_o,

    // to mem_wb & hazrd
    (* max_fanout = 30 *)
    output reg [4:0]    rd_addr_o,

    // dcache_ack
    input               dcache_ack
);
    wire is_lb   = load_packaged_i[`IS_LB];
    wire is_lh   = load_packaged_i[`IS_LH];
    wire is_lw   = load_packaged_i[`IS_LW];
    wire is_lbu  = load_packaged_i[`IS_LBU];
    wire is_lhu  = load_packaged_i[`IS_LHU];

    always@(*) begin
        rd_addr_o   = rd_addr_i;
        regs_wen_o  = mem_req_load_i ? dcache_ack : regs_wen;    // 添加与 Dcache 的握手机制来保证 LOAD 正确
        
        (* parallel_case, full_case *)
        case(1'b1)
            is_lb:   rd_data_o   = {{24{perip_rdata[7]}}, perip_rdata[7:0]};
            is_lh:   rd_data_o   = {{16{perip_rdata[15]}}, perip_rdata[15:0]};
            is_lw:   rd_data_o   = perip_rdata;
            is_lbu:  rd_data_o   = {24'b0, perip_rdata[7:0]};
            is_lhu:  rd_data_o   = {16'b0, perip_rdata[15:0]};
            default: rd_data_o   = rd_data_i;
        endcase
    end
endmodule