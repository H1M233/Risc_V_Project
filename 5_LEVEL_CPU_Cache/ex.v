`include "rv32I.vh"
`include "alu.vh"

module ex(
    // from id_ex
    input      [31:0]           pc_addr_i,
    input      [31:0]           inst_i,
    input      [31:0]           jump1_i,
    input      [31:0]           jump2_i,
    input      [4:0]            rd_addr_i,
    input                       regs_wen_i,
    (* max_fanout = 20 *)
    input      [31:0]           value1_i,
    (* max_fanout = 20 *)
    input      [31:0]           value2_i,
    input                       pred_taken_i,
    input      [31:0]           pred_pc_i,
    input      [`OP_INST_NUM - 1:0]  inst_packaged_i,
    (* max_fanout = 20 *)
    input                       valid_i,

    // from fowarding - fanout set
    (* max_fanout = 15 *)
    input      [31:0]   fwd_rs1_data_i,
    (* max_fanout = 15 *)
    input      [31:0]   fwd_rs2_data_i,
    (* max_fanout = 20 *)
    input               fwd_rs1_hit_ex_i,
    (* max_fanout = 20 *)
    input               fwd_rs2_hit_ex_i,
    (* max_fanout = 20 *)
    input      [31:0]   fwd_ex_rd_data_i,

    // to ex_mem
    output reg [31:0]   inst_o,
    output reg          regs_wen_o,
    output reg [4:0]    load_packaged_o,

    // to ex_mem & hazard   
    output reg [4:0]    rd_addr_o,
    (* max_fanout = 20 *)
    output reg [31:0]   rd_data_o,
    output reg          mem_req_load_o,

    // to jump
    (* max_fanout = 20 *)
    output reg [31:0]   jump_addr_o,
    (* max_fanout = 20 *)
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

    // 主操作码独热
    (* max_fanout = 20 *) wire is_alu_i  = inst_packaged_i[`OP_I];
    (* max_fanout = 20 *) wire is_alu_r  = inst_packaged_i[`OP_R];
    (* max_fanout = 20 *) wire is_auipc  = inst_packaged_i[`OP_AUIPC];
    (* max_fanout = 20 *) wire is_lui    = inst_packaged_i[`OP_LUI];
    (* max_fanout = 20 *) wire is_jal    = inst_packaged_i[`OP_JAL];
    (* max_fanout = 20 *) wire is_jalr   = inst_packaged_i[`OP_JALR];
    (* max_fanout = 20 *) wire is_branch = inst_packaged_i[`OP_BRANCH];
    (* max_fanout = 20 *) wire is_load   = inst_packaged_i[`OP_LOAD];
    (* max_fanout = 20 *) wire is_store  = inst_packaged_i[`OP_STORE];

    // I-type
    (* max_fanout = 20 *) wire sel_addi  = inst_packaged_i[`INST_ADDI];
    (* max_fanout = 20 *) wire sel_xori  = inst_packaged_i[`INST_XORI];
    (* max_fanout = 20 *) wire sel_ori   = inst_packaged_i[`INST_ORI];
    (* max_fanout = 20 *) wire sel_andi  = inst_packaged_i[`INST_ANDI];
    (* max_fanout = 20 *) wire sel_slli  = inst_packaged_i[`INST_SLLI];
    (* max_fanout = 20 *) wire sel_srli  = inst_packaged_i[`INST_SRLI];
    (* max_fanout = 20 *) wire sel_srai  = inst_packaged_i[`INST_SRAI];
    (* max_fanout = 20 *) wire sel_slti  = inst_packaged_i[`INST_SLTI];
    (* max_fanout = 20 *) wire sel_sltiu = inst_packaged_i[`INST_SLTIU];

    // R-type
    (* max_fanout = 20 *) wire sel_add   = inst_packaged_i[`INST_ADD];
    (* max_fanout = 20 *) wire sel_sub   = inst_packaged_i[`INST_SUB];
    (* max_fanout = 20 *) wire sel_xor   = inst_packaged_i[`INST_XOR];
    (* max_fanout = 20 *) wire sel_or    = inst_packaged_i[`INST_OR];
    (* max_fanout = 20 *) wire sel_and   = inst_packaged_i[`INST_AND];
    (* max_fanout = 20 *) wire sel_sll   = inst_packaged_i[`INST_SLL];
    (* max_fanout = 20 *) wire sel_srl   = inst_packaged_i[`INST_SRL];
    (* max_fanout = 20 *) wire sel_sra   = inst_packaged_i[`INST_SRA];
    (* max_fanout = 20 *) wire sel_slt   = inst_packaged_i[`INST_SLT];
    (* max_fanout = 20 *) wire sel_sltu  = inst_packaged_i[`INST_SLTU];

    // Load & Store
    (* max_fanout = 20 *) wire sel_lb    = inst_packaged_i[`INST_LB];
    (* max_fanout = 20 *) wire sel_lh    = inst_packaged_i[`INST_LH];
    (* max_fanout = 20 *) wire sel_lw    = inst_packaged_i[`INST_LW];
    (* max_fanout = 20 *) wire sel_lbu   = inst_packaged_i[`INST_LBU];
    (* max_fanout = 20 *) wire sel_lhu   = inst_packaged_i[`INST_LHU];
    (* max_fanout = 20 *) wire sel_sb    = inst_packaged_i[`INST_SB];
    (* max_fanout = 20 *) wire sel_sh    = inst_packaged_i[`INST_SH];
    (* max_fanout = 20 *) wire sel_sw    = inst_packaged_i[`INST_SW];

    // Branch
    (* max_fanout = 20 *) wire sel_beq  = inst_packaged_i[`INST_BEQ];
    (* max_fanout = 20 *) wire sel_bne  = inst_packaged_i[`INST_BNE];
    (* max_fanout = 20 *) wire sel_blt  = inst_packaged_i[`INST_BLT];
    (* max_fanout = 20 *) wire sel_bge  = inst_packaged_i[`INST_BGE];
    (* max_fanout = 20 *) wire sel_bltu = inst_packaged_i[`INST_BLTU];
    (* max_fanout = 20 *) wire sel_bgeu = inst_packaged_i[`INST_BGEU];

    // Branch/JALR 正确性由 hazard 显式 stall 保证。
    // 不在分支比较链路上再接复杂 EX/MEM/WB 转发，避免关键路径变长。
    wire [31:0] branch_rs1_data = value1_i;
    wire [31:0] branch_rs2_data = value2_i;
    wire [31:0] jalr_rs1_data   = jump1_i;

    // 前推选择
    (* max_fanout = 15 *) wire [31:0] rs1_data_fwd = (fwd_rs1_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs1_data_i;
    (* max_fanout = 15 *) wire [31:0] rs2_data_fwd = (fwd_rs2_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs2_data_i;

    wire [31:0] value1_eff = rs1_data_fwd;
    wire [31:0] value2_eff = rs2_data_fwd;

    // I 型计算
    wire [4:0]  shamti      = value2_i[4:0];
    wire [31:0] addi_res    = value1_eff + value2_i;
    wire [31:0] xori_res    = value1_eff ^ value2_i;
    wire [31:0] ori_res     = value1_eff | value2_i;
    wire [31:0] andi_res    = value1_eff & value2_i;
    wire [31:0] slli_res    = value1_eff << shamti;
    wire [31:0] srli_res    = value1_eff >> shamti;
    wire [31:0] srai_res    = $signed(value1_eff) >>> shamti;
    wire        ltui_res    = (value1_eff < value2_i);
    wire        sign_diffi  = (value1_eff[31] ^ value2_i[31]);
    wire        ltsi_res    = (sign_diffi) ? value1_eff[31] : (value1_eff[30:0] < value2_i[30:0]);

    // R 型计算
    wire [4:0]  shamt       = value2_eff[4:0];
    wire [31:0] add_res     = value1_eff + value2_eff;
    wire [31:0] sub_res     = value1_eff - value2_eff;
    wire [31:0] xor_res     = value1_eff ^ value2_eff;
    wire [31:0] or_res      = value1_eff | value2_eff;
    wire [31:0] and_res     = value1_eff & value2_eff;
    wire [31:0] sll_res     = value1_eff << shamt;
    wire [31:0] srl_res     = value1_eff >> shamt;
    wire [31:0] sra_res     = $signed(value1_eff) >>> shamt;
    wire        ltu_res     = (value1_eff < value2_eff);
    wire        sign_diff   = (value1_eff[31] ^ value2_eff[31]);
    wire        lts_res     = (sign_diff) ? value1_eff[31] : (value1_eff[30:0] < value2_eff[30:0]);

    // 非寄存器内容计算
    wire [31:0] add_res_nrs = value1_i + value2_i;

    // 地址计算
    wire [31:0] mem_addr_calc = value1_eff + value2_i;
    wire [31:0] branch_target = jump1_i + jump2_i;
    wire [31:0] jalr_target   = jalr_rs1_data + jump2_i;
    wire [31:0] pc_plus4      = pc_addr_i + 32'd4;

    // 分支计算
    wire branch_eq_res    = (branch_rs1_data == branch_rs2_data);
    wire branch_ltu_res   = (branch_rs1_data < branch_rs2_data);
    wire branch_sign_diff = (branch_rs1_data[31] ^ branch_rs2_data[31]);
    wire branch_lts_res   = (branch_sign_diff) ? branch_rs1_data[31] : (branch_rs1_data[30:0] < branch_rs2_data[30:0]);

    // Branch 计算
    reg branch_taken;
    always @(*) begin: ALU_Branch_Taken
        (* parallel_case, full_case *)
        case (1'b1)
            sel_beq:  branch_taken = branch_eq_res;
            sel_bne:  branch_taken = ~branch_eq_res;
            sel_blt:  branch_taken = branch_lts_res;
            sel_bge:  branch_taken = ~branch_lts_res;
            sel_bltu: branch_taken = branch_ltu_res;
            sel_bgeu: branch_taken = ~branch_ltu_res;
            default:  branch_taken = 1'b0;
        endcase
    end

    wire branch_pred_mispredict  = is_branch && (pred_taken_i != branch_taken);
    wire jalr_pred_mispredict    = is_jalr && ((!pred_taken_i) || (pred_pc_i != jalr_target));
    wire [31:0] branch_jump_addr = branch_taken ? branch_target : pc_plus4;

    // 分指令返回
    (* max_fanout = 20 *) reg [31:0] alu_result;
    always @(*) begin: ALU
        (* parallel_case, full_case *)
        case (1'b1)
            // I-type
            sel_addi:  alu_result = addi_res;
            sel_xori:  alu_result = xori_res;
            sel_ori:   alu_result = ori_res;
            sel_andi:  alu_result = andi_res;
            sel_slli:  alu_result = slli_res;
            sel_srli:  alu_result = srli_res;
            sel_srai:  alu_result = srai_res;
            sel_slti:  alu_result = {31'b0, ltsi_res};
            sel_sltiu: alu_result = {31'b0, ltui_res};

            // R-type
            sel_add:   alu_result = add_res;
            sel_sub:   alu_result = sub_res;
            sel_sll:   alu_result = sll_res;
            sel_slt:   alu_result = {31'b0, lts_res};
            sel_sltu:  alu_result = {31'b0, ltu_res};
            sel_xor:   alu_result = xor_res;
            sel_srl:   alu_result = srl_res;
            sel_sra:   alu_result = sra_res;
            sel_or:    alu_result = or_res;
            sel_and:   alu_result = and_res;

            // 地址类
            is_lui:    alu_result = value1_i;
            is_auipc:  alu_result = add_res_nrs;
            is_jal:    alu_result = add_res_nrs;
            is_jalr:   alu_result = add_res_nrs;
            default:   alu_result = 32'b0;
        endcase
    end

    // Dcache 控制
    always @(*) begin: ALU_Dcache
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

    // 跳转
    always @(*) begin: ALU_Branch_CTRL
        jump_en             = 1'b0;
        jump_addr_o         = 32'b0;
        update_btb_en       = 1'b0;
        update_gshare_en    = 1'b0;
        update_target       = 32'b0;
        actual_taken        = 1'b0;
        pred_mispredict     = 1'b0;

        // 分支 控制
        if (is_branch) begin
            update_gshare_en = valid_i;
            actual_taken     = branch_taken;
            pred_mispredict  = branch_pred_mispredict;
            jump_en          = branch_pred_mispredict;
            jump_addr_o      = branch_jump_addr;
        end

        // 跳转 / 返回 控制
        if (is_jalr) begin
            update_btb_en   = valid_i;
            update_target   = jalr_target;
            pred_mispredict = jalr_pred_mispredict;
            jump_en         = jalr_pred_mispredict;
            jump_addr_o     = jalr_target;
        end
    end

    // 跳转 & 读写
    always @(*) begin: ALU_WB
        // 数据穿透
        pc_addr_o           = pc_addr_i;
        inst_o              = (valid_i) ? inst_i : `NOP;

        regs_wen_o          = (valid_i) ? regs_wen_i : 1'b0;
        rd_data_o           = 32'b0;
        rd_addr_o           = rd_addr_i;
        mem_req_load_o      = is_load;

        // 转发 D-cache
        dcache_req_load     = is_load;
        dcache_req_store    = is_store;
        dcache_addr         = mem_addr_calc;
        dcache_wdata        = rs2_data_fwd;

        // 打包 Load
        load_packaged_o[`IS_LB]   = sel_lb;
        load_packaged_o[`IS_LH]   = sel_lh;
        load_packaged_o[`IS_LW]   = sel_lw;
        load_packaged_o[`IS_LBU]  = sel_lbu;
        load_packaged_o[`IS_LHU]  = sel_lhu;
        
        // 写回寄存器
        rd_data_o = alu_result;
    end
endmodule