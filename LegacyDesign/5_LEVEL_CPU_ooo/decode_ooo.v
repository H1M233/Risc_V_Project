`include "ooo_defs.vh"

module decode_ooo (
    input  [31:0]  inst,
    input  [31:0]  pc,
    input          pred_taken,
    input  [31:0]  pred_pc,
    output [6:0]   opcode,
    output [2:0]   funct3,
    output [6:0]   funct7,
    output [4:0]   rs1,
    output [4:0]   rs2,
    output [4:0]   rd,
    output         uses_rs1,
    output         uses_rs2,
    output         reg_wen,
    output         is_load,
    output         is_store,
    output         is_branch,
    output         is_jal,
    output         is_jalr,
    output         is_lui,
    output         is_auipc,
    output         is_control,
    output         is_mem,
    output [31:0]  imm,
    output [3:0]   alu_op,
    output [1:0]   mem_size,
    output         mem_unsigned,
    output [1:0]   op_class,
    output [2:0]   branch_type
);

    assign opcode = inst[6:0];
    assign funct3 = inst[14:12];
    assign funct7 = inst[31:25];
    assign rs1    = inst[19:15];
    assign rs2    = inst[24:20];
    assign rd     = inst[11:7];

    wire [31:0] imm_i = {{20{inst[31]}}, inst[31:20]};
    wire [31:0] imm_s = {{20{inst[31]}}, inst[31:25], inst[11:7]};
    wire [31:0] imm_b = {{20{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    wire [31:0] imm_u = {inst[31:12], 12'b0};
    wire [31:0] imm_j = {{12{inst[31]}}, inst[19:12], inst[20], inst[30:21], 1'b0};

    wire op_lui    = (opcode == `LUI);
    wire op_auipc  = (opcode == `AUIPC);
    wire op_jal    = (opcode == `JAL);
    wire op_jalr   = (opcode == `JALR);
    wire op_branch = (opcode == `TYPE_B);
    wire op_load   = (opcode == `TYPE_L);
    wire op_store  = (opcode == `TYPE_S);
    wire op_i_alu  = (opcode == `TYPE_I);
    wire op_r_alu  = (opcode == `TYPE_R);

    assign is_lui     = op_lui;
    assign is_auipc   = op_auipc;
    assign is_load    = op_load;
    assign is_store   = op_store;
    assign is_branch  = op_branch;
    assign is_jal     = op_jal;
    assign is_jalr    = op_jalr;
    assign is_control = op_branch | op_jal | op_jalr;
    assign is_mem     = op_load | op_store;

    assign uses_rs1 = op_jalr | op_branch | op_load | op_store | op_i_alu | op_r_alu;
    assign uses_rs2 = op_branch | op_store | op_r_alu;
    assign reg_wen  = op_lui | op_auipc | op_jal | op_jalr | op_load | op_i_alu | op_r_alu;

    // immediate
    reg [31:0] imm_val;
    always @(*) begin
        case (1'b1)
            op_lui, op_auipc: imm_val = imm_u;
            op_jal:           imm_val = imm_j;
            op_jalr:          imm_val = imm_i;
            op_branch:        imm_val = imm_b;
            op_load, op_i_alu:imm_val = imm_i;
            op_store:         imm_val = imm_s;
            default:          imm_val = 32'b0;
        endcase
    end
    assign imm = imm_val;

    // ALU op
    reg [3:0] alu_op_val;
    always @(*) begin
        alu_op_val = `ALU_ADD;
        if (op_lui)        alu_op_val = `ALU_LUI;
        else if (op_auipc)  alu_op_val = `ALU_AUIPC;
        else if (op_jal)    alu_op_val = `ALU_ADD;
        else if (op_jalr)   alu_op_val = `ALU_ADD;
        else if (op_branch) alu_op_val = `ALU_SUB;
        else if (op_load)   alu_op_val = `ALU_ADD;
        else if (op_store)  alu_op_val = `ALU_ADD;
        else if (op_i_alu) begin
            case (funct3)
                `ADDI:      alu_op_val = `ALU_ADD;
                `SLTI:      alu_op_val = `ALU_SLT;
                `SLTIU:     alu_op_val = `ALU_SLTU;
                `XORI:      alu_op_val = `ALU_XOR;
                `ORI:       alu_op_val = `ALU_OR;
                `ANDI:      alu_op_val = `ALU_AND;
                `SLLI:      alu_op_val = `ALU_SLL;
                `SRLI_SRAI: alu_op_val = (funct7[5]) ? `ALU_SRA : `ALU_SRL;
                default:    alu_op_val = `ALU_ADD;
            endcase
        end else if (op_r_alu) begin
            case (funct3)
                `ADD_SUB: alu_op_val = (funct7[5]) ? `ALU_SUB : `ALU_ADD;
                `SLL:     alu_op_val = `ALU_SLL;
                `SLT:     alu_op_val = `ALU_SLT;
                `SLTU:    alu_op_val = `ALU_SLTU;
                `XOR:     alu_op_val = `ALU_XOR;
                `SRL_SRA: alu_op_val = (funct7[5]) ? `ALU_SRA : `ALU_SRL;
                `OR:      alu_op_val = `ALU_OR;
                `AND:     alu_op_val = `ALU_AND;
                default:  alu_op_val = `ALU_ADD;
            endcase
        end
    end
    assign alu_op = alu_op_val;

    // memory size
    reg [1:0] mem_size_val;
    reg       mem_unsigned_val;
    always @(*) begin
        mem_size_val     = 2'b10;
        mem_unsigned_val = 1'b0;
        if (op_load) begin
            case (funct3)
                `LB:  begin mem_size_val = 2'b00; mem_unsigned_val = 1'b0; end
                `LH:  begin mem_size_val = 2'b01; mem_unsigned_val = 1'b0; end
                `LW:  begin mem_size_val = 2'b10; mem_unsigned_val = 1'b0; end
                `LBU: begin mem_size_val = 2'b00; mem_unsigned_val = 1'b1; end
                `LHU: begin mem_size_val = 2'b01; mem_unsigned_val = 1'b1; end
                default:;
            endcase
        end else if (op_store) begin
            case (funct3)
                `SB: mem_size_val = 2'b00;
                `SH: mem_size_val = 2'b01;
                `SW: mem_size_val = 2'b10;
                default:;
            endcase
        end
    end
    assign mem_size     = mem_size_val;
    assign mem_unsigned = mem_unsigned_val;

    // op_class
    reg [1:0] oc;
    always @(*) begin
        if (is_branch || is_jalr) oc = `OPCLASS_BRANCH;
        else if (is_jal)          oc = `OPCLASS_BRANCH;
        else if (is_mem)          oc = `OPCLASS_MEM;
        else                      oc = `OPCLASS_ALU;
    end
    assign op_class = oc;

    // branch_type: funct3 for B-type, BR_JAL for JAL, BR_JALR for JALR
    reg [2:0] bt;
    always @(*) begin
        if (op_branch) bt = funct3;
        else if (op_jal)  bt = `BR_JAL;
        else if (op_jalr) bt = `BR_JALR;
        else              bt = 3'b000;
    end
    assign branch_type = bt;

endmodule
