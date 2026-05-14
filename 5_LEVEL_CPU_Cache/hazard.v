`include "rv32I.vh"

module hazard(
    input      [4:0]    ex_waddr_i,
    input               ex_is_load,
    input               ex_regs_wen_i,

    input      [6:0]    id_opcode_i,
    input      [4:0]    id_rs1_raddr_i,
    input      [4:0]    id_rs2_raddr_i,

    input      [4:0]    mem_waddr_i,
    input               mem_regs_wen_i,

    (* max_fanout = 30 *)
    output reg          hazard_en
);

    wire rs1_hit_ex;
    wire rs2_hit_ex;
    wire id_is_branch;
    wire id_is_jalr;
    wire rs1_wait_ex;
    wire rs2_wait_ex;
    wire rs1_wait_mem;
    wire rs2_wait_mem;
    wire ctrl_dep_wait;

    assign id_is_branch = id_opcode_i == `TYPE_B;
    assign id_is_jalr   = id_opcode_i == `JALR;

    assign rs1_hit_ex = (ex_waddr_i != 5'b0) &&
                        (ex_waddr_i == id_rs1_raddr_i);

    assign rs2_hit_ex = (ex_waddr_i != 5'b0) &&
                        (ex_waddr_i == id_rs2_raddr_i);

    assign rs1_wait_ex = ex_regs_wen_i && rs1_hit_ex;
    assign rs2_wait_ex = ex_regs_wen_i && rs2_hit_ex;

    assign rs1_wait_mem = mem_regs_wen_i &&
                          (mem_waddr_i != 5'b0) &&
                          (mem_waddr_i == id_rs1_raddr_i);

    assign rs2_wait_mem = mem_regs_wen_i &&
                          (mem_waddr_i != 5'b0) &&
                          (mem_waddr_i == id_rs2_raddr_i);

    assign ctrl_dep_wait = 0 &
            (id_is_branch && (rs1_wait_ex || rs2_wait_ex || rs1_wait_mem || rs2_wait_mem)) ||
            (id_is_jalr   && (rs1_wait_ex || rs1_wait_mem));

    always @(*) begin
        // hazard_en = (ex_is_load && (rs1_hit_ex || rs2_hit_ex)) || ctrl_dep_wait;
        hazard_en = (ex_is_load & (rs1_hit_ex | rs2_hit_ex));
    end

endmodule
