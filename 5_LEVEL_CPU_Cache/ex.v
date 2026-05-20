`include "rv32I.vh"
`include "alu.vh"
`include "switch.vh"

module ex(
    input                       clk,

    // from id_ex
    input      [31:0]           pc_addr_i,
    input      [31:0]           inst_i,
    input      [31:0]           jump1_i,
    input      [31:0]           jump2_i,
    input      [4:0]            rd_addr_i,
    input                       regs_wen_i,
    (* max_fanout = 30 *)
    input      [31:0]           value1_i,
    (* max_fanout = 30 *)
    input      [31:0]           value2_i,
    input                       pred_taken_i,
    input      [`OP_INST_NUM - 1:0]  inst_packaged_i,
    (* max_fanout = 30 *)
    input                       valid_i,
    input                       ecall_i,
    input                       mret_i,
    input      [11:0]           csr_addr_i,
    
    output reg [1:0]            mem_load_addr_low,
    output reg [1:0]            mem_load_mask,
    output reg                  mem_load_is_signed,

    // from fowarding - fanout set
    input      [31:0]   fwd_rs1_data_i,
    input      [31:0]   fwd_rs2_data_i,
    (* max_fanout = 20 *)
    input               fwd_rs1_hit_ex_i,
    (* max_fanout = 20 *)
    input               fwd_rs2_hit_ex_i,
    input      [31:0]   fwd_ex_rd_data_i,

    //from csr_regs
    input      [31:0]   csr_rdata,


    // to ex_mem
    output reg          regs_wen_o,
    output              ecall_o,
    output              mret_o,

    // to ex_mem & hazard   
    output reg [4:0]    rd_addr_o,
    (* max_fanout = 30 *)
    output reg [31:0]   rd_data_o,
    output reg          mem_req_load_o,

    // to jump
    (* max_fanout = 30 *)
    output reg          pred_flush_en,
    (* max_fanout = 30 *)
    output reg [31:0]   pred_flush_pc,

    // to bpu
    output reg          update_btb_en_o,
    output reg          update_gshare_en_o,
    (* max_fanout = 30 *)
    output reg [31:0]   update_pc_o,
    output reg [31:0]   update_target_o,
    (* max_fanout = 30 *)
    output reg          actual_taken_o,

    // to dcache
    output reg          dcache_req_load,
    output reg          dcache_req_store,
    output reg [31:0]   dcache_addr,
    output reg [31:0]   dcache_wdata,
    output reg          dcache_write_dram,
    output reg [3:0]    dcache_we,

    //to csr_regs
    output reg          csr_wen_o,
    output     [11:0]   csr_addr_o,
    output reg [31:0]   csr_wdata_o,
    output     [31:0]   ecall_inst,

    input               ecall_flush,
    input               mret_flush
);
    // 主操作码独热
    wire is_alu_i  = inst_packaged_i[`OP_I];
    wire is_alu_r  = inst_packaged_i[`OP_R];
    wire is_auipc  = inst_packaged_i[`OP_AUIPC];
    wire is_lui    = inst_packaged_i[`OP_LUI];
    wire is_jal    = inst_packaged_i[`OP_JAL];
    wire is_jalr   = inst_packaged_i[`OP_JALR] & ~pred_flush_en & & valid_i & !ecall_flush & !mret_flush;
    wire is_branch = inst_packaged_i[`OP_BRANCH] & ~pred_flush_en & & valid_i & !ecall_flush & !mret_flush;
    wire is_load   = inst_packaged_i[`OP_LOAD] & ~pred_flush_en & & valid_i & !ecall_flush & !mret_flush;
    wire is_store  = inst_packaged_i[`OP_STORE] & ~pred_flush_en & & valid_i & !ecall_flush & !mret_flush;
    wire is_zicsr  = inst_packaged_i[`OP_ZICSR];

    // IR-type
    wire sel_add   = inst_packaged_i[`INST_IR_ADD];
    wire sel_sub   = inst_packaged_i[`INST_R_SUB];
    wire sel_xor   = inst_packaged_i[`INST_IR_XOR];
    wire sel_or    = inst_packaged_i[`INST_IR_OR];
    wire sel_and   = inst_packaged_i[`INST_IR_AND];
    wire sel_sll   = inst_packaged_i[`INST_IR_SLL];
    wire sel_srl   = inst_packaged_i[`INST_IR_SRL];
    wire sel_sra   = inst_packaged_i[`INST_IR_SRA];
    wire sel_slt   = inst_packaged_i[`INST_IR_SLT];
    wire sel_sltu  = inst_packaged_i[`INST_IR_SLTU];

    // Load & Store
    wire sel_lb    = inst_packaged_i[`INST_LB];
    wire sel_lh    = inst_packaged_i[`INST_LH];
    wire sel_lw    = inst_packaged_i[`INST_LW];
    wire sel_lbu   = inst_packaged_i[`INST_LBU];
    wire sel_lhu   = inst_packaged_i[`INST_LHU];
    wire sel_sb    = inst_packaged_i[`INST_SB];
    wire sel_sh    = inst_packaged_i[`INST_SH];
    wire sel_sw    = inst_packaged_i[`INST_SW];

    // Branch
    wire sel_beq   = inst_packaged_i[`INST_BEQ];
    wire sel_bne   = inst_packaged_i[`INST_BNE];
    wire sel_blt   = inst_packaged_i[`INST_BLT];
    wire sel_bge   = inst_packaged_i[`INST_BGE];
    wire sel_bltu  = inst_packaged_i[`INST_BLTU];
    wire sel_bgeu  = inst_packaged_i[`INST_BGEU];
    
    // CSR
    wire sel_csrrw  = inst_packaged_i[`INST_CSRRW];
    wire sel_csrrs  = inst_packaged_i[`INST_CSRRS];
    wire sel_csrrc  = inst_packaged_i[`INST_CSRRC];
    wire sel_csrrwi = inst_packaged_i[`INST_CSRRWI];
    wire sel_csrrsi = inst_packaged_i[`INST_CSRRSI];
    wire sel_csrrci = inst_packaged_i[`INST_CSRRCI];
    wire sel_ecall  = inst_packaged_i[`INST_ECALL];
    wire sel_mret   = inst_packaged_i[`INST_MRET];

    // 纯数值计算独热 - 已提前至 id 计算
    wire request_value_only = inst_packaged_i[`REQUEST_VALUE_ONLY];

    // 前推选择
    (* max_fanout = 20 *) wire [31:0] rs1_data_fwd = (fwd_rs1_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs1_data_i;
    (* max_fanout = 20 *) wire [31:0] rs2_data_fwd = (fwd_rs2_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs2_data_i;
    (* max_fanout = 20 *) wire [31:0] value1_eff = (fwd_rs1_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs1_data_i;
    (* max_fanout = 20 *) wire [31:0] value2_eff = (fwd_rs2_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs2_data_i;

    // 计算
    wire [4:0]  shamt    = value2_eff[4:0];
    wire [31:0] add_res  = value1_eff + value2_eff;
    wire [31:0] sub_res  = value1_eff - value2_eff;
    wire [31:0] xor_res  = value1_eff ^ value2_eff;
    wire [31:0] or_res   = value1_eff | value2_eff;
    wire [31:0] and_res  = value1_eff & value2_eff;
    wire [31:0] sll_res  = value1_eff << shamt;
    wire [31:0] srl_res  = value1_eff >> shamt;
    wire [31:0] sra_res  = $signed(value1_eff) >>> shamt;

    //csr 计算
    wire [31:0] csr_value1  = (inst_i[14]) ? value1_i : value1_eff; // CSR 写数据选择
    wire [31:0] rw_res      = csr_value1; // 读写结果，写入 CSR 的值或原 CSR 值
    wire [31:0] rs_res      = csr_rdata | csr_value1; // 读-置位结果
    wire [31:0] rc_res      = csr_rdata & ~csr_value1; // 读-清零结果 

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
        assign {branch_carry, branch_sub_result} = {1'b0, branch_rs1_data} - {1'b0, branch_rs2_data};   // 等同于例化减法器
        wire branch_sign_diff = (branch_rs1_data[31] ^ branch_rs2_data[31]);

        (* max_fanout = 20 *) wire branch_eq_res    = (branch_rs1_data == branch_rs2_data);
        (* max_fanout = 20 *) wire branch_ltu_res   = branch_carry;
        (* max_fanout = 20 *) wire branch_lts_res   = (branch_sign_diff) ? branch_rs1_data[31] : branch_carry;
    `endif

    // Branch 计算
    (* max_fanout = 20 *) wire branch_taken =   (sel_beq  & branch_eq_res  ) |
                                                (sel_bne  & ~branch_eq_res ) |
                                                (sel_blt  & branch_lts_res ) |
                                                (sel_bge  & ~branch_lts_res) |
                                                (sel_bltu & branch_ltu_res ) |
                                                (sel_bgeu & ~branch_ltu_res);

    // 预测错误判断
    wire jalr_pred_mispredict    = (rs1_data_fwd != jump2_i);           // without is_jalr, rs1 == pred_pc - imm
    wire branch_pred_mispredict  = (pred_taken_i != branch_taken);      // without is_branch
    wire [31:0] branch_jump_addr = (~pred_taken_i) ? jump1_i : jump2_i; // 提前到 id 计算

    // 地址计算
    wire [31:0] jalr_target       = rs1_data_fwd + value2_i;
    wire [31:0] mem_addr_calc     = rs1_data_fwd + value2_i;

    // 两位加法器
    wire mem_addr_calc_sum0 = rs1_data_fwd[0] ^ value2_i[0];
    wire mem_addr_calc_carry0 = rs1_data_fwd[0] & value2_i[0];
    wire mem_addr_calc_sum1 = rs1_data_fwd[1] ^ value2_i[1] ^ mem_addr_calc_carry0;
    wire [1:0]  mem_addr_calc_low = {mem_addr_calc_sum1, mem_addr_calc_sum0};

    // 分指令返回
    (* max_fanout = 30 *) reg [31:0] alu_result;
    always @(*) begin
        (* parallel_case *)
        case (1'b1)
            sel_add  : alu_result = add_res;
            sel_sub  : alu_result = sub_res;
            sel_sll  : alu_result = sll_res;
            sel_slt  : alu_result = {31'b0, lts_res};
            sel_sltu : alu_result = {31'b0, ltu_res};
            sel_xor  : alu_result = xor_res;
            sel_srl  : alu_result = srl_res;
            sel_sra  : alu_result = sra_res;
            sel_or   : alu_result = or_res;
            sel_and  : alu_result = and_res;

            request_value_only: alu_result = value1_i;

            is_zicsr : alu_result = csr_rdata;
            default  : alu_result = 32'b0;
        endcase
    end

    // Dcache 控制
    wire perip_write_dram = (mem_addr_calc >= `DRAM_ADDR_START && mem_addr_calc < `DRAM_ADDR_END);
    always @(posedge clk) begin: EX_DCACHE   
        // 转发 D-cache
        dcache_req_load   <= is_load & regs_wen_i & !ecall_flush & !mret_flush;   // dcache 读使能
        dcache_req_store  <= is_store;               // dcache 写使能
        dcache_addr       <= mem_addr_calc;
        dcache_write_dram <= perip_write_dram;

        (* parallel_case *)
        case (1'b1)
            sel_sb: begin // byte
                case (mem_addr_calc_low)
                    2'b00: begin 
                        dcache_wdata <= {24'b0, rs2_data_fwd[7:0]};
                        dcache_we    <= 4'b0001 & {4{~pred_flush_en & valid_i}};
                    end
                    2'b01: begin
                        dcache_wdata <= {16'b0, rs2_data_fwd[7:0], 8'b0};
                        dcache_we    <= 4'b0010 & {4{~pred_flush_en & valid_i}};
                    end
                    2'b10: begin
                        dcache_wdata <= {8'b0, rs2_data_fwd[7:0], 16'b0};
                        dcache_we    <= 4'b0100 & {4{~pred_flush_en & valid_i}};
                    end
                    2'b11: begin
                        dcache_wdata <= {rs2_data_fwd[7:0], 24'b0};
                        dcache_we    <= 4'b1000 & {4{~pred_flush_en & valid_i}};
                    end
                    default: begin
                        dcache_wdata <= 32'b0;
                        dcache_we    <= 4'b0000;
                    end
                endcase
            end
            sel_sh: begin // half
                case (mem_addr_calc_sum1)
                    1'b0: begin
                        dcache_wdata <= {16'b0, rs2_data_fwd[15:0]};
                        dcache_we    <= 4'b0011 & {4{~pred_flush_en & valid_i}};
                    end
                    1'b1: begin
                        dcache_wdata <= {rs2_data_fwd[15:0], 16'b0};
                        dcache_we    <= 4'b1100 & {4{~pred_flush_en & valid_i}};
                    end
                    default: begin
                        dcache_wdata <= 32'b0;
                        dcache_we    <= 4'b0000;
                    end
                endcase
            end
            sel_sw: begin // word
                dcache_wdata <= rs2_data_fwd;
                dcache_we    <= 4'b1111 & {4{~pred_flush_en & valid_i}};
            end
            default: begin
                dcache_wdata <= 32'b0;
                dcache_we    <= 4'b0000;
            end
        endcase
    end

    // rd & dram 读写
    always @(*) begin: ALU_WB
        // 寄存器写入
        regs_wen_o          = !pred_flush_en & regs_wen_i & !ecall_flush & !mret_flush; // regs 写使能
        rd_addr_o           = rd_addr_i;
        rd_data_o           = alu_result;
        mem_req_load_o      = is_load & regs_wen_i & !ecall_flush & !mret_flush; // 判断 x0 寄存器提前到 id 阶段，是 x0 直接不用 Load 请求
        mem_load_is_signed  = (sel_lb | sel_lh | sel_lw);
        mem_load_addr_low   = mem_addr_calc_low;
        
        (* parallel_case *)
        case (1'b1)
            sel_lb:  mem_load_mask = 2'b01;
            sel_lh:  mem_load_mask = 2'b10;
            sel_lw:  mem_load_mask = 2'b11;
            sel_lbu: mem_load_mask = 2'b01;
            sel_lhu: mem_load_mask = 2'b10;
            default: mem_load_mask = 2'b00;
        endcase     
    end

    // 跳转
    always @(posedge clk) begin: EX_BPU
        update_btb_en_o     <= is_jalr & jalr_pred_mispredict;      // btb 更新使能
        update_gshare_en_o  <= is_branch & branch_pred_mispredict;  // gshare 更新使能
        update_pc_o         <= pc_addr_i;
        update_target_o     <= jalr_target;
        actual_taken_o      <= branch_taken;

        // 分支控制
        pred_flush_en       <=  (is_branch & branch_pred_mispredict) | (is_jalr & jalr_pred_mispredict);
        pred_flush_pc       <=  (is_branch) ? branch_jump_addr :
                                (is_jalr)   ? jalr_target : 32'b0;
    end

    // CSR 控制
    always @(*) begin: ALU_CSR_CTRL
        csr_wen_o = valid_i & ~pred_flush_en & is_zicsr; // CSR 写使能
        csr_wdata_o = (sel_csrrw)  ? rw_res :
                      (sel_csrrs)  ? rs_res :
                      (sel_csrrc)  ? rc_res :
                      (sel_csrrwi) ? rw_res :
                      (sel_csrrsi) ? rs_res :
                      (sel_csrrci) ? rc_res :
                                      32'b0;               // CSR 写数据
    end 
    
    assign ecall_o = ecall_i;
    assign mret_o  = mret_i;
    assign ecall_inst = (ecall_i) ? pc_addr_i : 32'b0; // 传递 ecall 指令给 csr_regs 模块以保存 mepc
    assign csr_addr_o = csr_addr_i; //打拍
endmodule
