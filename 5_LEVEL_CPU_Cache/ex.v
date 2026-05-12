`include "rv32I.vh"
`include "alu.vh"

module ex(
    // from id_ex
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
    input      [8:0]    opcode_packged_i,
    (* max_fanout = 20 *)
    input               valid_i,

    // from mem
    input      [4:0]    mem_forward_rd_addr_i,
    input      [31:0]   mem_forward_rd_data_i,
    input               mem_forward_regs_wen_i,
    input      [6:0]    mem_forward_opcode_i,

    // from wb
    input      [4:0]    wb_forward_rd_addr_i,
    input      [31:0]   wb_forward_rd_data_i,
    input               wb_forward_regs_wen_i,

    // to hazard
    output reg [6:0]    hazard_opcode,

    // to ex_mem
    output reg [31:0]   inst_o,
    output reg          regs_wen_o,

    // to ex_mem & hazard   
    output reg [4:0]    rd_addr_o,
    (* max_fanout = 20 *)
    output reg [31:0]   rd_data_o,
    output reg          mem_req_load_o,

    // to jump
    output reg [31:0]   jump_addr_o,
    output reg          jump_en,

    // to bpu
    output reg          update_btb_en,
    output reg          update_gshare_en,
    (* max_fanout = 20 *)
    output reg [31:0]   pc_addr_o,
    output reg [31:0]   update_target,
    output reg          actual_taken,
    output reg          pred_mispredict,

    // to dcache
    output reg          dcache_req_load,
    output reg          dcache_req_store,
    output reg [1:0]    dcache_mask,
    output reg [31:0]   dcache_addr,
    output reg [31:0]   dcache_wdata
);
    (* max_fanout = 20 *)
    wire [6:0] opcode_raw = inst_i[6:0];
    (* max_fanout = 20 *)
    wire [2:0] funct3     = inst_i[14:12];
    (* max_fanout = 20 *)
    wire [6:0] funct7     = inst_i[31:25];

    // 主操作码独热
    (* max_fanout = 20 *) wire is_alu_i  = valid_i & opcode_packged_i[`OP_I];
    (* max_fanout = 20 *) wire is_alu_r  = valid_i & opcode_packged_i[`OP_R];
    (* max_fanout = 20 *) wire is_auipc  = valid_i & opcode_packged_i[`OP_AUIPC];
    (* max_fanout = 20 *) wire is_lui    = valid_i & opcode_packged_i[`OP_LUI];
    (* max_fanout = 20 *) wire is_jal    = valid_i & opcode_packged_i[`OP_JAL];
    (* max_fanout = 20 *) wire is_jalr   = valid_i & opcode_packged_i[`OP_JALR];
    (* max_fanout = 20 *) wire is_branch = valid_i & opcode_packged_i[`OP_BRANCH];
    (* max_fanout = 20 *) wire is_load   = valid_i & opcode_packged_i[`OP_LOAD];
    (* max_fanout = 20 *) wire is_store  = valid_i & opcode_packged_i[`OP_STORE];

    // funct3
    (* max_fanout = 20 *) wire f3_000 = (funct3 == 3'b000); // ADD/SUB, ADDI, LB, SB
    (* max_fanout = 20 *) wire f3_001 = (funct3 == 3'b001); // SLL, SLLI, LH, SH
    (* max_fanout = 20 *) wire f3_010 = (funct3 == 3'b010); // SLT, SLTI, LW, SW
    (* max_fanout = 20 *) wire f3_011 = (funct3 == 3'b011); // SLTU, SLTIU
    (* max_fanout = 20 *) wire f3_100 = (funct3 == 3'b100); // XOR, XORI, LBU
    (* max_fanout = 20 *) wire f3_101 = (funct3 == 3'b101); // SRL/SRA, SRLI/SRAI, LHU
    (* max_fanout = 20 *) wire f3_110 = (funct3 == 3'b110); // OR, ORI
    (* max_fanout = 20 *) wire f3_111 = (funct3 == 3'b111); // AND, ANDI

    // funct7
    (* max_fanout = 20 *) wire f7_0000000 = (funct7 == 7'b0000000);
    (* max_fanout = 20 *) wire f7_0100000 = (funct7 == 7'b0100000);

    // I-type
    (* max_fanout = 20 *) wire sel_addi  = is_alu_i & f3_000;
    (* max_fanout = 20 *) wire sel_slti  = is_alu_i & f3_010;
    (* max_fanout = 20 *) wire sel_sltiu = is_alu_i & f3_011;
    (* max_fanout = 20 *) wire sel_xori  = is_alu_i & f3_100;
    (* max_fanout = 20 *) wire sel_ori   = is_alu_i & f3_110;
    (* max_fanout = 20 *) wire sel_andi  = is_alu_i & f3_111;
    (* max_fanout = 20 *) wire sel_slli  = is_alu_i & f3_001;
    (* max_fanout = 20 *) wire sel_srli  = is_alu_i & f3_101 & f7_0000000;
    (* max_fanout = 20 *) wire sel_srai  = is_alu_i & f3_101 & f7_0100000;

    // R-type
    (* max_fanout = 20 *) wire sel_add   = is_alu_r & f3_000 & f7_0000000;
    (* max_fanout = 20 *) wire sel_sub   = is_alu_r & f3_000 & f7_0100000;
    (* max_fanout = 20 *) wire sel_sll   = is_alu_r & f3_001;
    (* max_fanout = 20 *) wire sel_slt   = is_alu_r & f3_010;
    (* max_fanout = 20 *) wire sel_sltu  = is_alu_r & f3_011;
    (* max_fanout = 20 *) wire sel_xor   = is_alu_r & f3_100;
    (* max_fanout = 20 *) wire sel_srl   = is_alu_r & f3_101 & f7_0000000;
    (* max_fanout = 20 *) wire sel_sra   = is_alu_r & f3_101 & f7_0100000;
    (* max_fanout = 20 *) wire sel_or    = is_alu_r & f3_110;
    (* max_fanout = 20 *) wire sel_and   = is_alu_r & f3_111;

    // Load & Store
    (* max_fanout = 20 *) wire sel_lb    = is_load & f3_000;
    (* max_fanout = 20 *) wire sel_lh    = is_load & f3_001;
    (* max_fanout = 20 *) wire sel_lw    = is_load & f3_010;
    (* max_fanout = 20 *) wire sel_lbu   = is_load & f3_100;
    (* max_fanout = 20 *) wire sel_lhu   = is_load & f3_101;
    (* max_fanout = 20 *) wire sel_sb    = is_store & f3_000;
    (* max_fanout = 20 *) wire sel_sh    = is_store & f3_001;
    (* max_fanout = 20 *) wire sel_sw    = is_store & f3_010;

    // 其它
    (* max_fanout = 20 *) wire sel_lui   = is_lui;
    (* max_fanout = 20 *) wire sel_auipc = is_auipc;
    (* max_fanout = 20 *) wire sel_jal   = is_jal;
    (* max_fanout = 20 *) wire sel_jalr  = is_jalr;

    (* max_fanout = 20 *)
    wire mem_can_forward =  (mem_forward_regs_wen_i) &&
                            (mem_forward_rd_addr_i != 5'b0) &&
                            (mem_forward_opcode_i != `TYPE_L);

    (* max_fanout = 20 *)
    wire wb_can_forward =   (wb_forward_regs_wen_i) &&
                            (wb_forward_rd_addr_i != 5'b0);

    (* max_fanout = 20 *)
    wire rs1_mem_hit =  (mem_can_forward) &&
                        (mem_forward_rd_addr_i == rs1_addr_i);

    (* max_fanout = 20 *)
    wire rs2_mem_hit =  (mem_can_forward) &&
                        (mem_forward_rd_addr_i == rs2_addr_i);

    (* max_fanout = 20 *)
    wire rs1_wb_hit  =  (wb_can_forward) &&
                        (wb_forward_rd_addr_i == rs1_addr_i);

    (* max_fanout = 20 *)
    wire rs2_wb_hit  =  (wb_can_forward) &&
                        (wb_forward_rd_addr_i == rs2_addr_i);

    (* max_fanout = 20 *)
    wire [31:0] rs1_fwd_data =  (rs1_mem_hit) ? mem_forward_rd_data_i :
                                (rs1_wb_hit)  ? wb_forward_rd_data_i  : 
                                                rs1_data_i;

    (* max_fanout = 20 *)
    wire [31:0] rs2_fwd_data =  (rs2_mem_hit) ? mem_forward_rd_data_i :
                                (rs2_wb_hit)  ? wb_forward_rd_data_i  :
                                                rs2_data_i;

    // Branch/JALR 正确性由 hazard 显式 stall 保证。
    // 不在分支比较链路上再接复杂 EX/MEM/WB 转发，避免关键路径变长。
    (* max_fanout = 20 *)
    wire [31:0] branch_rs1_data = rs1_data_i;
    (* max_fanout = 20 *)
    wire [31:0] branch_rs2_data = rs2_data_i;
    (* max_fanout = 20 *)
    wire [31:0] jalr_rs1_data   = rs1_data_i;

    (* max_fanout = 20 *)
    wire uses_rs1_as_value1 =   is_alu_r ||
                                is_alu_i ||
                                is_load ||
                                is_store ||
                                is_branch;

    (* max_fanout = 20 *)
    wire uses_rs2_as_value2 =   is_alu_r || is_branch;

    (* max_fanout = 20 *)
    wire [31:0] value1_eff = (uses_rs1_as_value1) ? rs1_fwd_data : value1_i;
    (* max_fanout = 20 *)
    wire [31:0] value2_eff = (uses_rs2_as_value2) ? rs2_fwd_data : value2_i;

    (* max_fanout = 20 *)
    wire [4:0] shamt = value2_eff[4:0];

    (* max_fanout = 20 *)
    wire [31:0] add_res       = value1_eff + value2_eff;
    (* max_fanout = 20 *)
    wire [31:0] sub_res       = value1_eff - value2_eff;
    (* max_fanout = 20 *)
    wire [31:0] mem_addr_calc = rs1_fwd_data + value2_i;
    (* max_fanout = 20 *)
    wire [31:0] branch_target = jump1_i + jump2_i;
    (* max_fanout = 20 *)
    wire [31:0] jalr_target   = jalr_rs1_data + jump2_i;
    (* max_fanout = 20 *)
    wire [31:0] pc_plus4      = pc_addr_i + 32'd4;

    wire        ltu_res       = (value1_eff < value2_eff);
    wire        sign_diff     = (value1_eff[31] ^ value2_eff[31]);
    wire        lts_res       = (sign_diff) ? value1_eff[31] : (value1_eff[30:0] < value2_eff[30:0]);

    wire        branch_eq_res    = (branch_rs1_data == branch_rs2_data);
    wire        branch_ltu_res   = (branch_rs1_data < branch_rs2_data);
    wire        branch_sign_diff = (branch_rs1_data[31] ^ branch_rs2_data[31]);
    wire        branch_lts_res   = (branch_sign_diff) ? branch_rs1_data[31] :
                                                        (branch_rs1_data[30:0] < branch_rs2_data[30:0]);

    wire [31:0] xor_res     = value1_eff ^ value2_eff;
    wire [31:0] or_res      = value1_eff | value2_eff;
    wire [31:0] and_res     = value1_eff & value2_eff;
    wire [31:0] sll_res     = value1_eff << shamt;
    wire [31:0] srl_res     = value1_eff >> shamt;
    wire [31:0] sra_res     = $signed(value1_eff) >>> shamt;

    (* max_fanout = 20 *)
    reg branch_taken;

    always @(*) begin
        case (funct3)
            `BEQ:    branch_taken = branch_eq_res;
            `BNE:    branch_taken = ~branch_eq_res;
            `BLT:    branch_taken = branch_lts_res;
            `BGE:    branch_taken = ~branch_lts_res;
            `BLTU:   branch_taken = branch_ltu_res;
            `BGEU:   branch_taken = ~branch_ltu_res;
            default: branch_taken = 1'b0;
        endcase
    end

    (* max_fanout = 20 *)
    wire        branch_pred_mispredict = is_branch && (pred_taken_i != branch_taken);
    (* max_fanout = 20 *)
    wire        jalr_pred_mispredict   = is_jalr && ((!pred_taken_i) || (pred_pc_i != jalr_target));

    (* max_fanout = 20 *)
    wire        branch_jump_en         = branch_pred_mispredict;
    (* max_fanout = 20 *)
    wire        jalr_jump_en           = jalr_pred_mispredict;

    (* max_fanout = 20 *)
    wire [31:0] branch_jump_addr       = branch_taken ? branch_target : pc_plus4;

    wire [31:0] resolved_jump_addr     = jalr_jump_en   ? jalr_target      :
                                         branch_jump_en ? branch_jump_addr :
                                                          32'b0;

    wire        resolved_jump_en       = branch_jump_en | jalr_jump_en;

    (* max_fanout = 20 *) wire [31:0] alu_result;
    (* max_fanout = 20 *) reg [31:0] alu_result_pre;

    // ALU 结果（TYPE_I 和 TYPE_R 公用一个预选）
    always @(*) begin
        alu_result_pre = 32'b0;

        (* parallel_case, full_case *)
        case (1'b1)
            sel_addi:  alu_result_pre = add_res;
            sel_slti:  alu_result_pre = {31'b0, lts_res};
            sel_sltiu: alu_result_pre = {31'b0, ltu_res};
            sel_xori:  alu_result_pre = xor_res;
            sel_ori:   alu_result_pre = or_res;
            sel_andi:  alu_result_pre = and_res;
            sel_slli:  alu_result_pre = sll_res;
            sel_srli:  alu_result_pre = srl_res;
            sel_srai:  alu_result_pre = sra_res;

            sel_add:   alu_result_pre = add_res;
            sel_sub:   alu_result_pre = sub_res;
            sel_sll:   alu_result_pre = sll_res;
            sel_slt:   alu_result_pre = {31'b0, lts_res};
            sel_sltu:  alu_result_pre = {31'b0, ltu_res};
            sel_xor:   alu_result_pre = xor_res;
            sel_srl:   alu_result_pre = srl_res;
            sel_sra:   alu_result_pre = sra_res;
            sel_or:    alu_result_pre = or_res;
            sel_and:   alu_result_pre = and_res;

            sel_lui:   alu_result_pre = add_res;
            sel_auipc: alu_result_pre = add_res;
            sel_jal:   alu_result_pre = add_res;
            sel_jalr:  alu_result_pre = add_res;
            default:   alu_result_pre = 32'b0;
        endcase
    end

    assign alu_result = alu_result_pre;

    always @(*) begin
        // 默认值
        pc_addr_o           = pc_addr_i;
        regs_wen_o          = valid_i ? regs_wen_i : 1'b0;
        rd_data_o           = 32'b0;
        rd_addr_o           = rd_addr_i;
        mem_req_load_o      = valid_i && (opcode_raw == `TYPE_L);

        jump_en             = 1'b0;
        jump_addr_o         = 32'b0;

        hazard_opcode       = valid_i ? opcode_raw : `TYPE_I;
        inst_o              = valid_i ? inst_i : `NOP;

        update_btb_en       = 1'b0;
        update_gshare_en    = 1'b0;
        update_target       = 32'b0;
        actual_taken        = 1'b0;
        pred_mispredict     = 1'b0;

        dcache_req_load     = valid_i && (opcode_raw == `TYPE_L);
        dcache_req_store    = valid_i && (opcode_raw == `TYPE_S);
        dcache_mask         = 2'b0;
        dcache_addr         = mem_addr_calc;
        dcache_wdata        = rs2_fwd_data;

        // 数据回写: ALU & 立即数 & 跳转
        if (valid_i) begin
            if (is_lui | is_auipc | is_jal | is_jalr | is_alu_i | is_alu_r) begin
                rd_data_o = alu_result;
            end
        end

        // 分支 & 跳转 控制
        if (is_branch) begin
            update_gshare_en = valid_i;
            actual_taken     = branch_taken;
            pred_mispredict  = branch_pred_mispredict;
            jump_en          = branch_jump_en;
            jump_addr_o      = branch_jump_addr;
        end
        if (is_jalr) begin
            update_btb_en   = valid_i;
            update_target   = jalr_target;
            pred_mispredict = jalr_pred_mispredict;
            jump_en         = resolved_jump_en;
            jump_addr_o     = resolved_jump_addr;
        end

        // DCACHE 控制: load & store
        (* parallel_case, full_case *)
        case (1'b1)
            sel_lb:  dcache_mask = 2'b00;
            sel_lh:  dcache_mask = 2'b01;
            sel_lw:  dcache_mask = 2'b10;
            sel_lbu: dcache_mask = 2'b00;
            sel_lhu: dcache_mask = 2'b01;
            sel_sb:  dcache_mask = 2'b00;
            sel_sh:  dcache_mask = 2'b01;
            sel_sw:  dcache_mask = 2'b10;
            default: dcache_mask = 2'b00;
        endcase
    end
endmodule