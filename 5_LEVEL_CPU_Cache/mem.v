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
    
    // to hazard & wb
    output              mem1_is_load_o,
    output reg          mem2_is_load_o,

    // to forwarding
    output     [4:0]    mem1_rd_addr_o,
    output     [31:0]   mem1_rd_data_o,
    output              mem1_regs_wen_o,

    // to mem_wb & forwarding
    output reg [4:0]    mem2_rd_addr_o,
    output reg [31:0]   mem2_rd_data_o,
    output reg          mem2_regs_wen_o
);  
    reg        mem1_req_load_o;
    reg [4:0]  mem1_rd_addr_oo;
    reg [31:0] mem1_rd_data_oo;
    reg        mem1_regs_wen_oo;

    reg        mem2_req_load_i;
    reg [4:0]  mem2_rd_addr_i;
    reg [31:0] mem2_rd_data_i;
    reg        mem2_regs_wen_i;

    assign mem1_is_load_o   = mem1_req_load_o;
    assign mem1_rd_addr_o   = mem1_rd_addr_oo;
    assign mem1_rd_data_o   = mem1_rd_data_oo;
    assign mem1_regs_wen_o  = mem1_regs_wen_oo;

    // mem1
    always@(*) begin
        mem1_req_load_o         = mem_req_load_i;
        mem1_rd_addr_oo         = rd_addr_i;
        mem1_rd_data_oo         = rd_data_i;
        mem1_regs_wen_oo        = (mem_req_load_i) ? 1'b0 : regs_wen;
    end

    // mem1_mem2
    always @(posedge clk) begin
        if (!rst) begin
            mem2_req_load_i       <= 0;
            mem2_rd_addr_i        <= 0;
            mem2_rd_data_i        <= 0;
            mem2_regs_wen_i       <= 0;
        end
        else begin
            mem2_req_load_i       <= mem1_req_load_o;
            mem2_rd_addr_i        <= mem1_rd_addr_oo;
            mem2_rd_data_i        <= mem1_rd_data_oo;
            mem2_regs_wen_i       <= mem1_regs_wen_oo;
        end
    end

    // mem2
    always@(*) begin
        mem2_rd_addr_o       = mem2_rd_addr_i;
        mem2_rd_data_o       = mem2_rd_data_i;
        mem2_regs_wen_o      = mem2_regs_wen_i;
        mem2_is_load_o       = mem2_req_load_i;
    end
endmodule