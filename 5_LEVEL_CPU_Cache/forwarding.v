module forwarding(
    // from id
    input [4:0]     id_rs1_addr_i,
    input [4:0]     id_rs2_addr_i,
    input [31:0]    id_rs1_data_i,
    input [31:0]    id_rs2_data_i,

    // from ex
    input           ex_regs_wen_i,
    input [4:0]     ex_rd_addr_i,
    input [31:0]    ex_rd_data_i,

    // from mem
    input           mem_regs_wen_i,
    input [4:0]     mem_rd_addr_i,
    input [31:0]    mem_rd_data_i,

    // from wb
    input           wb_regs_wen_i,
    input [4:0]     wb_rd_addr_i,
    input [31:0]    wb_rd_data_i,

    // to id_ex
    (* max_fanout = 10 *)
    output reg        forwarding_rs1_hit_ex_o,      // ex 寄存后转发，在 ex 内部再做判断
    (* max_fanout = 10 *)
    output reg        forwarding_rs2_hit_ex_o,
    (* max_fanout = 10 *)
    output reg [31:0] forwarding_rs1_data_o,
    (* max_fanout = 10 *)
    output reg [31:0] forwarding_rs2_data_o,
    (* max_fanout = 10 *)
    output reg [31:0] forwarding_ex_rd_data_o
);
    wire rs1_addr_write_available = (id_rs1_addr_i != 5'b0);
    wire rs2_addr_write_available = (id_rs2_addr_i != 5'b0);

    wire forwarding_rs1_ex  = (id_rs1_addr_i == ex_rd_addr_i) & ex_regs_wen_i & rs1_addr_write_available;
    wire forwarding_rs1_mem = (id_rs1_addr_i == mem_rd_addr_i) & mem_regs_wen_i & rs1_addr_write_available;
    wire forwarding_rs1_wb  = (id_rs1_addr_i == wb_rd_addr_i) & wb_regs_wen_i & rs1_addr_write_available;

    wire forwarding_rs2_ex  = (id_rs2_addr_i == ex_rd_addr_i) & ex_regs_wen_i & rs2_addr_write_available;
    wire forwarding_rs2_mem = (id_rs2_addr_i == mem_rd_addr_i) & mem_regs_wen_i & rs2_addr_write_available;
    wire forwarding_rs2_wb  = (id_rs2_addr_i == wb_rd_addr_i) & wb_regs_wen_i & rs2_addr_write_available;

    wire [31:0] forwarding_rs1_data_comb =  (forwarding_rs1_mem) ? mem_rd_data_i :
                                            (forwarding_rs1_wb) ? wb_rd_data_i :
                                            id_rs1_data_i;
    wire [31:0] forwarding_rs2_data_comb =  (forwarding_rs2_mem) ? mem_rd_data_i :
                                            (forwarding_rs2_wb) ? wb_rd_data_i :
                                            id_rs2_data_i;

    always @(*) begin
        forwarding_rs1_hit_ex_o = forwarding_rs1_ex;
        forwarding_rs2_hit_ex_o = forwarding_rs2_ex;
        forwarding_rs1_data_o   = forwarding_rs1_data_comb;
        forwarding_rs2_data_o   = forwarding_rs2_data_comb;
        forwarding_ex_rd_data_o = ex_rd_data_i;
    end
endmodule