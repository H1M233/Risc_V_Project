<<<<<<< HEAD
`include "rv32I.vh"
`include "alu.vh"

module ex2(
    input      [4:0]            rd_addr_i,
    input      [31:0]           rd_data_i,
    input                       regs_wen_i,
    input                       mem_req_load_i,
    input                       ecall_i,
    input                       mret_i,
    input      [1:0]            load_mask_i,
    input      [1:0]            load_addr_low_i,
    input                       load_is_signed_i,
    input      [31:0]           ecall_inst_i,

    input      [31:0]           op1_i,
    input      [31:0]           op2_i,
    input      [`OP_INST_NUM - 1:0] inst_packaged_i,
    input                       valid_i,

    input                       dcache_req_load_i,
    input                       dcache_req_store_i,
    input      [31:0]           dcache_addr_i,
    input      [31:0]           dcache_wdata_i,
    input                       dcache_write_dram_i,
    input      [3:0]            dcache_we_i,

    output reg [4:0]            rd_addr_o,
    output reg [31:0]           rd_data_o,
    output reg                  regs_wen_o,
    output reg                  mem_req_load_o,
    output reg                  ecall_o,
    output reg                  mret_o,
    output reg [1:0]            load_mask_o,
    output reg [1:0]            load_addr_low_o,
    output reg                  load_is_signed_o,
    output reg [31:0]           ecall_inst_o,

    output reg                  dcache_req_load_o,
    output reg                  dcache_req_store_o,
    output reg [31:0]           dcache_addr_o,
    output reg [31:0]           dcache_wdata_o,
    output reg                  dcache_write_dram_o,
    output reg [3:0]            dcache_we_o
);
    wire sel_mul    = inst_packaged_i[`INST_MUL]    & valid_i;
    wire sel_mulh   = inst_packaged_i[`INST_MULH]   & valid_i;
    wire sel_mulhsu = inst_packaged_i[`INST_MULHSU] & valid_i;
    wire sel_mulhu  = inst_packaged_i[`INST_MULHU]  & valid_i;
    wire sel_div    = inst_packaged_i[`INST_DIV]    & valid_i;
    wire sel_divu   = inst_packaged_i[`INST_DIVU]   & valid_i;
    wire sel_rem    = inst_packaged_i[`INST_REM]    & valid_i;
    wire sel_remu   = inst_packaged_i[`INST_REMU]   & valid_i;

    wire is_m_ext = sel_mul | sel_mulh | sel_mulhsu | sel_mulhu |
                    sel_div | sel_divu | sel_rem | sel_remu;

    wire signed [32:0] op1_s = {op1_i[31], op1_i};
    wire signed [32:0] op2_s = {op2_i[31], op2_i};
    wire signed [32:0] op1_u_as_s = {1'b0, op1_i};
    wire signed [32:0] op2_u_as_s = {1'b0, op2_i};

    wire signed [65:0] prod_ss = op1_s * op2_s;
    wire signed [65:0] prod_su = op1_s * op2_u_as_s;
    wire signed [65:0] prod_uu = op1_u_as_s * op2_u_as_s;

    wire div_signed = sel_div | sel_rem;
    wire op1_neg = div_signed & op1_i[31];
    wire op2_neg = div_signed & op2_i[31];
    wire [31:0] abs_op1 = op1_neg ? (~op1_i + 32'd1) : op1_i;
    wire [31:0] abs_op2 = op2_neg ? (~op2_i + 32'd1) : op2_i;

    wire [63:0] divrem_abs = divremu_nonrestore(abs_op1, abs_op2);
    wire [31:0] quot_abs = divrem_abs[63:32];
    wire [31:0] rem_abs  = divrem_abs[31:0];

    wire [31:0] quot_signed = (op1_neg ^ op2_neg) ? (~quot_abs + 32'd1) : quot_abs;
    wire [31:0] rem_signed  = op1_neg ? (~rem_abs + 32'd1) : rem_abs;

    wire div_by_zero = (op2_i == 32'b0);
    wire div_overflow = (op1_i == 32'h8000_0000) & (op2_i == 32'hffff_ffff);

    reg [31:0] m_result;
    always @(*) begin
        (* parallel_case *)
        case (1'b1)
            sel_mul:    m_result = prod_uu[31:0];
            sel_mulh:   m_result = prod_ss[63:32];
            sel_mulhsu: m_result = prod_su[63:32];
            sel_mulhu:  m_result = prod_uu[63:32];
            sel_div:    m_result = div_by_zero  ? 32'hffff_ffff :
                                  div_overflow ? 32'h8000_0000 :
                                                 quot_signed;
            sel_divu:   m_result = div_by_zero ? 32'hffff_ffff : quot_abs;
            sel_rem:    m_result = div_by_zero  ? op1_i :
                                  div_overflow ? 32'b0 :
                                                 rem_signed;
            sel_remu:   m_result = div_by_zero ? op1_i : rem_abs;
            default:    m_result = rd_data_i;
        endcase
    end

    always @(*) begin
        rd_addr_o           = rd_addr_i;
        rd_data_o           = is_m_ext ? m_result : rd_data_i;
=======
`include "alu.vh"

module ex2(
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen_i,
    input               mem_req_load_i,
    input               ecall_i,
    input               mret_i,
    input      [1:0]    load_mask_i,
    input      [1:0]    load_addr_low_i,
    input               load_is_signed_i,
    input      [31:0]   ecall_inst_i,

    input               dcache_req_load_i,
    input               dcache_req_store_i,
    input      [31:0]   dcache_addr_i,
    input      [31:0]   dcache_wdata_i,
    input               dcache_write_dram_i,
    input      [3:0]    dcache_we_i,

    input      [`OP_INST_NUM - 1:0] inst_packaged_i,
    input      [31:0]   mdu_rs1_i,
    input      [31:0]   mdu_rs2_i,
    input signed [33:0] div_remainder_i,
    input      [31:0]   div_quotient_i,
    input      [31:0]   div_divisor_abs_i,

    output reg [4:0]    rd_addr_o,
    output reg [31:0]   rd_data_o,
    output reg          regs_wen_o,
    output reg          mem_req_load_o,
    output reg          ecall_o,
    output reg          mret_o,
    output reg [1:0]    load_mask_o,
    output reg [1:0]    load_addr_low_o,
    output reg          load_is_signed_o,
    output reg [31:0]   ecall_inst_o,

    output reg          dcache_req_load_o,
    output reg          dcache_req_store_o,
    output reg [31:0]   dcache_addr_o,
    output reg [31:0]   dcache_wdata_o,
    output reg          dcache_write_dram_o,
    output reg [3:0]    dcache_we_o
);
    wire sel_mul    = inst_packaged_i[`INST_MUL];
    wire sel_mulh   = inst_packaged_i[`INST_MULH];
    wire sel_mulhsu = inst_packaged_i[`INST_MULHSU];
    wire sel_mulhu  = inst_packaged_i[`INST_MULHU];
    wire sel_div    = inst_packaged_i[`INST_DIV];
    wire sel_divu   = inst_packaged_i[`INST_DIVU];
    wire sel_rem    = inst_packaged_i[`INST_REM];
    wire sel_remu   = inst_packaged_i[`INST_REMU];

    wire is_mul = sel_mul | sel_mulh | sel_mulhsu | sel_mulhu;
    wire is_div = sel_div | sel_divu | sel_rem | sel_remu;
    wire is_mdu = is_mul | is_div;

    wire [63:0] mul_uu = {32'b0, mdu_rs1_i} * {32'b0, mdu_rs2_i};
    wire signed [65:0] mul_ss =
        $signed({mdu_rs1_i[31], mdu_rs1_i}) * $signed({mdu_rs2_i[31], mdu_rs2_i});
    wire signed [65:0] mul_su =
        $signed({mdu_rs1_i[31], mdu_rs1_i}) * $signed({1'b0, mdu_rs2_i});

    reg [31:0] mul_result;
    always @(*) begin
        case (1'b1)
            sel_mul:    mul_result = mul_uu[31:0];
            sel_mulh:   mul_result = mul_ss[63:32];
            sel_mulhsu: mul_result = mul_su[63:32];
            sel_mulhu:  mul_result = mul_uu[63:32];
            default:    mul_result = 32'b0;
        endcase
    end

    wire signed [33:0] div_remainder_s2;
    wire [31:0]        div_quotient_s2;
    rv32m_div_step #(.STEPS(16)) div_stage2 (
        .remainder_i (div_remainder_i),
        .quotient_i  (div_quotient_i),
        .divisor_i   (div_divisor_abs_i),
        .remainder_o (div_remainder_s2),
        .quotient_o  (div_quotient_s2)
    );

    wire signed [33:0] div_remainder_fixed =
        div_remainder_s2[33] ? (div_remainder_s2 + $signed({2'b00, div_divisor_abs_i})) :
                               div_remainder_s2;

    wire signed_div_op = sel_div | sel_rem;
    wire div_by_zero   = (mdu_rs2_i == 32'b0);
    wire div_overflow  = signed_div_op &&
                         (mdu_rs1_i == 32'h8000_0000) &&
                         (mdu_rs2_i == 32'hffff_ffff);

    wire quotient_neg  = signed_div_op & (mdu_rs1_i[31] ^ mdu_rs2_i[31]);
    wire remainder_neg = signed_div_op & mdu_rs1_i[31];

    wire [31:0] quotient_signed =
        quotient_neg ? (~div_quotient_s2 + 32'd1) : div_quotient_s2;
    wire [31:0] remainder_mag = div_remainder_fixed[31:0];
    wire [31:0] remainder_signed =
        remainder_neg ? (~remainder_mag + 32'd1) : remainder_mag;

    reg [31:0] div_result;
    always @(*) begin
        if (div_by_zero) begin
            div_result = (sel_div | sel_divu) ? 32'hffff_ffff : mdu_rs1_i;
        end
        else if (div_overflow) begin
            div_result = (sel_div) ? 32'h8000_0000 : 32'b0;
        end
        else begin
            case (1'b1)
                sel_div:  div_result = quotient_signed;
                sel_divu: div_result = div_quotient_s2;
                sel_rem:  div_result = remainder_signed;
                sel_remu: div_result = remainder_mag;
                default:  div_result = 32'b0;
            endcase
        end
    end

    wire [31:0] mdu_result = is_mul ? mul_result : div_result;

    always @(*) begin
        rd_addr_o           = rd_addr_i;
        rd_data_o           = is_mdu ? mdu_result : rd_data_i;
>>>>>>> 9949f6b048c4bc471514e2989b8b1a332441e541
        regs_wen_o          = regs_wen_i;
        mem_req_load_o      = mem_req_load_i;
        ecall_o             = ecall_i;
        mret_o              = mret_i;
        load_mask_o         = load_mask_i;
        load_addr_low_o     = load_addr_low_i;
        load_is_signed_o    = load_is_signed_i;
        ecall_inst_o        = ecall_inst_i;
<<<<<<< HEAD
=======

>>>>>>> 9949f6b048c4bc471514e2989b8b1a332441e541
        dcache_req_load_o   = dcache_req_load_i;
        dcache_req_store_o  = dcache_req_store_i;
        dcache_addr_o       = dcache_addr_i;
        dcache_wdata_o      = dcache_wdata_i;
        dcache_write_dram_o = dcache_write_dram_i;
        dcache_we_o         = dcache_we_i;
    end
<<<<<<< HEAD

    function [63:0] divremu_nonrestore;
        input [31:0] dividend;
        input [31:0] divisor;
        integer i;
        reg signed [33:0] rem;
        reg signed [33:0] divs;
        reg [31:0] quot;
        reg rem_nonneg;
        begin
            rem  = 34'sd0;
            divs = {2'b00, divisor};
            quot = dividend;

            for (i = 0; i < 32; i = i + 1) begin
                rem_nonneg = ~rem[33];
                rem = {rem[32:0], quot[31]};
                quot = {quot[30:0], 1'b0};

                if (rem_nonneg)
                    rem = rem - divs;
                else
                    rem = rem + divs;

                quot[0] = ~rem[33];
            end

            if (rem[33])
                rem = rem + divs;

            divremu_nonrestore = {quot, rem[31:0]};
        end
    endfunction
=======
>>>>>>> 9949f6b048c4bc471514e2989b8b1a332441e541
endmodule
