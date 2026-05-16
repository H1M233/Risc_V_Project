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
    input                       pred_flush_r,

    // from fowarding - fanout set
    input      [31:0]   fwd_rs1_data_i,
    input      [31:0]   fwd_rs2_data_i,
    (* max_fanout = 10 *)
    input               fwd_rs1_hit_ex_i,
    (* max_fanout = 10 *)
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
    (* max_fanout = 10 *)
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
    (* max_fanout = 20 *) wire is_jalr   = inst_packaged_i[`OP_JALR] & ~pred_flush_r;
    (* max_fanout = 20 *) wire is_branch = inst_packaged_i[`OP_BRANCH] & ~pred_flush_r;
    (* max_fanout = 20 *) wire is_load   = inst_packaged_i[`OP_LOAD] & ~pred_flush_r;
    (* max_fanout = 20 *) wire is_store  = inst_packaged_i[`OP_STORE] & ~pred_flush_r;

    // IR-type
    (* max_fanout = 20 *) wire sel_add   = inst_packaged_i[`INST_IR_ADD];
    (* max_fanout = 20 *) wire sel_sub   = inst_packaged_i[`INST_R_SUB];
    (* max_fanout = 20 *) wire sel_xor   = inst_packaged_i[`INST_IR_XOR];
    (* max_fanout = 20 *) wire sel_or    = inst_packaged_i[`INST_IR_OR];
    (* max_fanout = 20 *) wire sel_and   = inst_packaged_i[`INST_IR_AND];
    (* max_fanout = 20 *) wire sel_sll   = inst_packaged_i[`INST_IR_SLL];
    (* max_fanout = 20 *) wire sel_srl   = inst_packaged_i[`INST_IR_SRL];
    (* max_fanout = 20 *) wire sel_sra   = inst_packaged_i[`INST_IR_SRA];
    (* max_fanout = 20 *) wire sel_slt   = inst_packaged_i[`INST_IR_SLT];
    (* max_fanout = 20 *) wire sel_sltu  = inst_packaged_i[`INST_IR_SLTU];

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

    // 纯数值计算独热
    (* max_fanout = 20 *) wire request_value_only = inst_packaged_i[`REQUEST_VALUE_ONLY];

    // 前推选择
    (* max_fanout = 5 *) wire [31:0] rs1_data_fwd = (fwd_rs1_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs1_data_i;
    (* max_fanout = 5 *) wire [31:0] rs2_data_fwd = (fwd_rs2_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs2_data_i;

    (* max_fanout = 5 *) wire [31:0] value1_eff = rs1_data_fwd;
    (* max_fanout = 5 *) wire [31:0] value2_eff = (is_alu_r) ? rs2_data_fwd : value2_i; // 判断 I / R 型

    // 计算
    wire [4:0]  shamt       = value2_eff[4:0];
    wire [31:0] add_res     = value1_eff + value2_eff;
    wire [31:0] sub_res     = value1_eff - value2_eff;
    wire [31:0] xor_res     = value1_eff ^ value2_eff;
    wire [31:0] or_res      = value1_eff | value2_eff;
    wire [31:0] and_res     = value1_eff & value2_eff;
    wire [31:0] sll_res     = value1_eff << shamt;
    wire [31:0] srl_res     = value1_eff >> shamt;
    wire [31:0] sra_res     = $signed(value1_eff) >>> shamt;

    `ifndef ALU_USE_FAST_COMPARATOR
        wire ltu_res = value1_eff < value2_eff;
        wire lts_res = $signed(value1_eff) < $signed(value2_eff);
    `else
        // 利用减法器进行快速比较
        wire [31:0] IR_sub_result;
        wire        IR_carry;

        assign {IR_carry, IR_sub_result} = {1'b0, value1_eff} - {1'b0, value2_eff};     // 等同于例化减法器
        wire        sign_diff   = (value1_eff[31] ^ value2_eff[31]);
        wire        ltu_res     = IR_carry;
        wire        lts_res     = (sign_diff) ? value1_eff[31] : IR_carry;
    `endif

    // 非寄存器内容计算已提前至 id 计算

    // 地址计算
    wire [31:0] mem_addr_calc     = value1_eff + value2_i;
    wire [1:0]  mem_addr_calc_low = mem_addr_calc[1:0]; 
    wire [31:0] branch_target     = jump1_i;
    wire [31:0] jalr_target       = rs1_data_fwd + jump2_i;
    wire [31:0] pc_plus4          = pc_addr_i + 32'd4;

    // 分支计算
    wire [31:0] branch_rs1_data = rs1_data_fwd;
    wire [31:0] branch_rs2_data = rs2_data_fwd;

    `ifndef ALU_USE_FAST_COMPARATOR
        wire branch_eq_res  = (branch_rs1_data == branch_rs2_data);
        wire branch_ltu_res = branch_rs1_data < branch_rs2_data;
        wire branch_lts_res = $signed(branch_rs1_data) < $signed(branch_rs2_data);
    `else
        // 利用减法器进行快速比较
        wire [31:0] branch_sub_result;
        wire        branch_carry;          // 借位输出
        wire        branch_sub_zero;       // 结果是否为 0

        assign {branch_carry, branch_sub_result} = {1'b0, branch_rs1_data} - {1'b0, branch_rs2_data};   // 等同于例化减法器
        assign branch_sub_zero = ~(|branch_sub_result);

        wire branch_sign_diff = (branch_rs1_data[31] ^ branch_rs2_data[31]);
        wire branch_eq_res    = branch_sub_zero;
        wire branch_ltu_res   = branch_carry;
        wire branch_lts_res   = (branch_sign_diff) ? branch_rs1_data[31] : branch_carry;
    `endif

    // Branch 计算
    reg branch_taken;
    always @(*) begin: ALU_Branch_Taken
        branch_taken =  (sel_beq  &  branch_eq_res) |
                        (sel_bne  & ~branch_eq_res) |
                        (sel_blt  &  branch_lts_res) |
                        (sel_bge  & ~branch_lts_res) |
                        (sel_bltu &  branch_ltu_res) |
                        (sel_bgeu & ~branch_ltu_res);
    end

    wire branch_pred_mispredict  = (pred_taken_i != branch_taken); // without is_branch
    wire jalr_pred_mispredict    = ((!pred_taken_i) | (pred_pc_i != jalr_target)); // without is_jalr
    wire [31:0] branch_jump_addr = branch_taken ? branch_target : pc_plus4;

    // 分指令返回
    (* max_fanout = 20 *) reg [31:0] alu_result;
    always @(*) begin: ALU
        alu_result =    ({32{sel_add}}  & add_res) |
                        ({32{sel_sub}}  & sub_res) |
                        ({32{sel_sll}}  & sll_res) |
                        ({32{sel_slt}}  & {31'b0, lts_res}) |
                        ({32{sel_sltu}} & {31'b0, ltu_res}) |
                        ({32{sel_xor}}  & xor_res) |
                        ({32{sel_srl}}  & srl_res) |
                        ({32{sel_sra}}  & sra_res) |
                        ({32{sel_or }}  & or_res) |
                        ({32{sel_and}}  & and_res) |
                        ({32{request_value_only}} & value1_i);
    end

    // Dcache 控制
    always @(*) begin: ALU_Dcache
        // 转发 D-cache
        dcache_req_load   = is_load;          // dcache 读使能
        dcache_req_store  = is_store;         // dcache 写使能
        dcache_addr       = mem_addr_calc;
        dcache_wdata      = rs2_data_fwd;
        dcache_is_signed  = sel_lb | sel_lh | sel_lw;
        dcache_mask       = ({3{sel_lb}}  & 3'b001) |
                            ({3{sel_lh}}  & 3'b010) |
                            ({3{sel_lw}}  & 3'b100) |
                            ({3{sel_lbu}} & 3'b001) |
                            ({3{sel_lhu}} & 3'b010) |
                            ({3{sel_sb}}  & 3'b001) |
                            ({3{sel_sh}}  & 3'b010) |
                            ({3{sel_sw}}  & 3'b100);

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
        (* parallel_case *)
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
        regs_wen_o          = valid_i & ~pred_flush_r & regs_wen_i; // regs 写使能
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