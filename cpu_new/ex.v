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
    input      [31:0]   value1_i,
    input      [31:0]   value2_i,
    input               pred_taken_i,
    input      [31:0]   pred_pc_i,

    // to hazard
    output     [6:0]    hazard_opcode,

    // to ex_mem
    output reg [31:0]   inst_o,
    output reg [31:0]   mem_addr_o,
    output              mem_req,
    output              mem_wen,
    output reg          regs_wen_o,
    output reg [31:0]   rs2_data_o,

    // to ex_mem & hazard
    output reg [4:0]    rd_addr_o,
    output reg [31:0]   rd_data_o,

    // to jump
    output reg [31:0]   jump_addr_o,
    output reg          jump_en,

    // unused
    output reg [31:0]   rs1_data_o,

    // to bpu
    output              update_btb_en,
    output              update_gshare_en,
    output reg [31:0]   pc_addr_o,
    output reg [31:0]   update_target,
    output reg          actual_taken,
    output reg          pred_mispredict
);
    wire [6:0] opcode = inst_i[6:0];
    wire [2:0] funct3 = inst_i[14:12];
    wire [6:0] funct7 = inst_i[31:25];

    wire is_lui    = (opcode == `LUI);
    wire is_auipc  = (opcode == `AUIPC);
    wire is_jal    = (opcode == `JAL);
    wire is_jalr   = (opcode == `JALR);
    wire is_branch = (opcode == `TYPE_B);
    wire is_load   = (opcode == `TYPE_L);
    wire is_store  = (opcode == `TYPE_S);
    wire is_type_i = (opcode == `TYPE_I);
    wire is_type_r = (opcode == `TYPE_R);

    assign hazard_opcode   = opcode;
    assign mem_req         = is_load | is_store;
    assign mem_wen         = is_store;
    assign update_btb_en   = is_jalr;
    assign update_gshare_en= is_branch;

    wire [31:0] add_result  = value1_i + value2_i;
    wire [31:0] sub_result  = value1_i - value2_i;
    wire [31:0] jump_target = jump1_i + jump2_i;

    wire        eq_result   = (value1_i == value2_i);
    wire        slt_result  = ($signed(value1_i) < $signed(value2_i));
    wire        sltu_result = (value1_i < value2_i);

    reg [31:0] alu_result;
    reg        branch_taken;

    // ALU 结果
    always @(*) begin
        alu_result = 32'b0;

        if(is_lui || is_auipc || is_jal || is_jalr) begin
            alu_result = add_result;
        end
        else if(is_type_i) begin
            case(funct3)
                `ADDI:      alu_result = add_result;
                `SLTI:      alu_result = {31'b0, slt_result};
                `SLTIU:     alu_result = {31'b0, sltu_result};
                `XORI:      alu_result = value1_i ^ value2_i;
                `ORI:       alu_result = value1_i | value2_i;
                `ANDI:      alu_result = value1_i & value2_i;
                `SLLI:      alu_result = value1_i << value2_i[4:0];
                `SRLI_SRAI: begin
                    if(funct7 == 7'b0000000)
                        alu_result = value1_i >> value2_i[4:0];
                    else if(funct7 == 7'b0100000)
                        alu_result = $signed(value1_i) >>> value2_i[4:0];
                    else
                        alu_result = 32'b0;
                end
                default: begin
                    alu_result = 32'b0;
                end
            endcase
        end
        else if(is_type_r) begin
            case(funct3)
                `ADD_SUB: begin
                    if(funct7 == 7'b0000000)
                        alu_result = add_result;
                    else if(funct7 == 7'b0100000)
                        alu_result = sub_result;
                    else
                        alu_result = 32'b0;
                end
                `SLL: begin
                    alu_result = value1_i << value2_i[4:0];
                end
                `SLT: begin
                    alu_result = {31'b0, slt_result};
                end
                `SLTU: begin
                    alu_result = {31'b0, sltu_result};
                end
                `XOR: begin
                    alu_result = value1_i ^ value2_i;
                end
                `SRL_SRA: begin
                    if(funct7 == 7'b0000000)
                        alu_result = value1_i >> value2_i[4:0];
                    else if(funct7 == 7'b0100000)
                        alu_result = $signed(value1_i) >>> value2_i[4:0];
                    else
                        alu_result = 32'b0;
                end
                `OR: begin
                    alu_result = value1_i | value2_i;
                end
                `AND: begin
                    alu_result = value1_i & value2_i;
                end
                default: begin
                    alu_result = 32'b0;
                end
            endcase
        end
    end

    // 分支是否真实跳转
    always @(*) begin
        branch_taken = 1'b0;

        case(funct3)
            `BEQ:  branch_taken = eq_result;
            `BNE:  branch_taken = ~eq_result;
            `BLT:  branch_taken = slt_result;
            `BGE:  branch_taken = ~slt_result;
            `BLTU: branch_taken = sltu_result;
            `BGEU: branch_taken = ~sltu_result;
            default: begin
                branch_taken = 1'b0;
            end
        endcase
    end

    // 输出控制
    always @(*) begin
        pc_addr_o       = pc_addr_i;
        inst_o          = inst_i;

        regs_wen_o      = regs_wen_i;
        rd_addr_o       = rd_addr_i;
        rd_data_o       = alu_result;

        rs1_data_o      = rs1_data_i;
        rs2_data_o      = rs2_data_i;

        mem_addr_o      = 32'b0;

        jump_en         = 1'b0;
        jump_addr_o     = 32'b0;

        update_target   = 32'b0;
        actual_taken    = 1'b0;
        pred_mispredict = 1'b0;

        if(is_load || is_store) begin
            mem_addr_o = add_result;
        end

        if(is_jalr) begin
            update_target   = jump_target;
            pred_mispredict = (!pred_taken_i) || (pred_pc_i != jump_target);
            jump_en         = pred_mispredict;
            jump_addr_o     = pred_mispredict ? jump_target : 32'b0;
        end
        else if(is_branch) begin
            actual_taken    = branch_taken;
            pred_mispredict = (pred_taken_i != branch_taken);
            jump_en         = pred_mispredict;

            if(pred_mispredict) begin
                jump_addr_o = branch_taken ? jump_target : (pc_addr_i + 32'h4);
            end
            else begin
                jump_addr_o = 32'b0;
            end
        end
    end

endmodule