`include "rv32I.vh"
module id(
    input [31:0] inst_i,          // 从if_id模块传来的指令内�?
    input [31:0] pc_addr_i,     // 从if_id模块传来的指令地�?
    input [31:0] rs1_data_i,   // 从寄存器堆读出的寄存�?1的�??
    input [31:0] rs2_data_i,   // 从寄存器堆读出的寄存�?2的�??
    input forward_rs1_en,
    input forward_rs2_en,
    input [31:0] forward_rs1_data,
    input [31:0] forward_rs2_data,

    output reg [31:0] inst_o,             // 传�?�给id_ex模块的指令内�?

    output reg [31:0] value1_o,       // 传�?�寄存器1的�??
    output reg [31:0] value2_o,        // 传�?�寄存器2的�??
    output reg [31:0] jump1_o,       // 传�?�指令地�?
    output reg [31:0] jump2_o,         // 传�?�指令地�?
    output reg reg_wen,              // 寄存器写使能信号
    output reg [31:0] rs1_data_o, 
    output reg [31:0] rs2_data_o,
    output reg [4:0] rs1_addr_o,
    output reg [4:0] rs2_addr_o,
    output reg [4:0] rd_addr_o      // 传�?�指令rd地址   
);  
    wire [31:0] data1;
    wire [31:0] data2;
    assign data1 = forward_rs1_en ? forward_rs1_data : rs1_data_i;   
    assign data2 = forward_rs2_en ? forward_rs2_data : rs2_data_i;
    wire [6:0] opcode_o;         // 传�?�指令opcode
    wire [2:0] funct3_o;         // 传�?�指令funct3
    wire [6:0] funct7_o;         // 传�?�指令funct7
    wire [4:0] rd_o;             // 传�?�指令rd地址
    wire [4:0] rs1_o;            // 传�?�指令rs1地址
    wire [4:0] rs2_o;             // 传�?�指令rs2地址

    assign opcode_o = inst_i[6:0];       // 从指令内容中提取opcode
    assign funct3_o = inst_i[14:12];     // 从指令内容中提取funct3
    assign funct7_o = inst_i[31:25];     // 从指令内容中提取funct7
    assign rd_o = inst_i[11:7];          // 从指令内容中提取rd地址
    assign rs1_o = inst_i[19:15];        // 从指令内容中提取rs1地址
    assign rs2_o = inst_i[24:20];        // 从指令内容中提取rs2地址


    always@(*) begin
        inst_o = inst_i;
        rs1_data_o = data1;        
        rs2_data_o = data2;  
        value1_o = 32'b0;
        value2_o = 32'b0;
        jump1_o = 32'b0;
        jump2_o = 32'b0;
        reg_wen = 1'b0;
        rs1_addr_o = 5'b0;            
        rs2_addr_o = 5'b0; 
        rd_addr_o = 5'b0;

        case(opcode_o)
            `LUI: begin
                reg_wen = 1'b1;             
                value1_o = {inst_i[31:12], 12'b0};   
                value2_o = 32'd0;
                rs1_addr_o = 5'b0;            
                rs2_addr_o = 5'b0; 
                rd_addr_o = rd_o;
            end
            `AUIPC: begin
                reg_wen = 1'b1;             
                value1_o = pc_addr_i;                
                value2_o = {inst_i[31:12], 12'b0};
                rs1_addr_o = 5'b0;            
                rs2_addr_o = 5'b0;  
                rd_addr_o = rd_o;  
            end
            `JAL: begin
                reg_wen = 1'b1;              
                value1_o = pc_addr_i;          
                value2_o = 32'd4;             
                jump1_o = pc_addr_i;   
                jump2_o = {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
                rs1_addr_o = 5'b0;            
                rs2_addr_o = 5'b0;  
                rd_addr_o = rd_o;
            end
            `JALR: begin
                reg_wen = 1'b1;              
                value1_o = pc_addr_i;          
                value2_o = 32'd4;             
                jump1_o = data1;   
                jump2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                rs1_addr_o = rs1_o;            
                rs2_addr_o = 5'b0;  
                rd_addr_o = rd_o;
            end
            `TYPE_B: begin
                value1_o = data1;
                value2_o = data2;
                jump1_o = pc_addr_i;
                jump2_o = {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                rs1_addr_o = rs1_o;            
                rs2_addr_o = rs2_o;  
                rd_addr_o = 5'b0;
            end
            `TYPE_L: begin
                reg_wen = 1'b1;
                value1_o = data1;
                value2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                rs1_addr_o = rs1_o;            
                rs2_addr_o = 5'b0;  
                rd_addr_o = rd_o;
            end
            `TYPE_S: begin
                value1_o = data1;
                value2_o = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                rs1_addr_o = rs1_o;            
                rs2_addr_o = rs2_o;  
                rd_addr_o = 5'b0;
            end
            `TYPE_I: begin
                reg_wen = 1'b1;
                value1_o = data1;
                value2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                rs1_addr_o = rs1_o;
                rs2_addr_o = 5'b0;
                rd_addr_o = rd_o;
            end
            `TYPE_R: begin
                reg_wen = 1'b1;
                value1_o = data1;
                value2_o = data2;
                rs1_addr_o = rs1_o;
                rs2_addr_o = rs2_o;
                rd_addr_o = rd_o;
            end
            default: begin
                reg_wen = 1'b0;
                value1_o = 32'b0;
                value2_o = 32'b0;
                jump1_o = 32'b0;
                jump2_o = 32'b0;
                rs1_addr_o = 5'b0;            
                rs2_addr_o = 5'b0;  
                rd_addr_o = 5'b0;
            end
        endcase
    end
endmodule