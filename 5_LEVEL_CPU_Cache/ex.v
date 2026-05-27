`include "rv32I.vh"
`include "alu.vh"
`include "switch.vh"

module ex(
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

    // from fowarding - fanout set
    (* max_fanout = 20 *)
    input      [31:0]   fwd_rs1_data_i,
    (* max_fanout = 20 *)
    input      [31:0]   fwd_rs2_data_i,
    (* max_fanout = 20 *)
    input               fwd_rs1_hit_ex_i,
    (* max_fanout = 20 *)
    input               fwd_rs2_hit_ex_i,
    (* max_fanout = 20 *)
    input      [31:0]   fwd_ex_rd_data_i,

    // from csr_regs
    input      [31:0]   csr_rdata,

    // to ex_mem & hazard
    output              regs_wen_o,
    output              ecall_o,
    output              mret_o,
    output              mem_req_load,
    output     [1:0]    mem_load_addr_low,
    output reg [1:0]    mem_load_mask,
    output              mem_load_is_signed,
    output              valid_o,
    output     [4:0]    rd_addr_o,
    (* max_fanout = 30 *)
    output     [31:0]   rd_data_o,

    // to ex_dcache & hazard
    output              dcache_req_load,
    output              dcache_req_store,
    output     [31:0]   dcache_addr,
    output reg [31:0]   dcache_wdata,
    output reg [3:0]    dcache_we,
    output              dcache_write_dram,

    // to ex_bpu
    output              update_btb_en_o,
    output              update_gshare_en_o,
    output     [31:0]   update_pc_o,
    output     [31:0]   update_target_o,
    output              actual_taken_o,
    output              pred_flush_en,
    output     [31:0]   pred_flush_pc,

    // to csr_regs
    output              csr_wen_o,
    output     [11:0]   csr_addr_o,
    output reg [31:0]   csr_wdata_o,
    output     [31:0]   ecall_inst
);

    // 主操作码独热
    wire is_alu_i  = inst_packaged_i[`OP_I];
    wire is_alu_r  = inst_packaged_i[`OP_R];
    wire is_auipc  = inst_packaged_i[`OP_AUIPC];
    wire is_lui    = inst_packaged_i[`OP_LUI];
    wire is_jal    = inst_packaged_i[`OP_JAL];
    wire is_jalr   = inst_packaged_i[`OP_JALR];
    wire is_branch = inst_packaged_i[`OP_BRANCH];
    wire is_load   = inst_packaged_i[`OP_LOAD];
    wire is_store  = inst_packaged_i[`OP_STORE];
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
    (* max_fanout = 20 *) wire [31:0] value1_eff = rs1_data_fwd;
    (* max_fanout = 20 *) wire [31:0] value2_eff = rs2_data_fwd;

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

    // 利用减法器进行快速比较
    wire [31:0] IR_sub_result;
    wire        IR_carry;

    assign {IR_carry, IR_sub_result} = {1'b0, value1_eff} - {1'b0, value2_eff};     // 等同于例化减法器
    wire        sign_diff   = (value1_eff[31] ^ value2_eff[31]);
    wire        ltu_res     = IR_carry;
    wire        lts_res     = (sign_diff) ? value1_eff[31] : IR_carry;

    // 分支计算
    wire [31:0] branch_rs1_data = rs1_data_fwd;
    wire [31:0] branch_rs2_data = rs2_data_fwd;

    // 利用减法器进行快速比较
    wire [31:0] branch_sub_result;
    wire        branch_carry;          // 借位输出
    assign {branch_carry, branch_sub_result} = {1'b0, branch_rs1_data} - {1'b0, branch_rs2_data};   // 等同于例化减法器
    wire branch_sign_diff = (branch_rs1_data[31] ^ branch_rs2_data[31]);

    (* max_fanout = 20 *) wire branch_eq_res    = (branch_rs1_data == branch_rs2_data);
    (* max_fanout = 20 *) wire branch_ltu_res   = branch_carry;
    (* max_fanout = 20 *) wire branch_lts_res   = (branch_sign_diff) ? branch_rs1_data[31] : branch_carry;

    // Branch 计算
    (* max_fanout = 20 *) wire branch_taken =   (sel_beq  & branch_eq_res  ) |
                                                (sel_bne  & ~branch_eq_res ) |
                                                (sel_blt  & branch_lts_res ) |
                                                (sel_bge  & ~branch_lts_res) |
                                                (sel_bltu & branch_ltu_res ) |
                                                (sel_bgeu & ~branch_ltu_res);

    // 预测错误判断
    wire jalr_pred_mispredict    = (is_jalr && rs1_data_fwd != jump2_i);            // rs1 == pred_pc - imm
    wire branch_pred_mispredict  = (is_branch && pred_taken_i != branch_taken);
    wire [31:0] branch_jump_addr = (~pred_taken_i) ? jump1_i : jump2_i;             // 提前到 id 计算

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

    // 跳转
    assign update_btb_en_o     = jalr_pred_mispredict;        // btb 更新使能
    assign update_gshare_en_o  = branch_pred_mispredict;      // gshare 更新使能
    assign update_pc_o         = pc_addr_i;
    assign update_target_o     = jalr_target;
    assign actual_taken_o      = branch_taken;

    // 冲刷控制
    assign pred_flush_en  = (branch_pred_mispredict | jalr_pred_mispredict);
    assign pred_flush_pc  = (is_branch) ? branch_jump_addr :
                            (is_jalr)   ? jalr_target : 32'b0;
    
    // Dcache 控制
    assign dcache_req_load     = is_load & regs_wen_i;   // dcache 读使能
    assign dcache_req_store    = is_store;               // dcache 写使能
    assign dcache_addr         = mem_addr_calc;
    assign dcache_write_dram   = (mem_addr_calc >= `DRAM_ADDR_START && mem_addr_calc < `DRAM_ADDR_END);
    assign mem_req_load        = is_load & regs_wen_i;
    assign mem_load_is_signed  = (sel_lb | sel_lh | sel_lw);
    assign mem_load_addr_low   = mem_addr_calc_low;

    always @(*) begin        
        (* parallel_case *)
        case (1'b1)
            sel_lb:  mem_load_mask = 2'b01;
            sel_lh:  mem_load_mask = 2'b10;
            sel_lw:  mem_load_mask = 2'b11;
            sel_lbu: mem_load_mask = 2'b01;
            sel_lhu: mem_load_mask = 2'b10;
            default: mem_load_mask = 2'b00;
        endcase     

        (* parallel_case *)
        case (1'b1)
            sel_sb: begin // byte
                case (mem_addr_calc_low)
                    2'b00: begin 
                        dcache_wdata = {24'b0, rs2_data_fwd[7:0]};
                        dcache_we    = 4'b0001;
                    end
                    2'b01: begin
                        dcache_wdata = {16'b0, rs2_data_fwd[7:0], 8'b0};
                        dcache_we    = 4'b0010;
                    end
                    2'b10: begin
                        dcache_wdata = {8'b0, rs2_data_fwd[7:0], 16'b0};
                        dcache_we    = 4'b0100;
                    end
                    2'b11: begin
                        dcache_wdata = {rs2_data_fwd[7:0], 24'b0};
                        dcache_we    = 4'b1000;
                    end
                    default: begin
                        dcache_wdata = 32'b0;
                        dcache_we    = 4'b0000;
                    end
                endcase
            end
            sel_sh: begin // half
                case (mem_addr_calc_sum1)
                    1'b0: begin
                        dcache_wdata = {16'b0, rs2_data_fwd[15:0]};
                        dcache_we    = 4'b0011;
                    end
                    1'b1: begin
                        dcache_wdata = {rs2_data_fwd[15:0], 16'b0};
                        dcache_we    = 4'b1100;
                    end
                    default: begin
                        dcache_wdata = 32'b0;
                        dcache_we    = 4'b0000;
                    end
                endcase
            end
            sel_sw: begin // word
                dcache_wdata = rs2_data_fwd;
                dcache_we    = 4'b1111;
            end
            default: begin
                dcache_wdata = 32'b0;
                dcache_we    = 4'b0000;
            end
        endcase
    end

    // rd & dram 读写
    assign regs_wen_o  = regs_wen_i; // regs 写使能
    assign rd_addr_o   = rd_addr_i;
    assign rd_data_o   = alu_result;
    assign valid_o     = valid_i;

    // CSR 控制
    always @(*) begin: ALU_CSR_CTRL
        (* parallel_case *)
        case (1'b1)
            sel_csrrw:  csr_wdata_o = rw_res;
            sel_csrrs:  csr_wdata_o = rs_res;
            sel_csrrc:  csr_wdata_o = rc_res;
            sel_csrrwi: csr_wdata_o = rw_res;
            sel_csrrsi: csr_wdata_o = rs_res;
            sel_csrrci: csr_wdata_o = rc_res;
            default:    csr_wdata_o = 32'b0;
        endcase
    end 
    
    assign csr_wen_o    = is_zicsr;     // CSR 写使能
    assign ecall_o      = ecall_i;
    assign mret_o       = mret_i;
    assign ecall_inst   = (ecall_i) ? pc_addr_i : 32'b0; // 传递 ecall 指令给 csr_regs 模块以保存 mepc
    assign csr_addr_o   = csr_addr_i;   //打拍
endmodule
