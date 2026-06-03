`include "rv32I.vh"
`include "alu.vh"
`include "switch.vh"

module ex(
    // from id_ex
    input data_t            data_packaged_i,
    input decode_t          inst_packaged_i,
    input logic             valid_i,

    // forwarding
    input logic [31:0] fwd_slot0_ex_rd_data_i,
    input logic [31:0] fwd_slot1_ex_rd_data_i,

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
    // 解码
    wire [31:0] pc_addr_i       = data_packaged_i.pc;
    wire [31:0] inst_i          = data_packaged_i.inst;
    wire        regs_wen_i      = data_packaged_i.regs_wen;
    wire [31:0] value1_i        = data_packaged_i.value1;
    wire [31:0] value2_i        = data_packaged_i.value2;
    wire [31:0] jump1_i         = data_packaged_i.jump1;
    wire [31:0] jump2_i         = data_packaged_i.jump2;
    wire [4:0]  rd_addr_i       = data_packaged_i.rd_addr;
    wire        pred_taken_i    = data_packaged_i.pred_taken;
    wire [11:0] csr_addr_i      = data_packaged_i.csr_addr;
    wire        ecall_i         = data_packaged_i.ecall;
    wire        mret_i          = data_packaged_i.mret;

    // 主操作码独热
    wire is_alu_i  = inst_packaged_i.is_alu_i;
    wire is_alu_r  = inst_packaged_i.is_alu_r;
    wire is_auipc  = inst_packaged_i.is_auipc;
    wire is_lui    = inst_packaged_i.is_lui;
    wire is_jal    = inst_packaged_i.is_jal;
    wire is_jalr   = inst_packaged_i.is_jalr;
    wire is_branch = inst_packaged_i.is_branch;
    wire is_load   = inst_packaged_i.is_load;
    wire is_store  = inst_packaged_i.is_store;
    wire is_zicsr  = inst_packaged_i.is_zicsr;

    // IR-type
    wire sel_add   = inst_packaged_i.sel_add;
    wire sel_sub   = inst_packaged_i.sel_sub;
    wire sel_xor   = inst_packaged_i.sel_xor;
    wire sel_or    = inst_packaged_i.sel_or;
    wire sel_and   = inst_packaged_i.sel_and;
    wire sel_sll   = inst_packaged_i.sel_sll;
    wire sel_srl   = inst_packaged_i.sel_srl;
    wire sel_sra   = inst_packaged_i.sel_sra;
    wire sel_slt   = inst_packaged_i.sel_slt;
    wire sel_sltu  = inst_packaged_i.sel_sltu;

    // Load & Store
    wire sel_lb    = inst_packaged_i.sel_lb;
    wire sel_lh    = inst_packaged_i.sel_lh;
    wire sel_lw    = inst_packaged_i.sel_lw;
    wire sel_lbu   = inst_packaged_i.sel_lbu;
    wire sel_lhu   = inst_packaged_i.sel_lhu;
    wire sel_sb    = inst_packaged_i.sel_sb;
    wire sel_sh    = inst_packaged_i.sel_sh;
    wire sel_sw    = inst_packaged_i.sel_sw;

    // Branch
    wire sel_beq   = inst_packaged_i.sel_beq;
    wire sel_bne   = inst_packaged_i.sel_bne;
    wire sel_blt   = inst_packaged_i.sel_blt;
    wire sel_bge   = inst_packaged_i.sel_bge;
    wire sel_bltu  = inst_packaged_i.sel_bltu;
    wire sel_bgeu  = inst_packaged_i.sel_bgeu;
    
    // CSR
    wire sel_csrrw  = inst_packaged_i.sel_csrrw;
    wire sel_csrrs  = inst_packaged_i.sel_csrrs;
    wire sel_csrrc  = inst_packaged_i.sel_csrrc;
    wire sel_csrrwi = inst_packaged_i.sel_csrrwi;
    wire sel_csrrsi = inst_packaged_i.sel_csrrsi;
    wire sel_csrrci = inst_packaged_i.sel_csrrci;
    wire sel_ecall  = inst_packaged_i.sel_ecall;
    wire sel_mret   = inst_packaged_i.sel_mret;

    // 纯数值计算独热 - 已提前至 id 计算
    wire request_value_only = inst_packaged_i.request_value_only;

    // 前推选择 - 当为立即数时 fwd_rs2_data_i 代表 imm
    wire fwd_rs1_hit_slot0_ex_i = data_packaged_i.fwd_rs1_hit_slot0_ex;
    wire fwd_rs1_hit_slot1_ex_i = data_packaged_i.fwd_rs1_hit_slot1_ex;
    wire fwd_rs2_hit_slot0_ex_i = data_packaged_i.fwd_rs2_hit_slot0_ex;
    wire fwd_rs2_hit_slot1_ex_i = data_packaged_i.fwd_rs2_hit_slot1_ex;
    wire [31:0] fwd_rs1_data_i = data_packaged_i.fwd_rs1_data;
    wire [31:0] fwd_rs2_data_i = data_packaged_i.fwd_rs2_data;

    (* max_fanout = 20 *) wire [31:0] rs1_data_fwd = (fwd_rs1_hit_slot1_ex_i) ? fwd_slot1_ex_rd_data_i : (fwd_rs1_hit_slot0_ex_i) ? fwd_slot0_ex_rd_data_i : fwd_rs1_data_i;
    (* max_fanout = 20 *) wire [31:0] rs2_data_fwd = (fwd_rs2_hit_slot1_ex_i) ? fwd_slot1_ex_rd_data_i : (fwd_rs2_hit_slot0_ex_i) ? fwd_slot0_ex_rd_data_i : fwd_rs2_data_i;

    // value1 & value2 仅用于 I & R 型运算
    (* max_fanout = 20 *) wire [31:0] value1_eff = (fwd_rs1_hit_slot1_ex_i) ? fwd_slot1_ex_rd_data_i : (fwd_rs1_hit_slot0_ex_i) ? fwd_slot0_ex_rd_data_i : fwd_rs1_data_i;
    (* max_fanout = 20 *) wire [31:0] value2_eff = (fwd_rs2_hit_slot1_ex_i) ? fwd_slot1_ex_rd_data_i : (fwd_rs2_hit_slot0_ex_i) ? fwd_slot0_ex_rd_data_i : fwd_rs2_data_i;

    // 加减法专用前推
    wire [31:0] value1_eff_add = (fwd_rs1_hit_slot1_ex_i) ? fwd_slot1_ex_rd_data_i : (fwd_rs1_hit_slot0_ex_i) ? fwd_slot0_ex_rd_data_i : fwd_rs1_data_i;
    wire [31:0] value2_eff_add = (fwd_rs2_hit_slot1_ex_i) ? fwd_slot1_ex_rd_data_i : (fwd_rs2_hit_slot0_ex_i) ? fwd_slot0_ex_rd_data_i : fwd_rs2_data_i;
    wire [31:0] value1_eff_sub = (fwd_rs1_hit_slot1_ex_i) ? fwd_slot1_ex_rd_data_i : (fwd_rs1_hit_slot0_ex_i) ? fwd_slot0_ex_rd_data_i : fwd_rs1_data_i;
    wire [31:0] value2_eff_sub = (fwd_rs2_hit_slot1_ex_i) ? fwd_slot1_ex_rd_data_i : (fwd_rs2_hit_slot0_ex_i) ? fwd_slot0_ex_rd_data_i : fwd_rs2_data_i;

    // 计算
    wire [4:0]  shamt    = value2_eff[4:0];
    wire [31:0] add_res  = value1_eff_add + value2_eff_add;
    wire [31:0] sub_res  = value1_eff_sub - value2_eff_sub;
    wire [31:0] xor_res  = value1_eff ^ value2_eff;
    wire [31:0] or_res   = value1_eff | value2_eff;
    wire [31:0] and_res  = value1_eff & value2_eff;
    wire [31:0] sll_res  = value1_eff << shamt;
    wire [31:0] srl_res  = value1_eff >> shamt;
    wire [31:0] sra_res  = $signed(value1_eff) >>> shamt;
    wire [1:0]  alu_cmp  = fast_compare(value1_eff, value2_eff);    // 利用减法器进行快速比较
    wire        ltu_res  = alu_cmp[1];
    wire        lts_res  = alu_cmp[0];

    // csr 计算
    wire [31:0] csr_value1  = (inst_i[14]) ? value1_i : rs1_data_fwd;   // CSR 写数据选择
    wire [31:0] rw_res      = csr_value1;                               // 读写结果，写入 CSR 的值或原 CSR 值
    wire [31:0] rs_res      = csr_rdata | csr_value1;                   // 读-置位结果
    wire [31:0] rc_res      = csr_rdata & ~csr_value1;                  // 读-清零结果 

    // 分支计算
    wire [31:0] branch_rs1_data = (fwd_rs1_hit_slot1_ex_i) ? fwd_slot1_ex_rd_data_i : (fwd_rs1_hit_slot0_ex_i) ? fwd_slot0_ex_rd_data_i : fwd_rs1_data_i;
    wire [31:0] branch_rs2_data = (fwd_rs2_hit_slot1_ex_i) ? fwd_slot1_ex_rd_data_i : (fwd_rs2_hit_slot0_ex_i) ? fwd_slot0_ex_rd_data_i : fwd_rs2_data_i;
    wire [1:0]  branch_cmp = fast_compare(branch_rs1_data, branch_rs2_data);    // 利用减法器进行快速比较
    (* max_fanout = 20 *) wire branch_eq_res  = branch_rs1_data == branch_rs2_data;
    (* max_fanout = 20 *) wire branch_ltu_res = branch_cmp[1];
    (* max_fanout = 20 *) wire branch_lts_res = branch_cmp[0];

    // Branch 计算
    reg branch_taken;
    always_comb begin
        unique case (1'b1)
            sel_beq  : branch_taken = branch_eq_res;
            sel_bne  : branch_taken = ~branch_eq_res;
            sel_blt  : branch_taken = branch_lts_res;
            sel_bge  : branch_taken = ~branch_lts_res;
            sel_bltu : branch_taken = branch_ltu_res;
            sel_bgeu : branch_taken = ~branch_ltu_res;
            default  : branch_taken = 1'b0;
        endcase
    end

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
    always_comb begin
        unique case (1'b1)
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
            is_zicsr : alu_result = csr_rdata;

            request_value_only: alu_result = value1_i;
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

    always_comb begin        
        unique case (1'b1)
            sel_lb:  mem_load_mask = 2'b01;
            sel_lh:  mem_load_mask = 2'b10;
            sel_lw:  mem_load_mask = 2'b11;
            sel_lbu: mem_load_mask = 2'b01;
            sel_lhu: mem_load_mask = 2'b10;
            default: mem_load_mask = 2'b00;
        endcase     

        unique case (1'b1)
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
    always_comb begin: ALU_CSR_CTRL
        unique case (1'b1)
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

    // 快速比较器
    function [1:0] fast_compare;    // {eq, ltu, lts}
        input [31:0] a;
        input [31:0] b;
        reg   [31:0] diff;
        reg          borrow;
        begin
            // 例化减法器
            {borrow, diff} = {1'b0, a} - {1'b0, b};

            // ltu (a < b unsigned)
            fast_compare[1] = borrow;

            // lts (a < b signed)
            fast_compare[0] = (a[31] ^ b[31]) ? a[31] : borrow;
        end
    endfunction
endmodule
