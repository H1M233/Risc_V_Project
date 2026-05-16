`include "rv32I.vh"
`include "alu.vh"

module id(
    // from if_id
    input      [31:0]   inst_i,             // 从if_id模块传来的指令内容
    input      [31:0]   pc_addr_i,          // 从if_id模块传来的指令地址

    // from bpu
    input               pred_taken_i,
    input      [31:0]   pred_pc_i,
    
    // from regs
    input      [31:0]   rs1_data_i,         // 从寄存器堆读出的寄存rs1的数据
    input      [31:0]   rs2_data_i,         // 从寄存器堆读出的寄存rs2的数据

    // to id_ex
    output reg [31:0]   pc_addr_o,
    output reg [31:0]   inst_o,             // 传入给id_ex模块的指令内容
    output reg [31:0]   jump1_o,            // 传入跳转指令地址1
    output reg [31:0]   jump2_o,            // 传入跳转指令地址2
    output reg [4:0]    rd_addr_o,          // 传入指令rd地址
    output reg          reg_wen,            // 寄存器写使能信号
    output reg [31:0]   value1_o,           // 传入寄存器1的数据
    output reg [31:0]   value2_o,           // 传入寄存器2的数据
    output reg          pred_taken_o,
    output reg [31:0]   pred_pc_o,
    output reg [`OP_INST_NUM - 1:0] inst_packaged_o,

    // to regs & hazard & forwarding
    (* max_fanout = 30 *)
    output reg [4:0]    rs1_addr_o,
    (* max_fanout = 30 *)
    output reg [4:0]    rs2_addr_o,
    output reg [31:0]   rs1_data_o,
    output reg [31:0]   rs2_data_o
);  
    // 提取指令
    wire [31:0] data1       = rs1_data_i;
    wire [31:0] data2       = rs2_data_i;
    wire [6:0]  opcode      = inst_i[6:0];              // 传入指令opcode
    wire [2:0]  funct3      = inst_i[14:12];
    wire [6:0]  funct7      = inst_i[31:25];
    wire [4:0]  rd_o        = inst_i[11:7];             // 传入指令rd地址
    wire [4:0]  rs1_o       = inst_i[19:15];            // 传入指令rs1地址
    wire [4:0]  rs2_o       = inst_i[24:20];            // 传入指令rs2地址

    // opcode
    wire is_alu_i  = (opcode == `TYPE_I);
    wire is_alu_r  = (opcode == `TYPE_R);
    wire is_auipc  = (opcode == `AUIPC);
    wire is_lui    = (opcode == `LUI);
    wire is_jal    = (opcode == `JAL);
    wire is_jalr   = (opcode == `JALR);
    wire is_branch = (opcode == `TYPE_B);
    wire is_load   = (opcode == `TYPE_L);
    wire is_store  = (opcode == `TYPE_S);

    // f3
    wire f3_000 = (funct3 == 3'b000);
    wire f3_001 = (funct3 == 3'b001);
    wire f3_010 = (funct3 == 3'b010);
    wire f3_011 = (funct3 == 3'b011);
    wire f3_100 = (funct3 == 3'b100);
    wire f3_101 = (funct3 == 3'b101);
    wire f3_110 = (funct3 == 3'b110);
    wire f3_111 = (funct3 == 3'b111);

    // f7
    wire f7_0000000 = (funct7 == 7'b0000000);
    wire f7_0100000 = (funct7 == 7'b0100000);

    // 打包指令
    always @(*) begin
        // opcode
        inst_packaged_o[`OP_I]      = is_alu_i;
        inst_packaged_o[`OP_R]      = is_alu_r;
        inst_packaged_o[`OP_AUIPC]  = is_auipc;
        inst_packaged_o[`OP_LUI]    = is_lui;
        inst_packaged_o[`OP_JAL]    = is_jal;
        inst_packaged_o[`OP_JALR]   = is_jalr;
        inst_packaged_o[`OP_BRANCH] = is_branch;
        inst_packaged_o[`OP_LOAD]   = is_load;
        inst_packaged_o[`OP_STORE]  = is_store;

        // IR-type
        inst_packaged_o[`INST_IR_ADD]  = (is_alu_r & f3_000 & f7_0000000) | (is_alu_i & f3_000);
        inst_packaged_o[`INST_R_SUB]   = is_alu_r & f3_000 & f7_0100000;
        inst_packaged_o[`INST_IR_XOR]  = (is_alu_r | is_alu_i) & f3_100;
        inst_packaged_o[`INST_IR_OR]   = (is_alu_r | is_alu_i) & f3_110;
        inst_packaged_o[`INST_IR_AND]  = (is_alu_r | is_alu_i) & f3_111;
        inst_packaged_o[`INST_IR_SLL]  = (is_alu_r | is_alu_i) & f3_001;
        inst_packaged_o[`INST_IR_SRL]  = (is_alu_r | is_alu_i) & f3_101 & f7_0000000;
        inst_packaged_o[`INST_IR_SRA]  = (is_alu_r | is_alu_i) & f3_101 & f7_0100000;
        inst_packaged_o[`INST_IR_SLT]  = (is_alu_r | is_alu_i) & f3_010;
        inst_packaged_o[`INST_IR_SLTU] = (is_alu_r | is_alu_i) & f3_011;

        // Load & Store
        inst_packaged_o[`INST_LB]  = is_load & f3_000;
        inst_packaged_o[`INST_LH]  = is_load & f3_001;
        inst_packaged_o[`INST_LW]  = is_load & f3_010;
        inst_packaged_o[`INST_LBU] = is_load & f3_100;
        inst_packaged_o[`INST_LHU] = is_load & f3_101;
        inst_packaged_o[`INST_SB]  = is_store & f3_000;
        inst_packaged_o[`INST_SH]  = is_store & f3_001;
        inst_packaged_o[`INST_SW]  = is_store & f3_010;

        // Branch
        inst_packaged_o[`INST_BEQ]  = is_branch & f3_000;
        inst_packaged_o[`INST_BNE]  = is_branch & f3_001;
        inst_packaged_o[`INST_BLT]  = is_branch & f3_100;
        inst_packaged_o[`INST_BGE]  = is_branch & f3_101;
        inst_packaged_o[`INST_BLTU] = is_branch & f3_110;
        inst_packaged_o[`INST_BGEU] = is_branch & f3_111;

        // 纯数值计算独热
        inst_packaged_o[`REQUEST_VALUE_ONLY] = is_auipc | is_lui | is_jal | is_jalr;
    end

    always@(*) begin
        pc_addr_o       = pc_addr_i;
        inst_o          = inst_i;
        rs1_data_o      = data1;        
        rs2_data_o      = data2;  
        value1_o        = 32'b0;
        value2_o        = 32'b0;
        jump1_o         = 32'b0;
        jump2_o         = 32'b0;
        reg_wen         = 1'b0;
        rs1_addr_o      = 5'b0;            
        rs2_addr_o      = 5'b0; 
        rd_addr_o       = 5'b0;
        pred_taken_o    = pred_taken_i;
        pred_pc_o       = pred_pc_i;

        case(opcode)
            `LUI: begin
                reg_wen     = 1'b1;             
                value1_o    = {inst_i[31:12], 12'b0};   
                value2_o    = 32'd0;
                rs1_addr_o  = 5'b0;            
                rs2_addr_o  = 5'b0; 
                rd_addr_o   = rd_o;
            end

            `AUIPC: begin
                reg_wen     = 1'b1;
                value1_o    = pc_addr_i + {inst_i[31:12], 12'b0};
                value2_o    = 32'b0;
                rs1_addr_o  = 5'b0;            
                rs2_addr_o  = 5'b0;  
                rd_addr_o   = rd_o;  
            end

            `JAL: begin
                reg_wen     = 1'b1;              
                value1_o    = pc_addr_i + 32'd4;          
                value2_o    = 32'b0;             
                jump1_o     = pc_addr_i;   
                jump2_o     = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
                rs1_addr_o  = 5'b0;            
                rs2_addr_o  = 5'b0;  
                rd_addr_o   = rd_o;
            end

            `JALR: begin
                reg_wen     = 1'b1;              
                value1_o    = pc_addr_i + 32'd4;          
                value2_o    = 32'b0;             
                jump1_o     = data1;   
                jump2_o     = {{20{inst_i[31]}}, inst_i[31:20]};
                rs1_addr_o  = rs1_o;            
                rs2_addr_o  = 5'b0;  
                rd_addr_o   = rd_o;
            end

            `TYPE_B: begin
                value1_o    = data1;
                value2_o    = data2;
                jump1_o     = pc_addr_i + {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                rs1_addr_o  = rs1_o;            
                rs2_addr_o  = rs2_o;  
                rd_addr_o   = 5'b0;
            end

            `TYPE_L: begin
                reg_wen     = 1'b1;
                value1_o    = data1;
                value2_o    = {{20{inst_i[31]}}, inst_i[31:20]};
                rs1_addr_o  = rs1_o;            
                rs2_addr_o  = 5'b0;  
                rd_addr_o   = rd_o;
            end

            `TYPE_S: begin
                value1_o    = data1;
                value2_o    = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                rs1_addr_o  = rs1_o;            
                rs2_addr_o  = rs2_o;  
                rd_addr_o   = 5'b0;
            end

            `TYPE_I: begin
                reg_wen     = 1'b1;
                value1_o    = data1;
                value2_o    = {{20{inst_i[31]}}, inst_i[31:20]};
                rs1_addr_o  = rs1_o;
                rs2_addr_o  = 5'b0;
                rd_addr_o   = rd_o;
            end

            `TYPE_R: begin
                reg_wen     = 1'b1;
                value1_o    = data1;
                value2_o    = data2;
                rs1_addr_o  = rs1_o;
                rs2_addr_o  = rs2_o;
                rd_addr_o   = rd_o;
            end

            default: begin
                reg_wen     = 1'b0;
                value1_o    = 32'b0;
                value2_o    = 32'b0;
                jump1_o     = 32'b0;
                jump2_o     = 32'b0;
                rs1_addr_o  = 5'b0;            
                rs2_addr_o  = 5'b0;  
                rd_addr_o   = 5'b0;
            end
        endcase
    end
endmodule