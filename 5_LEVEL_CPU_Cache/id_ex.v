`include "rv32I.vh"

module id_ex(
    input               clk,
    input               rst,

    // from D-cache stall
    input               dcache_stall,

    input               jump_en,
    input               hazard_en,

    // from id
    input      [31:0]   pc_addr_i,
    input      [31:0]   inst_i,
    input      [31:0]   jump1_i,
    input      [31:0]   jump2_i,
    input      [4:0]    rd_addr_i,
    input               regs_wen_i,
    input      [31:0]   rs1_data_i,
    input      [31:0]   rs2_data_i,
    input      [4:0]    rs1_addr_i,
    input      [4:0]    rs2_addr_i,
    input      [31:0]   value1_i,
    input      [31:0]   value2_i,
    input               pred_taken_i,
    input      [31:0]   pred_pc_i,


    // to ex
    output reg [31:0]   pc_addr_o,
    output reg [31:0]   inst_o,
    output reg [31:0]   jump1_o,
    output reg [31:0]   jump2_o,
    output reg [4:0]    rd_addr_o,
    output reg          regs_wen_o,
    output reg [31:0]   rs1_data_o,
    output reg [31:0]   rs2_data_o,
    output reg [4:0]    rs1_addr_o,
    output reg [4:0]    rs2_addr_o,
    output reg [31:0]   value1_o,
    output reg [31:0]   value2_o,
    output reg          pred_taken_o,
    output reg [31:0]   pred_pc_o,
    output reg          valid_o
);
    wire flush_id_ex = jump_en | hazard_en;
    always @(posedge clk) begin
        if(!rst) begin
            pc_addr_o    <= 32'b0;
            regs_wen_o   <= 1'b0;
            inst_o       <= `NOP;
            value1_o     <= 32'b0;
            value2_o     <= 32'b0;
            jump1_o      <= 32'b0;
            jump2_o      <= 32'b0;
            rd_addr_o    <= 5'b0;
            rs1_data_o   <= 32'b0;
            rs2_data_o   <= 32'b0;
            rs1_addr_o   <= 5'b0;
            rs2_addr_o   <= 5'b0;
            valid_o      <= 1'b0;
        end
        else if(!dcache_stall) begin
            // 关键点：
            // jump_en 不再直接控制 inst_o/value1_o/value2_o 等宽寄存器，
            // 只控制 1 bit valid_o，从而切断 EX compare -> ID_EX.inst/value 的长路径。
            pc_addr_o    <= pc_addr_i;
            regs_wen_o   <= regs_wen_i;
            inst_o       <= inst_i;
            value1_o     <= value1_i;
            value2_o     <= value2_i;
            jump1_o      <= jump1_i;
            jump2_o      <= jump2_i;
            rd_addr_o    <= rd_addr_i;
            rs1_data_o   <= rs1_data_i;
            rs2_data_o   <= rs2_data_i;
            rs1_addr_o   <= rs1_addr_i;
            rs2_addr_o   <= rs2_addr_i;
            valid_o      <= ~flush_id_ex;
        end
    end

    // 特殊处理 pred_taken
    always @(posedge clk) begin
        if (!rst) begin
            pred_taken_o <= 1'b0;
            pred_pc_o    <= 32'b0;
        end
        else if (!dcache_stall & !hazard_en) begin
            pred_taken_o <= pred_taken_i;
            pred_pc_o    <= pred_pc_i;
        end
    end
endmodule