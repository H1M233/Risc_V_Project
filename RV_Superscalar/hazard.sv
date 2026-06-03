module hazard(
    input  logic        clk,
    // from id_slot0
    input  logic [4:0]  slot0_id_rs1_addr_i,
    input  logic [4:0]  slot0_id_rs2_addr_i,
    input  logic [4:0]  slot0_id_rd_addr_i,
    
    // from id_slot1
    input  logic [4:0]  slot1_id_rs1_addr_i,
    input  logic [4:0]  slot1_id_rs2_addr_i,
    input  logic        slot1_id_regs_wen_i,
    input  logic        slot1_id_is_load_i,

    // from ex
    input  logic [4:0]  ex_rd_addr_i,
    input  logic        ex_is_load_i,

    // from mem1
    input  logic [4:0]  mem1_rd_addr_i,
    input  logic        mem1_is_load_i,

    output logic        hazard_en,
    output logic        dual_stall,
    output logic        dual_stall_r
);
    // Hazard - 只在 slot0 发射 load 指令
    wire rs1_hit_ex   = (ex_rd_addr_i == slot0_id_rs1_addr_i);
    wire rs2_hit_ex   = (ex_rd_addr_i == slot0_id_rs2_addr_i);
    wire id_need_ex   = ex_is_load_i & (rs1_hit_ex | rs2_hit_ex);

    wire rs1_hit_mem1 = (mem1_rd_addr_i == slot0_id_rs1_addr_i);
    wire rs2_hit_mem1 = (mem1_rd_addr_i == slot0_id_rs2_addr_i);
    wire id_need_mem1 = mem1_is_load_i & (rs1_hit_mem1 | rs2_hit_mem1);

    assign hazard_en = id_need_ex | id_need_mem1;

    // Hazard only for slot1 - slot1 依赖 slot0 内容 / slot0 & slot1 都为 load
    wire slot1_dep_slot0 = slot1_id_regs_wen_i && (slot1_id_rs1_addr_i == slot0_id_rd_addr_i || slot1_id_rs2_addr_i == slot0_id_rd_addr_i);
    assign dual_stall = (slot1_dep_slot0 || slot1_id_is_load_i) && !dual_stall_r;
    always_ff @(posedge clk) dual_stall_r <= dual_stall;
endmodule