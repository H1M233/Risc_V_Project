`include "../def/alu_def.svh"
module alu_csr (
    input  logic            ctrl_stall,

    input  logic [31:0]     value1,
    input  logic [31:0]     value2,
    input  decode_t         ipkg,
    input  id_ex_data_t     dpkg,

    // fcsr
    input  logic [4:0]      fflags,

    output ex_csr_data_t    cpkg
);
    assign cpkg.waddr       = dpkg.csr_waddr;
    assign cpkg.wen         = (ipkg.is_zicsr | (ipkg.is_FP & (fflags != dpkg.csr_rdata[4:0])));     // CSR 写使能
    assign cpkg.ecall       = ipkg.sel_ecall;
    assign cpkg.mret        = ipkg.sel_mret;
    assign cpkg.ecall_inst  = (ipkg.sel_ecall) ? dpkg.pc : 32'b0;

    // csr 计算
    wire [31:0] csr_value1 = (dpkg.inst[14]) ? dpkg.imm : value1;      // CSR 写数据选择
    wire [31:0] rw_res     = csr_value1;                               // 读写结果，写入 CSR 的值或原 CSR 值
    wire [31:0] rs_res     = dpkg.csr_rdata | csr_value1;              // 读-置位结果
    wire [31:0] rc_res     = dpkg.csr_rdata & ~csr_value1;             // 读-清零结果 

    wire [31:0] fflags_res = dpkg.csr_rdata | {27'b0, fflags};

    always_comb begin: ALU_CSR_CTRL
        unique case (1'b1)
            ipkg.sel_csrrw  : cpkg.wdata = rw_res;
            ipkg.sel_csrrwi : cpkg.wdata = rw_res;
            ipkg.sel_csrrs  : cpkg.wdata = rs_res;
            ipkg.sel_csrrsi : cpkg.wdata = rs_res;
            ipkg.sel_csrrc  : cpkg.wdata = rc_res;
            ipkg.sel_csrrci : cpkg.wdata = rc_res;

            ipkg.is_FP      : cpkg.wdata = fflags_res;
            default         : cpkg.wdata = 32'b0;
        endcase
    end 
endmodule