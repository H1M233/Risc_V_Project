`include "rv32I.vh"
module id(
    // from hazard
    input      [31:0]   forward_rs1_data,
    input               forward_rs1_en,
    input      [31:0]   forward_rs2_data,
    input               forward_rs2_en,

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
    output reg [31:0]   rs1_data_o,
    output reg [31:0]   rs2_data_o,
    output reg [31:0]   value1_o,           // 传入寄存器1的数据
    output reg [31:0]   value2_o,           // 传入寄存器2的数据
    output reg          pred_taken_o,
    output reg [31:0]   pred_pc_o,

    // to regs & hazard
    output reg [4:0]    rs1_addr_o,
    output reg [4:0]    rs2_addr_o
);  
    // 提取指令
    wire [31:0] data1       = forward_rs1_en ? forward_rs1_data : rs1_data_i;
    wire [31:0] data2       = forward_rs2_en ? forward_rs2_data : rs2_data_i;
    wire [6:0]  opcode      = inst_i[6:0];              // 传入指令opcode
    wire [2:0]  funct3      = inst_i[14:12];            // 传入指令funct3
    wire [6:0]  funct7      = inst_i[31:25];            // 传入指令funct7
    wire [4:0]  rd_o        = inst_i[11:7];             // 传入指令rd地址
    wire [4:0]  rs1_o       = inst_i[19:15];            // 传入指令rs1地址
    wire [4:0]  rs2_o       = inst_i[24:20];            // 传入指令rs2地址

    always@(*) begin
        pc_addr_o   = pc_addr_i;
        inst_o      = inst_i;
        rs1_data_o  = data1;        
        rs2_data_o  = data2;  
        value1_o    = 32'b0;
        value2_o    = 32'b0;
        jump1_o     = 32'b0;
        jump2_o     = 32'b0;
        reg_wen     = 1'b0;
        rs1_addr_o  = 5'b0;            
        rs2_addr_o  = 5'b0; 
        rd_addr_o   = 5'b0;
        pred_taken_o = pred_taken_i;
        pred_pc_o   = pred_pc_i;
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
                value1_o    = pc_addr_i;                
                value2_o    = {inst_i[31:12], 12'b0};
                rs1_addr_o  = 5'b0;            
                rs2_addr_o  = 5'b0;  
                rd_addr_o   = rd_o;  
            end
            `JAL: begin
                reg_wen     = 1'b1;              
                value1_o    = pc_addr_i;          
                value2_o    = 32'd4;             
                jump1_o     = pc_addr_i;   
                jump2_o     = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
                rs1_addr_o  = 5'b0;            
                rs2_addr_o  = 5'b0;  
                rd_addr_o   = rd_o;
            end
            `JALR: begin
                reg_wen     = 1'b1;              
                value1_o    = pc_addr_i;          
                value2_o    = 32'd4;             
                jump1_o     = data1;   
                jump2_o     = {{20{inst_i[31]}}, inst_i[31:20]};
                rs1_addr_o  = rs1_o;            
                rs2_addr_o  = 5'b0;  
                rd_addr_o   = rd_o;
            end
            `TYPE_B: begin
                value1_o    = data1;
                value2_o    = data2;
                jump1_o     = pc_addr_i;
                jump2_o     = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
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
                rs2_addr_o  = 5'b0;  
                rs1_addr_o  = 5'b0;            
                rd_addr_o   = 5'b0;
            end
        endcase
    end
endmodule