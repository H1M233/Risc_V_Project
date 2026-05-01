`include "rv32I.vh"

module id(
    // from hazard
    input      [31:0]   forward_rs1_data,
    input               forward_rs1_en,
    input      [31:0]   forward_rs2_data,
    input               forward_rs2_en,

    // from if_id
    input      [31:0]   inst_i,
    input      [31:0]   pc_addr_i,

    // from bpu
    input               pred_taken_i,
    input      [31:0]   pred_pc_i,
    
    // from regs
    input      [31:0]   rs1_data_i,
    input      [31:0]   rs2_data_i,

    // to id_ex
    output reg [31:0]   pc_addr_o,
    output reg [31:0]   inst_o,
    output reg [31:0]   jump1_o,
    output reg [31:0]   jump2_o,
    output reg [4:0]    rd_addr_o,
    output reg          reg_wen,
    output reg [31:0]   rs1_data_o,
    output reg [31:0]   rs2_data_o,
    output reg [31:0]   value1_o,
    output reg [31:0]   value2_o,
    output reg          pred_taken_o,
    output reg [31:0]   pred_pc_o,

    // to regs & hazard
    output reg [4:0]    rs1_addr_o,
    output reg [4:0]    rs2_addr_o
);  
    wire [31:0] data1       = forward_rs1_en ? forward_rs1_data : rs1_data_i;
    wire [31:0] data2       = forward_rs2_en ? forward_rs2_data : rs2_data_i;
    wire [6:0]  opcode      = inst_i[6:0];
    wire [4:0]  rd_o        = inst_i[11:7];
    wire [4:0]  rs1_o       = inst_i[19:15];
    wire [4:0]  rs2_o       = inst_i[24:20];

    always@(*) begin
        pc_addr_o    = pc_addr_i;
        inst_o       = inst_i;
        rs1_data_o   = data1;        
        rs2_data_o   = data2;  
        value1_o     = 32'b0;
        value2_o     = 32'b0;
        jump1_o      = 32'b0;
        jump2_o      = 32'b0;
        reg_wen      = 1'b0;
        rs1_addr_o   = 5'b0;            
        rs2_addr_o   = 5'b0; 
        rd_addr_o    = 5'b0;
        pred_taken_o = pred_taken_i;
        pred_pc_o    = pred_pc_i;

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
                // 分支比较不要在 ID 做，否则 IF_ID.inst -> REGFILE -> compare -> ID_EX.value1 会变成关键路径。
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
                rs1_addr_o  = 5'b0;            
                rs2_addr_o  = 5'b0;  
                rd_addr_o   = 5'b0;
            end
        endcase
    end
endmodule