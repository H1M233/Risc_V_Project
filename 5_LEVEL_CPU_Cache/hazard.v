`include "rv32I.vh"

module hazard(
    input      [4:0]    ex_rd_addr_i,
    input               ex_is_load_i,

    input      [4:0]    mem1_rd_addr_i,
    input               mem1_is_load_i,

    input      [4:0]    id_rs1_raddr_i,
    input      [4:0]    id_rs2_raddr_i,

    (* max_fanout = 30 *)
    output reg          hazard_en
);

    wire rs1_hit_ex   = (ex_rd_addr_i == id_rs1_raddr_i);
    wire rs2_hit_ex   = (ex_rd_addr_i == id_rs2_raddr_i);

    wire rs1_hit_mem1 = (mem1_rd_addr_i == id_rs1_raddr_i);
    wire rs2_hit_mem1 = (mem1_rd_addr_i == id_rs2_raddr_i);

    wire id_need_ex   = ex_is_load_i & (rs1_hit_ex | rs2_hit_ex);
    wire id_need_mem1 = mem1_is_load_i & (rs1_hit_mem1 | rs2_hit_mem1);

    always @(*) begin
        hazard_en = id_need_ex | id_need_mem1;
    end

endmodule
