`include "rv32I.svh"
`include "alu_def.svh"

module RF(
    input  logic                        clk             ,
    input  logic                        rst             ,

    // from wb
    input  RF_data_t                    data_pkg_i      ,

    `ifdef ENABLE_F
    input  logic [`RF_IDX_WIDTH - 1:0]  rs3_addr_i      ,
    output logic [31:0]                 rs3_data_o      ,
    `endif

    // from id
    input  logic [`RF_IDX_WIDTH - 1:0]  rs1_addr_i      ,
    input  logic [`RF_IDX_WIDTH - 1:0]  rs2_addr_i      ,

    // to id
    output logic [31:0]                 rs1_data_o      ,
    output logic [31:0]                 rs2_data_o      
);
    // 64 个 32 位寄存器 - 高 32 为浮点寄存器
    reg [31:0] RF_p1 [0:`RF_NUM - 1];
    reg [31:0] RF_p2 [0:`RF_NUM - 1];

    // 初始化
    initial begin
        for (int i = 0; i < `RF_NUM; i++) begin
            RF_p1[i] = 32'b0;
            RF_p2[i] = 32'b0;
        end
    end

    // 读寄存器
    assign rs1_data_o = (rs1_addr_i) ? RF_p1[rs1_addr_i] : 32'b0;
    assign rs2_data_o = (rs2_addr_i) ? RF_p2[rs2_addr_i] : 32'b0;
    `ifdef ENABLE_F
    assign rs3_data_o = RF_p2[rs3_addr_i];
    `endif

    // 写寄存器
    wire                    rd_wen   = data_pkg_i.regs_wen;
    wire [`RF_IDX_WIDTH:0]  rd_addr  = data_pkg_i.rd_addr;
    wire [31:0]             rd_wdata = data_pkg_i.rd_data;
    always_ff @(posedge clk) begin
        if (rd_wen) begin
            RF_p1[rd_addr] <= rd_wdata;
            RF_p2[rd_addr] <= rd_wdata;
        end
    end
endmodule