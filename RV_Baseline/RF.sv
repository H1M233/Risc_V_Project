`include "rv32I.svh"

module RF(
    input  logic            clk             ,
    input  logic            rst             ,

    // from wb
    input  RF_data_t        data_pkg_i      ,

    `ifdef ENABLE_F
    input  logic [5:0]      rs3_addr_i      ,
    output logic [31:0]     rs3_data_o      ,
    `endif

    // from id
    input  logic [5:0]      rs1_addr_i      ,
    input  logic [5:0]      rs2_addr_i      ,

    // to id
    output logic [31:0]     rs1_data_o      ,
    output logic [31:0]     rs2_data_o      
);
    // 64 个 32 位寄存器 - 高 32 为浮点寄存器
    reg [31:0] regs_p1 [0:63];
    reg [31:0] regs_p2 [0:63];

    // 初始化
    initial begin
        for (int i = 0; i < 64; i++) begin
            regs_p1[i] = 32'b0;
            regs_p2[i] = 32'b0;
        end
    end

    // 读寄存器
    assign rs1_data_o = regs_p1[rs1_addr_i];
    assign rs2_data_o = regs_p2[rs2_addr_i];
    `ifdef ENABLE_F
    assign rs3_data_o = regs_p2[rs3_addr_i];
    `endif

    // 写寄存器
    wire        rd_wen   = data_pkg_i.regs_wen;
    wire [5:0]  rd_addr  = data_pkg_i.rd_addr;
    wire [31:0] rd_wdata = data_pkg_i.rd_data;
    always_ff @(posedge clk) begin
        if (rd_wen) begin
            regs_p1[rd_addr] <= rd_wdata;
            regs_p2[rd_addr] <= rd_wdata;
        end
    end
endmodule