`include "rv32I.vh"
`include "alu.vh"
`include "switch.vh"

module ex(
    input  logic            clk,
    input  logic            rst,
    input  logic            pipe_flush,

    // from id_ex
    input  id_ex_data_t     data_packaged_i,
    input  decode_t         inst_packaged_i,
    input  logic            regs_wen_i,
    input  logic            valid_i,

    // frowarding ex data
    input  logic [31:0]     fwd_ex_rd_data_i,

    // from csr_regs
    input  logic [31:0]     csr_rdata,

    // from d-cache
    input  logic            dcache_load_ready_i,
    input  logic            dcache_store_ready_i,
    input  logic [31:0]     dcache_rdata_i,

    // to ex_mem & hazard
    output ex_mem_data_t    mem_data_packaged_o,
    output logic            valid_o,

    // to ex_dcache & hazard
    output ex_lsu_data_t    dcache_data_packaged_o,

    // to ex_bpu
    output ex_bpu_data_t    bpu_data_packaged_o,
    output logic            pred_flush_en,
    output logic [31:0]     pred_flush_pc,

    // to csr_regs
    output ex_csr_data_t    csr_data_packaged_o,

    // ctrl_stall
    output logic            ctrl_stall
);
    // 解码
    wire [31:0] pc_addr_i    = data_packaged_i.pc;
    wire [31:0] inst_i       = data_packaged_i.inst;
    wire [31:0] value1_i     = data_packaged_i.value1;
    wire [31:0] value2_i     = data_packaged_i.value2;
    wire [31:0] jump1_i      = data_packaged_i.jump1;
    wire [31:0] jump2_i      = data_packaged_i.jump2;
    wire [4:0]  rd_addr_i    = data_packaged_i.rd_addr;
    wire        pred_taken_i = data_packaged_i.pred_taken;
    wire        ecall_i      = data_packaged_i.ecall;
    wire        mret_i       = data_packaged_i.mret;

    // 主操作码独热
    decode_t ipkg;
    assign ipkg = inst_packaged_i;

    // 前推选择 - 当为立即数时 fwd_rs2_data_i 代表 imm
    wire fwd_rs1_hit_ex_i = data_packaged_i.fwd_rs1_hit_ex;
    wire fwd_rs2_hit_ex_i = data_packaged_i.fwd_rs2_hit_ex;
    wire [31:0] fwd_rs1_data_i = data_packaged_i.fwd_rs1_data;
    wire [31:0] fwd_rs2_data_i = data_packaged_i.fwd_rs2_data;

    // 前推选择 - 当为立即数时 fwd_rs2_data_i 代表 imm
    (* max_fanout = 20 *) wire [31:0] rs1_data_fwd = (fwd_rs1_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs1_data_i;
    (* max_fanout = 20 *) wire [31:0] rs2_data_fwd = (fwd_rs2_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs2_data_i;

    // value1 & value2 仅用于 I & R 型运算
    (* max_fanout = 20 *) wire [31:0] value1_eff = (fwd_rs1_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs1_data_i;
    (* max_fanout = 20 *) wire [31:0] value2_eff = (fwd_rs2_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs2_data_i;

    // 加减法专用前推
    wire [31:0] value1_eff_add = (fwd_rs1_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs1_data_i;
    wire [31:0] value2_eff_add = (fwd_rs2_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs2_data_i;
    wire [31:0] value1_eff_sub = (fwd_rs1_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs1_data_i;
    wire [31:0] value2_eff_sub = (fwd_rs2_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs2_data_i;

    // 计算
    cmp_result_t alu_cmp;
    assign alu_cmp = fast_compare(value1_eff, value2_eff);

    wire [4:0]  shamt    = value2_eff[4:0];
    wire [31:0] add_res  = value1_eff_add + value2_eff_add;
    wire [31:0] sub_res  = value1_eff_sub - value2_eff_sub;
    wire [31:0] xor_res  = value1_eff ^ value2_eff;
    wire [31:0] or_res   = value1_eff | value2_eff;
    wire [31:0] and_res  = value1_eff & value2_eff;
    wire [31:0] sll_res  = value1_eff << shamt;
    wire [31:0] srl_res  = value1_eff >> shamt;
    wire [31:0] sra_res  = $signed(value1_eff) >>> shamt;
    wire        ltu_res  = alu_cmp.ltu;
    wire        lts_res  = alu_cmp.lts;
    
    // csr 计算
    wire [31:0] csr_value1 = (inst_i[14]) ? value1_i : rs1_data_fwd;   // CSR 写数据选择
    wire [31:0] rw_res     = csr_value1;                               // 读写结果，写入 CSR 的值或原 CSR 值
    wire [31:0] rs_res     = csr_rdata | csr_value1;                   // 读-置位结果
    wire [31:0] rc_res     = csr_rdata & ~csr_value1;                  // 读-清零结果 
    
    // 分支计算
    cmp_result_t branch_cmp;
    assign branch_cmp = fast_compare(branch_rs1_data, branch_rs2_data);

    wire [31:0] branch_rs1_data = (fwd_rs1_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs1_data_i;
    wire [31:0] branch_rs2_data = (fwd_rs2_hit_ex_i) ? fwd_ex_rd_data_i : fwd_rs2_data_i;
    wire branch_eq_res  = branch_rs1_data == branch_rs2_data;
    wire branch_ltu_res = branch_cmp.ltu;
    wire branch_lts_res = branch_cmp.lts;
    
    // Branch 计算
    reg branch_taken;
    always_comb begin
        unique case (1'b1)
            ipkg.sel_beq  : branch_taken = branch_eq_res;
            ipkg.sel_bne  : branch_taken = ~branch_eq_res;
            ipkg.sel_blt  : branch_taken = branch_lts_res;
            ipkg.sel_bge  : branch_taken = ~branch_lts_res;
            ipkg.sel_bltu : branch_taken = branch_ltu_res;
            ipkg.sel_bgeu : branch_taken = ~branch_ltu_res;
            default  : branch_taken = 1'b0;
        endcase
    end
    
    // 预测错误判断
    wire [31:0] jalr_target             = rs1_data_fwd + value2_i;
    wire        jalr_pred_mispredict    = (ipkg.is_jalr && rs1_data_fwd != jump2_i);        // rs1 == pred_pc - imm
    wire        branch_pred_mispredict  = (ipkg.is_branch && pred_taken_i != branch_taken);
    wire [31:0] branch_jump_addr        = (~pred_taken_i) ? jump1_i : jump2_i;              // 提前到 id 计算
    
    // 两位加法器
    wire mem_addr_calc_sum0 = rs1_data_fwd[0] ^ value2_i[0];
    wire mem_addr_calc_carry0 = rs1_data_fwd[0] & value2_i[0];
    wire mem_addr_calc_sum1 = rs1_data_fwd[1] ^ value2_i[1] ^ mem_addr_calc_carry0;
    wire [1:0]  mem_addr_calc_low = {mem_addr_calc_sum1, mem_addr_calc_sum0};
    
    // RV32I 标准结果
    logic [31:0] alu_rv32i_res;
    always_comb begin
        unique case (1'b1)
            ipkg.sel_add            : alu_rv32i_res = add_res;
            ipkg.sel_sub            : alu_rv32i_res = sub_res;
            ipkg.sel_sll            : alu_rv32i_res = sll_res;
            ipkg.sel_slt            : alu_rv32i_res = {31'b0, lts_res};
            ipkg.sel_sltu           : alu_rv32i_res = {31'b0, ltu_res};
            ipkg.sel_xor            : alu_rv32i_res = xor_res;
            ipkg.sel_srl            : alu_rv32i_res = srl_res;
            ipkg.sel_sra            : alu_rv32i_res = sra_res;
            ipkg.sel_or             : alu_rv32i_res = or_res;
            ipkg.sel_and            : alu_rv32i_res = and_res;
            ipkg.request_value_only : alu_rv32i_res = value1_i;
            default                 : alu_rv32i_res = 32'b0;
        endcase
    end
    
    // 输出计算结果
    logic [31:0] alu_result;
    always_comb begin
        unique case (1'b1)
            ipkg.is_rv32i     : alu_result = alu_rv32i_res;
            ipkg.is_zicsr     : alu_result = csr_rdata;
            ipkg.is_Mext      : alu_result = Mext_res;
            is_Bext           : alu_result = Bext_res;
            ipkg.is_Zicondext : alu_result = Zicondext_res;
            ipkg.is_Aext      : alu_result = Aext_res;
            default           : alu_result = 32'b0;
        endcase
    end
    
    // 跳转
    ex_bpu_data_t bpkg;
    assign bpu_data_packaged_o    = bpkg;
    assign bpkg.update_btb_en     = jalr_pred_mispredict;        // btb 更新使能
    assign bpkg.update_gshare_en  = branch_pred_mispredict;      // gshare 更新使能
    assign bpkg.update_pc         = pc_addr_i;
    assign bpkg.update_target     = jalr_target;
    assign bpkg.actual_taken      = branch_taken;
    assign bpkg.rollback_ras_ptr  = data_packaged_i.ras_ptr;

    // 冲刷控制
    assign pred_flush_en  = (branch_pred_mispredict | jalr_pred_mispredict);
    assign pred_flush_pc  = (ipkg.is_branch) ? branch_jump_addr :
    (ipkg.is_jalr)   ? jalr_target : 32'b0;
    
    // Load & Store Unit
    logic atom_req_load, atom_req_store;
    logic [31:0] atom_addr, atom_wdata;
    wire [31:0] mem_addr_calc = rs1_data_fwd + value2_i;
    alu_lsu ALU_LSU (
        .clk            (clk),
        .rst            (rst),
        .flush          (pipe_flush),
        
        .rs1            (rs1_data_fwd),
        .rs2            (rs2_data_fwd),
        .mem_addr       (mem_addr_calc),
        .addr_low       (mem_addr_calc_low),
        .regs_wen       (regs_wen_i),
        .ipkg           (ipkg),

        .atom_req_load  (atom_req_load),
        .atom_req_store (atom_req_store),
        .atom_addr      (atom_addr),
        .atom_wdata     (atom_wdata),

        .dpkg       (dcache_data_packaged_o)
    );
    
    // rd & dram 读写
    ex_mem_data_t mpkg;
    assign mem_data_packaged_o  = mpkg;
    assign mpkg.rd_addr         = rd_addr_i;
    assign mpkg.rd_data         = alu_result;
    assign mpkg.regs_wen        = regs_wen_i & ~ctrl_stall; // regs 写使能
    assign mpkg.req_load        = dcache_data_packaged_o.req_load;
    assign mpkg.load_is_signed  = (ipkg.sel_lb | ipkg.sel_lh | ipkg.sel_lw);
    assign mpkg.load_addr_low   = mem_addr_calc_low;
    assign valid_o              = valid_i;
    
    always_comb begin
        unique case (1'b1)
            ipkg.sel_lb:  mpkg.load_mask = 2'b01;
            ipkg.sel_lh:  mpkg.load_mask = 2'b10;
            ipkg.sel_lw:  mpkg.load_mask = 2'b11;
            ipkg.sel_lbu: mpkg.load_mask = 2'b01;
            ipkg.sel_lhu: mpkg.load_mask = 2'b10;
            default: mpkg.load_mask = 2'b00;
        endcase    
    end
    
    // CSR 控制
    ex_csr_data_t cpkg;
    assign csr_data_packaged_o = cpkg;
    assign cpkg.wen   = ipkg.is_zicsr;     // CSR 写使能
    assign mpkg.ecall = ecall_i;
    assign mpkg.mret  = mret_i;
    assign mpkg.ecall_inst = (ecall_i) ? pc_addr_i : 32'b0; // 传递 ecall 指令给 csr_regs 模块以保存 mepc
    always_comb begin: ALU_CSR_CTRL
        unique case (1'b1)
            ipkg.sel_csrrw:  cpkg.wdata = rw_res;
            ipkg.sel_csrrs:  cpkg.wdata = rs_res;
            ipkg.sel_csrrc:  cpkg.wdata = rc_res;
            ipkg.sel_csrrwi: cpkg.wdata = rw_res;
            ipkg.sel_csrrsi: cpkg.wdata = rs_res;
            ipkg.sel_csrrci: cpkg.wdata = rc_res;
            default: cpkg.wdata = 32'b0;
        endcase
    end 

    // M-ext
    logic Mext_ctrl;
    logic [31:0] Mext_res;
    `ifdef ENABLE_M
    alu_Mext ALU_MEXT (
        .clk        (clk),
        .rst        (rst),
        .flush      (pipe_flush),

        .value1     (rs1_data_fwd),
        .value2     (rs2_data_fwd),
        .ipkg       (ipkg),

        .ctrl       (Mext_ctrl),
        .result     (Mext_res)
    );
    `endif

    // B-ext
    wire is_Bext = ipkg.is_Bext_zba | ipkg.is_Bext_zbb | ipkg.is_Bext_zbc | ipkg.is_Bext_zbs | ipkg.is_Bext_zbkb | ipkg.is_Bext_zbkx;
    logic Bext_ctrl;
    logic [31:0] Bext_res;
    `ifdef ENABLE_B
    alu_Bext ALU_BEXT (
        .clk        (clk),
        .rst        (rst),
        .flush      (pipe_flush),

        .value1     (rs1_data_fwd),
        .value2     (rs2_data_fwd),
        .ipkg       (ipkg),

        .ctrl       (Bext_ctrl),
        .result     (Bext_res)
    );
    `endif

    // Zicond-ext
    logic [31:0] Zicondext_res;
    `ifdef ENABLE_Zicond
    wire Zicond_value2_nez = |rs2_data_fwd;
    always_comb begin
        unique case (1'b1)
            ipkg.sel_czero_eqz : Zicondext_res = (~Zicond_value2_nez) ? 0 : rs1_data_fwd;
            ipkg.sel_czero_nez : Zicondext_res = (Zicond_value2_nez)  ? 0 : rs1_data_fwd;
            default : Zicondext_res = 32'b0;
        endcase
    end
    `endif

    // A-ext
    logic Aext_ctrl;
    logic [31:0] Aext_res;
    `ifdef ENABLE_A
    alu_Aext ALU_AEXT (
        .clk            (clk),
        .rst            (rst),
        .flush          (pipe_flush),

        .rs1            (rs1_data_fwd),
        .rs2            (rs2_data_fwd),
        .regs_wen       (regs_wen_i),
        .ipkg           (ipkg),

        .AXI_wen        (1'b0),
        .load_ready     (dcache_load_ready_i),
        .store_ready    (dcache_store_ready_i),
        .mem_rdata      (dcache_rdata_i),

        .atom_req_load  (atom_req_load),
        .atom_req_store (atom_req_store),
        .atom_addr      (atom_addr),
        .atom_wdata     (atom_wdata),

        .AXI_lock       (),
        .ctrl           (Aext_ctrl),
        .result         (Aext_res)
    );
    `endif


    // ex 暂停控制
    assign ctrl_stall = (Mext_ctrl | Bext_ctrl | Aext_ctrl) & ~pipe_flush;
endmodule
