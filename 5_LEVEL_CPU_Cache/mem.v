`include "rv32I.vh"
`include "alu.vh"

module mem(
    input               clk,
    input               rst,

    // from ex_mem
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen,
    input               mem_req_load_i,
    input      [4:0]    load_packaged_i,

    // from D-Cache
    input      [31:0]   perip_rdata,
    input               dcache_ack,
    
    // to hazard
    output              mem1_is_load_o,

    // to forwarding
    output     [4:0]    mem1_rd_addr_o,
    output     [31:0]   mem1_rd_data_o,
    output              mem1_regs_wen_o,

    // to mem_wb & forwarding
    output     [4:0]    mem2_rd_addr_o,
    output     [31:0]   mem2_rd_data_o,
    output              mem2_regs_wen_o
);  
    wire        mem1_req_load_o;
    wire [4:0]  mem1_rd_addr_oo;
    wire [31:0] mem1_rd_data_oo;
    wire        mem1_regs_wen_oo;
    wire [4:0]  mem1_load_packaged_o;

    wire        mem2_req_load_i;
    wire [4:0]  mem2_rd_addr_i;
    wire [31:0] mem2_rd_data_i;
    wire        mem2_regs_wen_i;
    wire [4:0]  mem2_load_packaged_i;

    wire [4:0]  mem2_rd_addr_oo;
    wire [31:0] mem2_rd_data_oo;
    wire        mem2_regs_wen_oo;

    assign mem1_is_load_o   = mem1_req_load_o;
    assign mem1_rd_addr_o   = mem1_rd_addr_oo;
    assign mem1_rd_data_o   = mem1_rd_data_oo;
    assign mem1_regs_wen_o  = mem1_regs_wen_oo;
    assign mem2_rd_addr_o   = mem2_rd_addr_oo;
    assign mem2_rd_data_o   = mem2_rd_data_oo;
    assign mem2_regs_wen_o  = mem2_regs_wen_oo;

    mem1 MEM1(
        .rd_addr_i          (rd_addr_i),
        .rd_data_i          (rd_data_i),
        .regs_wen           (regs_wen),
        .mem_req_load_i     (mem_req_load_i),
        .load_packaged_i    (load_packaged_i),

        .req_load_o         (mem1_req_load_o),
        .rd_addr_o          (mem1_rd_addr_oo),
        .rd_data_o          (mem1_rd_data_oo),
        .regs_wen_o         (mem1_regs_wen_oo),
        .load_packaged_o    (mem1_load_packaged_o)
    );

    mem1_mem2 MEM1_MEM2(
        .clk(clk), .rst(rst),
        .req_load_i(mem1_req_load_o), .rd_addr_i(mem1_rd_addr_oo), .rd_data_i(mem1_rd_data_oo),
        .regs_wen_i(mem1_regs_wen_oo), .load_packaged_i(mem1_load_packaged_o),
        .req_load_o(mem2_req_load_i), .rd_addr_o(mem2_rd_addr_i), .rd_data_o(mem2_rd_data_i),
        .regs_wen_o(mem2_regs_wen_i), .load_packaged_o(mem2_load_packaged_i)
    );

    mem2 MEM2(
        .req_load_i         (mem2_req_load_i),
        .rd_addr_i          (mem2_rd_addr_i),
        .rd_data_i          (mem2_rd_data_i),
        .regs_wen           (mem2_regs_wen_i),
        .load_packaged_i    (mem2_load_packaged_i),

        .perip_rdata        (perip_rdata),
        .dcache_ack         (dcache_ack),

        .rd_addr_o          (mem2_rd_addr_oo),
        .rd_data_o          (mem2_rd_data_oo),
        .regs_wen_o         (mem2_regs_wen_oo)
    );
endmodule

module mem1(
    // from ex_mem
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen,
    input               mem_req_load_i,
    input      [4:0]    load_packaged_i,

    // to mem1_mem2
    output reg          req_load_o,
    output reg [4:0]    rd_addr_o,
    output reg [31:0]   rd_data_o,
    output reg          regs_wen_o,
    output reg [4:0]    load_packaged_o
);
    always@(*) begin
        req_load_o      = mem_req_load_i;
        rd_addr_o       = rd_addr_i;
        rd_data_o       = rd_data_i;
        regs_wen_o      = (mem_req_load_i) ? 1'b0 : regs_wen;
        load_packaged_o = load_packaged_i;
    end
endmodule

module mem1_mem2(
    input               clk,
    input               rst,

    // from mem1
    input               req_load_i,
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen_i,
    input      [4:0]    load_packaged_i,

    // from mem2
    output reg          req_load_o,
    output reg [4:0]    rd_addr_o,
    output reg [31:0]   rd_data_o,
    output reg          regs_wen_o,
    output reg [4:0]    load_packaged_o
);
    always @(posedge clk) begin
        if (!rst) begin
            req_load_o          <= 0;
            rd_addr_o           <= 0;
            rd_data_o           <= 0;
            regs_wen_o          <= 0;
            load_packaged_o     <= 0;
        end
        else begin
            req_load_o          <= req_load_i;
            rd_addr_o           <= rd_addr_i;
            rd_data_o           <= rd_data_i;
            regs_wen_o          <= regs_wen_i;
            load_packaged_o     <= load_packaged_i;
        end
    end
endmodule

module mem2(
    // from mem1_mem2
    input               req_load_i,
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen,
    input      [4:0]    load_packaged_i,

    // from D-Cache
    input      [31:0]   perip_rdata,
    input               dcache_ack,

    // to mem_wb
    output reg [4:0]    rd_addr_o,
    output reg [31:0]   rd_data_o,
    output reg          regs_wen_o
);
    wire is_lb   = load_packaged_i[`IS_LB];
    wire is_lh   = load_packaged_i[`IS_LH];
    wire is_lw   = load_packaged_i[`IS_LW];
    wire is_lbu  = load_packaged_i[`IS_LBU];
    wire is_lhu  = load_packaged_i[`IS_LHU];

    always@(*) begin
        rd_addr_o   = rd_addr_i;
        regs_wen_o  = req_load_i ? dcache_ack : regs_wen;    // 添加与 Dcache 的握手机制来保证 LOAD 正确
        
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