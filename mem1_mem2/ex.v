`include "rv32I.vh"

module ex(
    input      [31:0]   pc_addr_i,
    input      [31:0]   inst_i,
    input      [31:0]   jump1_i,
    input      [31:0]   jump2_i,
    input      [4:0]    rd_addr_i,
    input               regs_wen_i,
    input      [31:0]   rs1_data_i,
    input      [31:0]   rs2_data_i,
    input      [31:0]   value1_i,
    input      [31:0]   value2_i,
    input               pred_taken_i,
    input      [31:0]   pred_pc_i,

    input      [4:0]    mem_forward_rd_addr_i,
    input      [31:0]   mem_forward_rd_data_i,
    input               mem_forward_regs_wen_i,
    input      [6:0]    mem_forward_opcode_i,

    input      [4:0]    mem2_forward_rd_addr_i,
    input      [31:0]   mem2_forward_rd_data_i,
    input               mem2_forward_regs_wen_i,

    input      [4:0]    wb_forward_rd_addr_i,
    input      [31:0]   wb_forward_rd_data_i,
    input               wb_forward_regs_wen_i,

    input      [4:0]    prev_wb_forward_rd_addr_i,
    input      [31:0]   prev_wb_forward_rd_data_i,
    input               prev_wb_forward_regs_wen_i,

    output reg [6:0]    hazard_opcode,

    output reg [31:0]   inst_o,
    output reg [31:0]   mem_addr_o,
    output reg          mem_req,
    output reg          mem_wen,
    output reg          regs_wen_o,
    output reg [31:0]   rs2_data_o,

    output reg [4:0]    rd_addr_o,
    output reg [31:0]   rd_data_o,

    output reg [31:0]   jump_addr_o,
    output reg          jump_en,

    output reg [31:0]   rs1_data_o,

    output reg          update_btb_en,
    output reg          update_gshare_en,
    output reg [31:0]   pc_addr_o,
    output reg [31:0]   update_target,
    output reg          actual_taken,
    output reg          pred_mispredict
);

    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [4:0] rs1_addr;
    wire [4:0] rs2_addr;
    wire [4:0] shamt;

    assign opcode   = inst_i[6:0];
    assign funct3   = inst_i[14:12];
    assign funct7   = inst_i[31:25];
    assign rs1_addr = inst_i[19:15];
    assign rs2_addr = inst_i[24:20];

    wire mem_can_forward;
    wire mem2_can_forward;
    wire wb_can_forward;
    wire prev_wb_can_forward;

    assign mem_can_forward = mem_forward_regs_wen_i &&
                             (mem_forward_rd_addr_i != 5'b0) &&
                             (mem_forward_opcode_i != `TYPE_L);

    assign mem2_can_forward = mem2_forward_regs_wen_i &&
                              (mem2_forward_rd_addr_i != 5'b0);

    assign wb_can_forward = wb_forward_regs_wen_i &&
                            (wb_forward_rd_addr_i != 5'b0);

    assign prev_wb_can_forward = prev_wb_forward_regs_wen_i &&
                                 (prev_wb_forward_rd_addr_i != 5'b0);

    wire rs1_mem_hit;
    wire rs2_mem_hit;
    wire rs1_mem2_hit;
    wire rs2_mem2_hit;
    wire rs1_wb_hit;
    wire rs2_wb_hit;
    wire rs1_prev_wb_hit;
    wire rs2_prev_wb_hit;

    assign rs1_mem_hit = mem_can_forward &&
                         (mem_forward_rd_addr_i == rs1_addr);

    assign rs2_mem_hit = mem_can_forward &&
                         (mem_forward_rd_addr_i == rs2_addr);

    assign rs1_mem2_hit = mem2_can_forward &&
                          (mem2_forward_rd_addr_i == rs1_addr);

    assign rs2_mem2_hit = mem2_can_forward &&
                          (mem2_forward_rd_addr_i == rs2_addr);

    assign rs1_wb_hit = wb_can_forward &&
                        (wb_forward_rd_addr_i == rs1_addr);

    assign rs2_wb_hit = wb_can_forward &&
                        (wb_forward_rd_addr_i == rs2_addr);

    assign rs1_prev_wb_hit = prev_wb_can_forward &&
                             (prev_wb_forward_rd_addr_i == rs1_addr);

    assign rs2_prev_wb_hit = prev_wb_can_forward &&
                             (prev_wb_forward_rd_addr_i == rs2_addr);

    wire [31:0] rs1_fwd_data;
    wire [31:0] rs2_fwd_data;

    assign rs1_fwd_data =
        rs1_mem_hit     ? mem_forward_rd_data_i      :
        rs1_mem2_hit    ? mem2_forward_rd_data_i     :
        rs1_wb_hit      ? wb_forward_rd_data_i       :
        rs1_prev_wb_hit ? prev_wb_forward_rd_data_i  :
                          rs1_data_i;

    assign rs2_fwd_data =
        rs2_mem_hit     ? mem_forward_rd_data_i      :
        rs2_mem2_hit    ? mem2_forward_rd_data_i     :
        rs2_wb_hit      ? wb_forward_rd_data_i       :
        rs2_prev_wb_hit ? prev_wb_forward_rd_data_i  :
                          rs2_data_i;

    wire uses_rs1_as_value1;
    wire uses_rs2_as_value2;

    assign uses_rs1_as_value1 = (opcode == `TYPE_R) ||
                                (opcode == `TYPE_I) ||
                                (opcode == `TYPE_L) ||
                                (opcode == `TYPE_S) ||
                                (opcode == `TYPE_B);

    assign uses_rs2_as_value2 = (opcode == `TYPE_R) ||
                                (opcode == `TYPE_B);

    wire [31:0] value1_eff;
    wire [31:0] value2_eff;
    wire [31:0] jump1_eff;

    assign value1_eff = uses_rs1_as_value1 ? rs1_fwd_data : value1_i;
    assign value2_eff = uses_rs2_as_value2 ? rs2_fwd_data : value2_i;
    assign jump1_eff  = (opcode == `JALR) ? rs1_fwd_data : jump1_i;

    assign shamt = value2_eff[4:0];

    wire [31:0] add_res;
    wire [31:0] sub_res;
    wire [31:0] jump_target;
    wire [31:0] pc_plus4;

    assign add_res     = value1_eff + value2_eff;
    assign sub_res     = value1_eff - value2_eff;
    assign jump_target = jump1_eff + jump2_i;
    assign pc_plus4    = pc_addr_i + 32'd4;

    wire eq_res;
    wire ltu_res;
    wire sign_diff;
    wire lts_res;

    assign eq_res    = value1_eff == value2_eff;
    assign ltu_res   = value1_eff < value2_eff;
    assign sign_diff = value1_eff[31] ^ value2_eff[31];
    assign lts_res   = sign_diff ? value1_eff[31] :
                                    (value1_eff[30:0] < value2_eff[30:0]);

    wire [31:0] xor_res;
    wire [31:0] or_res;
    wire [31:0] and_res;
    wire [31:0] sll_res;
    wire [31:0] srl_res;
    wire [31:0] sra_res;

    assign xor_res = value1_eff ^ value2_eff;
    assign or_res  = value1_eff | value2_eff;
    assign and_res = value1_eff & value2_eff;
    assign sll_res = value1_eff << shamt;
    assign srl_res = value1_eff >> shamt;
    assign sra_res = $signed(value1_eff) >>> shamt;

    reg branch_taken;

    always @(*) begin
        case (funct3)
            `BEQ:    branch_taken = eq_res;
            `BNE:    branch_taken = ~eq_res;
            `BLT:    branch_taken = lts_res;
            `BGE:    branch_taken = ~lts_res;
            `BLTU:   branch_taken = ltu_res;
            `BGEU:   branch_taken = ~ltu_res;
            default: branch_taken = 1'b0;
        endcase
    end

    always @(*) begin
        pc_addr_o        = pc_addr_i;
        regs_wen_o       = regs_wen_i;
        mem_wen          = 1'b0;
        mem_req          = 1'b0;
        mem_addr_o       = 32'b0;
        rd_data_o        = 32'b0;
        rd_addr_o        = rd_addr_i;
        rs1_data_o       = rs1_fwd_data;
        rs2_data_o       = rs2_fwd_data;
        jump_en          = 1'b0;
        jump_addr_o      = 32'b0;
        hazard_opcode    = opcode;
        inst_o           = inst_i;
        update_btb_en    = 1'b0;
        update_gshare_en = 1'b0;
        update_target    = 32'b0;
        actual_taken     = 1'b0;
        pred_mispredict  = 1'b0;

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
                update_btb_en   = 1'b1;
                update_target   = jump_target;
                pred_mispredict = (!pred_taken_i) || (pred_pc_i != jump_target);
                jump_en         = pred_mispredict;
                jump_addr_o     = pred_mispredict ? jump_target : 32'b0;
            end

            `TYPE_B: begin
                update_gshare_en = 1'b1;
                actual_taken     = branch_taken;
                pred_mispredict  = pred_taken_i != branch_taken;
                jump_en          = pred_mispredict;

                if (pred_mispredict) begin
                    jump_addr_o = branch_taken ? jump_target : pc_plus4;
                end
                else begin
                    jump_addr_o = 32'b0;
                end
            end

            `TYPE_L: begin
                case (funct3)
                    `LB, `LH, `LW, `LBU, `LHU: begin
                        mem_req    = 1'b1;
                        mem_wen    = 1'b0;
                        mem_addr_o = add_res;
                    end

                    default: begin
                        mem_req    = 1'b0;
                        mem_wen    = 1'b0;
                        mem_addr_o = 32'b0;
                    end
                endcase
            end

            `TYPE_S: begin
                case (funct3)
                    `SB, `SH, `SW: begin
                        mem_req    = 1'b1;
                        mem_wen    = 1'b1;
                        mem_addr_o = add_res;
                    end

                    default: begin
                        mem_req    = 1'b0;
                        mem_wen    = 1'b0;
                        mem_addr_o = 32'b0;
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
                mem_req          = 1'b0;
                mem_wen          = 1'b0;
                mem_addr_o       = 32'b0;
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