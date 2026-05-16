module forwarding(
    input           clk,
    input           rst,
    input           dcache_stall,

    // from id
    input [4:0]     id_rs1_addr_i,
    input [4:0]     id_rs2_addr_i,
    input [31:0]    id_rs1_data_i,
    input [31:0]    id_rs2_data_i,

    // from ex
    input           ex_regs_wen_i,
    input [4:0]     ex_rd_addr_i,
    input [31:0]    ex_rd_data_i,

    // from mem1
    input [4:0]     mem1_rd_addr_i,
    input [31:0]    mem1_rd_data_i,
    input           mem1_regs_wen_i,

    // from mem2
    input [4:0]     mem2_rd_addr_i,
    input [31:0]    mem2_rd_data_i,
    input           mem2_regs_wen_i,

    // from wb
    input [4:0]     wb_rd_addr_i,
    input [31:0]    wb_rd_data_i,
    input           wb_regs_wen_i,

    // to id_ex
    output reg        forwarding_rs1_hit_ex_o,      // ex 寄存后转发，在 ex 内部再做判断
    output reg        forwarding_rs2_hit_ex_o,
    (* max_fanout = 20 *)
    output reg [31:0] forwarding_rs1_data_o,
    (* max_fanout = 20 *)
    output reg [31:0] forwarding_rs2_data_o,
    output reg [31:0] forwarding_ex_rd_data_o
);
    wire forwarding_rs1_ex   = (id_rs1_addr_i == ex_rd_addr_i) & ex_regs_wen_i;
    wire forwarding_rs1_mem1 = (id_rs1_addr_i == mem1_rd_addr_i) & mem1_regs_wen_i;
    wire forwarding_rs1_mem2 = (id_rs1_addr_i == mem2_rd_addr_i) & mem2_regs_wen_i;
    wire forwarding_rs1_wb   = (id_rs1_addr_i == wb_rd_addr_i) & wb_regs_wen_i;

    wire forwarding_rs2_ex   = (id_rs2_addr_i == ex_rd_addr_i) & ex_regs_wen_i;
    wire forwarding_rs2_mem1 = (id_rs2_addr_i == mem1_rd_addr_i) & mem1_regs_wen_i;
    wire forwarding_rs2_mem2 = (id_rs2_addr_i == mem2_rd_addr_i) & mem2_regs_wen_i;
    wire forwarding_rs2_wb   = (id_rs2_addr_i == wb_rd_addr_i) & wb_regs_wen_i;

    wire [31:0] forwarding_rs1_data_hit =   (forwarding_rs1_mem1) ? mem1_rd_data_i :
                                            (forwarding_rs1_mem2) ? mem2_rd_data_i :
                                            (forwarding_rs1_wb)   ? wb_rd_data_i :
                                            id_rs1_data_i;
    wire [31:0] forwarding_rs2_data_hit =   (forwarding_rs2_mem1) ? mem1_rd_data_i :
                                            (forwarding_rs2_mem2) ? mem2_rd_data_i :
                                            (forwarding_rs2_wb)   ? wb_rd_data_i :
                                            id_rs2_data_i;

    always @(posedge clk) begin
        if (!rst) begin
            forwarding_rs1_hit_ex_o <= 0;
            forwarding_rs2_hit_ex_o <= 0;
            forwarding_rs1_data_o   <= 0;
            forwarding_rs2_data_o   <= 0;
            forwarding_ex_rd_data_o <= 0;
        end
        else if (!dcache_stall) begin
            forwarding_rs1_hit_ex_o <= forwarding_rs1_ex;
            forwarding_rs2_hit_ex_o <= forwarding_rs2_ex;
            forwarding_rs1_data_o   <= forwarding_rs1_data_hit;
            forwarding_rs2_data_o   <= forwarding_rs2_data_hit;
            forwarding_ex_rd_data_o <= ex_rd_data_i;
        end
    end
endmodule