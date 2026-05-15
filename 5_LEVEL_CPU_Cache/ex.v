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
    input      [31:0]   fwd_rs1_data_i,
    input      [31:0]   fwd_rs2_data_i,
    input               fwd_rs1_hit_ex_i,
    input               fwd_rs2_hit_ex_i,
    input      [31:0]   fwd_ex_rd_data_i,

    // to ex_mem
    output reg          regs_wen_o,
    // output reg [4:0]    load_packaged_o,

    // to ex_mem & hazard   
    output reg [4:0]    rd_addr_o,
    (* max_fanout = 20 *)
    output reg [31:0]   rd_data_o,
    output reg          mem_req_load_o,

    // to jump
    (* max_fanout = 20 *)
    output reg          pred_flush_en,
    (* max_fanout = 20 *)
    output reg [31:0]   pred_flush_pc,

    // to bpu
    output reg          update_btb_en_o,
    output reg          update_gshare_en_o,
    (* max_fanout = 20 *)
    output reg [31:0]   update_pc_o,
    output reg [31:0]   update_target_o,
    output reg          actual_taken_o,

    // to dcache
    output reg          dcache_req_load,
    output reg          dcache_req_store,
    output reg [2:0]    dcache_mask,
    output reg [31:0]   dcache_addr,
    output reg [3:0]    dcache_addr_offset,
    output reg [31:0]   dcache_wdata,
    output reg          dcache_is_signed
);

    // 主操作码独热
    (* max_fanout = 20 *) wire is_alu_i  = inst_packaged_i[`OP_I];
    (* max_fanout = 20 *) wire is_alu_r  = inst_packaged_i[`OP_R];
    (* max_fanout = 20 *) wire is_auipc  = inst_packaged_i[`OP_AUIPC];
    (* max_fanout = 20 *) wire is_lui    = inst_packaged_i[`OP_LUI];
    (* max_fanout = 20 *) wire is_jal    = inst_packaged_i[`OP_JAL];
    (* max_fanout = 20 *) wire is_jalr   = inst_packaged_i[`OP_JALR] & valid_i;
    (* max_fanout = 20 *) wire is_branch = inst_packaged_i[`OP_BRANCH] & valid_i;
    (* max_fanout = 20 *) wire is_load   = inst_packaged_i[`OP_LOAD] & valid_i;
    (* max_fanout = 20 *) wire is_store  = inst_packaged_i[`OP_STORE] & valid_i;

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
    wire [31:0] mem_addr_calc     = value1_eff + value2_i;
    wire [1:0]  mem_addr_calc_low = mem_addr_calc[1:0]; 
    wire [31:0] branch_target     = jump1_i;
    wire [31:0] jalr_target       = rs1_data_fwd + jump2_i;
    wire [31:0] pc_plus4          = pc_addr_i + 32'd4;

    // 分支计算
    wire [31:0] branch_rs1_data = rs1_data_fwd;
    wire [31:0] branch_rs2_data = rs2_data_fwd;
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

    wire branch_pred_mispredict  = (pred_taken_i != branch_taken); // without is_branch
    wire jalr_pred_mispredict    = ((!pred_taken_i) | (pred_pc_i != jalr_target)); // without is_jalr
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
        // 转发 D-cache
        dcache_req_load     = is_load;          // dcache 读使能
        dcache_req_store    = is_store;         // dcache 写使能
        dcache_addr         = mem_addr_calc;
        dcache_wdata        = rs2_data_fwd;

        (* parallel_case, full_case *)
        case (1'b1)
            sel_lb:  dcache_is_signed = 1'b1;
            sel_lh:  dcache_is_signed = 1'b1;
            sel_lw:  dcache_is_signed = 1'b1;
            sel_lbu: dcache_is_signed = 1'b0;
            sel_lhu: dcache_is_signed = 1'b0;
            default: dcache_is_signed = 1'b0;
        endcase
        
        (* parallel_case, full_case *)
        case (1'b1)
            sel_lb:  dcache_mask = 3'b001;
            sel_lh:  dcache_mask = 3'b010;
            sel_lw:  dcache_mask = 3'b100;
            sel_lbu: dcache_mask = 3'b001;
            sel_lhu: dcache_mask = 3'b010;
            sel_sb:  dcache_mask = 3'b001;
            sel_sh:  dcache_mask = 3'b010;
            sel_sw:  dcache_mask = 3'b100;
            default: dcache_mask = 3'b000;
        endcase
        (* parallel_case, full_case *)
        case (mem_addr_calc_low)
            2'b00: dcache_addr_offset = 4'b0001;
            2'b01: dcache_addr_offset = 4'b0010;
            2'b10: dcache_addr_offset = 4'b0100;
            2'b11: dcache_addr_offset = 4'b1000;
        endcase
    end

    // 跳转
    always @(*) begin: ALU_JUMP_CTRL
        update_btb_en_o     = is_jalr & jalr_pred_mispredict;      // btb 更新使能
        update_gshare_en_o  = is_branch & branch_pred_mispredict;    // gshare 更新使能
        update_pc_o         = pc_addr_i;
        update_target_o     = jalr_target;
        actual_taken_o      = branch_taken;

        // 分支控制
        (* parallel_case, full_case *)
        case (1'b1)
            is_branch: begin
                pred_flush_en  = branch_pred_mispredict;
                pred_flush_pc  = branch_jump_addr;
            end
            is_jalr: begin
                pred_flush_en  = jalr_pred_mispredict;
                pred_flush_pc  = jalr_target;
            end
            default: begin
                pred_flush_en  = 1'b0;
                pred_flush_pc  = 32'b0;
            end
        endcase
    end

    // 跳转 & 读写
    always @(*) begin: ALU_WB
        // 寄存器写入
        regs_wen_o          = valid_i & regs_wen_i; // regs 写使能
        rd_addr_o           = rd_addr_i;
        rd_data_o           = alu_result;
        mem_req_load_o      = is_load;

        // // 打包 Load - mem1 -> wb 的 load 使能
        // load_packaged_o[`IS_LB]   = sel_lb;
        // load_packaged_o[`IS_LH]   = sel_lh;
        // load_packaged_o[`IS_LW]   = sel_lw;
        // load_packaged_o[`IS_LBU]  = sel_lbu;
        // load_packaged_o[`IS_LHU]  = sel_lhu;
    end
endmodule