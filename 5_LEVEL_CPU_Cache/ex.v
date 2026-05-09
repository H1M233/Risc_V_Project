`include "rv32I.vh"

module ex(
    // from id_ex
    input      [31:0]   pc_addr_i,
    input      [31:0]   inst_i,
    input      [31:0]   jump1_i,
    input      [31:0]   jump2_i,
    input      [4:0]    rd_addr_i,
    input               regs_wen_i,
    input      [31:0]   rs1_data_i,
    input      [31:0]   rs2_data_i,
    input      [4:0]    rs1_addr_i,
    input      [4:0]    rs2_addr_i,
    input      [31:0]   value1_i,
    input      [31:0]   value2_i,
    input               pred_taken_i,
    input      [31:0]   pred_pc_i,
    input               valid_i,

    // from mem
    input      [4:0]    mem_forward_rd_addr_i,
    input      [31:0]   mem_forward_rd_data_i,
    input               mem_forward_regs_wen_i,
    input      [6:0]    mem_forward_opcode_i,

    // from wb
    input      [4:0]    wb_forward_rd_addr_i,
    input      [31:0]   wb_forward_rd_data_i,
    input               wb_forward_regs_wen_i,

    // to hazard
    output reg [6:0]    hazard_opcode,

    // to ex_mem
    output reg [31:0]   inst_o,
    output reg          regs_wen_o,

    // to ex_mem & hazard
    output reg [4:0]    rd_addr_o,
    output reg [31:0]   rd_data_o,

    // to jump
    output reg [31:0]   jump_addr_o,
    output reg          jump_en,

    // unused
    output reg [31:0]   rs1_data_o,

    // to bpu
    output reg          update_btb_en,
    output reg          update_gshare_en,
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
    wire [6:0] opcode_raw = inst_i[6:0];
    wire [6:0] opcode     = valid_i ? opcode_raw : `TYPE_I;
    wire [2:0] funct3     = inst_i[14:12];
    wire [6:0] funct7     = inst_i[31:25];

    wire mem_can_forward =  (mem_forward_regs_wen_i) &&
                            (mem_forward_rd_addr_i != 5'b0) &&
                            (mem_forward_opcode_i != `TYPE_L);

    wire wb_can_forward =   (wb_forward_regs_wen_i) &&
                            (wb_forward_rd_addr_i != 5'b0);

    wire rs1_mem_hit =  (mem_can_forward) &&
                        (mem_forward_rd_addr_i == rs1_addr_i);

    wire rs2_mem_hit =  (mem_can_forward) &&
                        (mem_forward_rd_addr_i == rs2_addr_i);

    wire rs1_wb_hit  =  (wb_can_forward) &&
                        (wb_forward_rd_addr_i == rs1_addr_i);

    wire rs2_wb_hit  =  (wb_can_forward) &&
                        (wb_forward_rd_addr_i == rs2_addr_i);

    wire [31:0] rs1_fwd_data =  (rs1_mem_hit) ? mem_forward_rd_data_i :
                                (rs1_wb_hit)  ? wb_forward_rd_data_i  : 
                                                rs1_data_i;

    wire [31:0] rs2_fwd_data =  (rs2_mem_hit) ? mem_forward_rd_data_i :
                                (rs2_wb_hit)  ? wb_forward_rd_data_i  :
                                                rs2_data_i;

    wire is_branch = valid_i && (opcode_raw == `TYPE_B);
    wire is_jalr   = valid_i && (opcode_raw == `JALR);

    // Branch/JALR 正确性由 hazard 显式 stall 保证。
    // 不在分支比较链路上再接复杂 EX/MEM/WB 转发，避免关键路径变长。
    wire [31:0] branch_rs1_data = rs1_data_i;
    wire [31:0] branch_rs2_data = rs2_data_i;
    wire [31:0] jalr_rs1_data   = rs1_data_i;

    wire uses_rs1_as_value1 =   (opcode == `TYPE_R) ||
                                (opcode == `TYPE_I) ||
                                (opcode == `TYPE_L) ||
                                (opcode == `TYPE_S) ||
                                (opcode == `TYPE_B);

    wire uses_rs2_as_value2 =   (opcode == `TYPE_R) ||
                                (opcode == `TYPE_B);

    wire [31:0] value1_eff = (uses_rs1_as_value1) ? rs1_fwd_data : value1_i;
    wire [31:0] value2_eff = (uses_rs2_as_value2) ? rs2_fwd_data : value2_i;

    wire [4:0] shamt = value2_eff[4:0];

    wire [31:0] add_res       = value1_eff + value2_eff;
    wire [31:0] sub_res       = value1_eff - value2_eff;
    wire [31:0] mem_addr_calc = rs1_fwd_data + value2_i;
    wire [31:0] branch_target = jump1_i + jump2_i;
    wire [31:0] jalr_target   = jalr_rs1_data + jump2_i;
    wire [31:0] pc_plus4      = pc_addr_i + 32'd4;

    wire        ltu_res       = (value1_eff < value2_eff);
    wire        sign_diff     = (value1_eff[31] ^ value2_eff[31]);
    wire        lts_res       = (sign_diff) ? value1_eff[31] : (value1_eff[30:0] < value2_eff[30:0]);

    wire        branch_eq_res    = (branch_rs1_data == branch_rs2_data);
    wire        branch_ltu_res   = (branch_rs1_data < branch_rs2_data);
    wire        branch_sign_diff = (branch_rs1_data[31] ^ branch_rs2_data[31]);
    wire        branch_lts_res   = (branch_sign_diff) ? branch_rs1_data[31] :
                                                        (branch_rs1_data[30:0] < branch_rs2_data[30:0]);

    wire [31:0] xor_res     = value1_eff ^ value2_eff;
    wire [31:0] or_res      = value1_eff | value2_eff;
    wire [31:0] and_res     = value1_eff & value2_eff;
    wire [31:0] sll_res     = value1_eff << shamt;
    wire [31:0] srl_res     = value1_eff >> shamt;
    wire [31:0] sra_res     = $signed(value1_eff) >>> shamt;

    reg branch_taken;

    always @(*) begin
        case (funct3)
            `BEQ:    branch_taken = branch_eq_res;
            `BNE:    branch_taken = ~branch_eq_res;
            `BLT:    branch_taken = branch_lts_res;
            `BGE:    branch_taken = ~branch_lts_res;
            `BLTU:   branch_taken = branch_ltu_res;
            `BGEU:   branch_taken = ~branch_ltu_res;
            default: branch_taken = 1'b0;
        endcase
    end

    wire        branch_pred_mispredict = is_branch && (pred_taken_i != branch_taken);
    wire        jalr_pred_mispredict   = is_jalr && ((!pred_taken_i) || (pred_pc_i != jalr_target));

    wire        branch_jump_en         = branch_pred_mispredict;
    wire        jalr_jump_en           = jalr_pred_mispredict;

    wire [31:0] branch_jump_addr       = branch_taken ? branch_target : pc_plus4;

    wire [31:0] resolved_jump_addr     = jalr_jump_en   ? jalr_target      :
                                         branch_jump_en ? branch_jump_addr :
                                                          32'b0;

    wire        resolved_jump_en       = branch_jump_en | jalr_jump_en;

    always @(*) begin
        pc_addr_o           = pc_addr_i;
        regs_wen_o          = valid_i ? regs_wen_i : 1'b0;

        rd_data_o           = 32'b0;
        rd_addr_o           = rd_addr_i;

        rs1_data_o          = rs1_fwd_data;

        jump_en             = 1'b0;
        jump_addr_o         = 32'b0;

        hazard_opcode       = valid_i ? opcode_raw : `TYPE_I;
        inst_o              = valid_i ? inst_i : `NOP;

        update_btb_en       = 1'b0;
        update_gshare_en    = 1'b0;
        update_target       = 32'b0;
        actual_taken        = 1'b0;
        pred_mispredict     = 1'b0;

        dcache_req_load     = valid_i && (opcode_raw == `TYPE_L);
        dcache_req_store    = valid_i && (opcode_raw == `TYPE_S);
        dcache_mask         = 2'b0;
        dcache_addr         = mem_addr_calc;
        dcache_wdata        = rs2_fwd_data;

        case (opcode)

            `LUI: begin
                rd_data_o = add_res;
            end

            `AUIPC: begin
                rd_data_o = add_res;
            end

            `JAL: begin
                rd_data_o = add_res;
            end

            `JALR: begin
                rd_data_o       = add_res;
                update_btb_en   = valid_i;
                update_target   = jalr_target;
                pred_mispredict = jalr_pred_mispredict;
                jump_en         = resolved_jump_en;
                jump_addr_o     = resolved_jump_addr;
            end

            `TYPE_B: begin
                update_gshare_en = valid_i;
                actual_taken     = branch_taken;
                pred_mispredict  = branch_pred_mispredict;
                jump_en          = resolved_jump_en;
                jump_addr_o      = resolved_jump_addr;
            end

            `TYPE_L: begin
                case(funct3)
                    `LB: begin
                        dcache_mask  = 2'b00;
                    end

                    `LH: begin
                        dcache_mask  = 2'b01;
                    end

                    `LW: begin
                        dcache_mask  = 2'b10;
                    end

                    `LBU: begin
                        dcache_mask  = 2'b00;
                    end

                    `LHU: begin
                        dcache_mask  = 2'b01;
                    end
                    
                    default: begin
                        dcache_mask  = 2'b00;
                    end
                endcase
            end

            `TYPE_S: begin
                case (funct3)
                    `SB: begin
                        dcache_mask = 2'b00;
                    end
                    `SH: begin
                        dcache_mask = 2'b01;
                    end
                    `SW: begin
                        dcache_mask = 2'b10;
                    end
                    default: begin
                        dcache_mask = 2'b00;
                    end
                endcase
            end

            `TYPE_I: begin
                case (funct3)
                    `ADDI: begin
                        rd_data_o = add_res;
                    end

                    `SLTI: begin
                        rd_data_o = {31'b0, lts_res};
                    end

                    `SLTIU: begin
                        rd_data_o = {31'b0, ltu_res};
                    end

                    `XORI: begin
                        rd_data_o = xor_res;
                    end

                    `ORI: begin
                        rd_data_o = or_res;
                    end

                    `ANDI: begin
                        rd_data_o = and_res;
                    end

                    `SLLI: begin
                        rd_data_o = sll_res;
                    end

                    `SRLI_SRAI: begin
                        if (funct7 == 7'b0000000) begin
                            rd_data_o = srl_res;
                        end
                        else if (funct7 == 7'b0100000) begin
                            rd_data_o = sra_res;
                        end
                        else begin
                            rd_data_o = 32'b0;
                        end
                    end

                    default: begin
                        rd_data_o = 32'b0;
                    end
                endcase
            end

            `TYPE_R: begin
                case (funct3)
                    `ADD_SUB: begin
                        if (funct7 == 7'b0000000) begin
                            rd_data_o = add_res;
                        end
                        else if (funct7 == 7'b0100000) begin
                            rd_data_o = sub_res;
                        end
                        else begin
                            rd_data_o = 32'b0;
                        end
                    end

                    `SLL: begin
                        rd_data_o = sll_res;
                    end

                    `SLT: begin
                        rd_data_o = {31'b0, lts_res};
                    end

                    `SLTU: begin
                        rd_data_o = {31'b0, ltu_res};
                    end

                    `XOR: begin
                        rd_data_o = xor_res;
                    end

                    `SRL_SRA: begin
                        if (funct7 == 7'b0000000) begin
                            rd_data_o = srl_res;
                        end
                        else if (funct7 == 7'b0100000) begin
                            rd_data_o = sra_res;
                        end
                        else begin
                            rd_data_o = 32'b0;
                        end
                    end

                    `OR: begin
                        rd_data_o = or_res;
                    end

                    `AND: begin
                        rd_data_o = and_res;
                    end

                    default: begin
                        rd_data_o = 32'b0;
                    end
                endcase
            end

            default: begin
                rd_data_o        = 32'b0;
                jump_en          = 1'b0;
                jump_addr_o      = 32'b0;
                update_btb_en    = 1'b0;
                update_gshare_en = 1'b0;
                update_target    = 32'b0;
                actual_taken     = 1'b0;
                pred_mispredict  = 1'b0;
            end
        endcase
    end

endmodule