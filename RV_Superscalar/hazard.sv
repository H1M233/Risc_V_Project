module hazard(
    // from id_slot0
    input  logic [4:0]  slot0_id_rs1_addr_i,
    input  logic [4:0]  slot0_id_rs2_addr_i,
    input  logic [4:0]  slot0_id_rd_addr_i,
    input  logic        slot0_id_regs_wen_i,
    
    // from id_slot1
    input  logic [4:0]  slot1_id_rs1_addr_i,
    input  logic [4:0]  slot1_id_rs2_addr_i,
    input  logic        slot1_using_rs_data_i,
    input  logic        slot1_id_is_load_i,
    input  logic        slot1_id_is_store_i,
    input  logic        slot1_id_is_zicsr_i,
    
    // from ex
    input  logic [4:0]  ex_rd_addr_i,
    input  logic        ex_is_load_i,
    
    // from mem1
    input  logic [4:0]  mem1_rd_addr_i,
    input  logic        mem1_is_load_i,
    
    output logic        hazard_en,
    output logic        dual_stall,
    input  logic        dual_stall_finish
);
    // Hazard - 只在 slot0 发射 load 指令
    wire slot0_rs1_hit_ex   = (ex_rd_addr_i == slot0_id_rs1_addr_i);
    wire slot0_rs2_hit_ex   = (ex_rd_addr_i == slot0_id_rs2_addr_i);
    wire slot1_rs1_hit_ex   = (ex_rd_addr_i == slot1_id_rs1_addr_i);
    wire slot1_rs2_hit_ex   = (ex_rd_addr_i == slot1_id_rs2_addr_i);
    wire id_need_ex   = ex_is_load_i && (slot0_rs1_hit_ex || slot0_rs2_hit_ex || slot1_rs1_hit_ex || slot1_rs2_hit_ex);

    wire slot0_rs1_hit_mem1 = (mem1_rd_addr_i == slot0_id_rs1_addr_i);
    wire slot0_rs2_hit_mem1 = (mem1_rd_addr_i == slot0_id_rs2_addr_i);
    wire slot1_rs1_hit_mem1 = (mem1_rd_addr_i == slot1_id_rs1_addr_i);
    wire slot1_rs2_hit_mem1 = (mem1_rd_addr_i == slot1_id_rs2_addr_i);
    wire id_need_mem1 = mem1_is_load_i && (slot0_rs1_hit_mem1 || slot0_rs2_hit_mem1 || slot1_rs1_hit_mem1 || slot1_rs2_hit_mem1);

    assign hazard_en = id_need_ex | id_need_mem1;

    // Hazard only for slot1 - slot1 依赖 slot0 内容 / slot1 为 load & store / slot1 为 csr 读写
    wire slot1_dep_slot0 = slot0_id_regs_wen_i && slot1_using_rs_data_i && (slot1_id_rs1_addr_i == slot0_id_rd_addr_i || slot1_id_rs2_addr_i == slot0_id_rd_addr_i);
    wire only_slot0_can_access_mem =  slot1_id_is_load_i || slot1_id_is_store_i;
    wire dual_csr = slot1_id_is_zicsr_i;
    assign dual_stall = (slot1_dep_slot0 || only_slot0_can_access_mem || dual_csr) && !dual_stall_finish;
endmodule