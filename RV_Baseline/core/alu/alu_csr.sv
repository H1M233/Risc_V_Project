`include "../def/alu_def.svh"
module alu_csr (
    input  logic [31:0]     value1,
    input  logic [31:0]     value2,
    input  decode_t         ipkg,
    input  EX_data_t        dpkg,

    // fcsr
    `ifdef ENABLE_F
    input  logic [4:0]      fflags,
    `endif

    output CSR_data_t       cpkg
);
    `ifdef ENABLE_F
    wire fflags_wen        = ((ipkg.is_FP | ipkg.is_FM) & (fflags != dpkg.csr_rdata[4:0]));
    wire [31:0] fflags_res = dpkg.csr_rdata | {27'b0, fflags};
    `else
    wire fflags_wen = 0;
    `endif

    // csr 计算
    wire [31:0] csr_value1 = (dpkg.inst[14]) ? dpkg.imm : value1;      // CSR 写数据选择
    wire [31:0] rw_res     = csr_value1;                               // 读写结果，写入 CSR 的值或原 CSR 值
    wire [31:0] rs_res     = dpkg.csr_rdata | csr_value1;              // 读-置位结果
    wire [31:0] rc_res     = dpkg.csr_rdata & ~csr_value1;             // 读-清零结果 

    always_comb begin: ALU_CSR_CTRL
        cpkg.waddr = dpkg.csr_waddr;
        cpkg.wen   = ipkg.is_zicsr | fflags_wen;     // CSR 写使能
        cpkg.ecall = ipkg.sel_ecall;
        cpkg.mret  = ipkg.sel_mret;
        cpkg.sret  = ipkg.sel_sret;

        unique case (1'b1)
            ipkg.sel_csrrw  : cpkg.wdata = rw_res;
            ipkg.sel_csrrwi : cpkg.wdata = rw_res;
            ipkg.sel_csrrs  : cpkg.wdata = rs_res;
            ipkg.sel_csrrsi : cpkg.wdata = rs_res;
            ipkg.sel_csrrc  : cpkg.wdata = rc_res;
            ipkg.sel_csrrci : cpkg.wdata = rc_res;

            `ifdef ENABLE_F
            ipkg.is_FP      : cpkg.wdata = fflags_res;
            ipkg.is_FM      : cpkg.wdata = fflags_res;
            `endif
            default         : cpkg.wdata = 32'b0;
        endcase
    end 
endmodule