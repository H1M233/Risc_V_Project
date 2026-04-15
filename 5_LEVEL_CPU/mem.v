`include "rv32I.vh"

module mem(
    input mem_req,
    input mem_wen,
    input [31:0] mem_addr_i,
    input [31:0] rs2_data_i,
    input [31:0] rd_data_i,
    input [31:0] inst_i,
    input regs_wen,
    input [4:0] rd_addr_i,
    input [31:0] perip_rdata,

    output reg [31:0] rd_data_o,
    output reg [4:0] rd_addr_o,
    output reg regs_wen_o,
    output reg [31:0] perip_addr,
    output reg perip_wen,
    output reg [1:0] perip_mask,
    output reg [31:0] perip_wdata
);
    wire [6:0] opcode;
    wire [2:0] funct3;  
    assign opcode = inst_i[6:0];
    assign funct3 = inst_i[14:12];

    always@(*) begin
        rd_data_o = rd_data_i;
        rd_addr_o = rd_addr_i;
        regs_wen_o = regs_wen;
        perip_addr = mem_addr_i;
        perip_wen = mem_wen && mem_req;
        perip_mask = 2'b00;
        perip_wdata = 32'b0;
        
        case(opcode)
            `TYPE_L: begin
                perip_wdata = 32'b0;
                case(funct3)
                    `LB: begin
                        perip_mask = 2'b00;
                        rd_data_o = {{24{perip_rdata[7]}}, perip_rdata[7:0]};
                    end
                    `LH: begin
                        perip_mask = 2'b01;
                        rd_data_o = {{16{perip_rdata[15]}}, perip_rdata[15:0]};
                    end
                    `LW: begin
                        perip_mask = 2'b10;
                        rd_data_o = perip_rdata;
                    end
                    `LBU: begin
                        perip_mask = 2'b00;
                        rd_data_o = {24'b0, perip_rdata[7:0]};
                    end
                    `LHU: begin
                        perip_mask = 2'b01;
                        rd_data_o = {16'b0, perip_rdata[15:0]};
                    end
                    default: begin
                        perip_mask = 2'b00;
                        rd_data_o = 32'b0;
                    end
                endcase
            end
            `TYPE_S: begin
                case(funct3)
                    `SB: begin
                        perip_mask = 2'b00;
                        perip_wdata = rs2_data_i;
                    end
                    `SH: begin
                        perip_mask = 2'b01;
                        perip_wdata = rs2_data_i;
                    end
                    `SW: begin
                        perip_mask = 2'b10;
                        perip_wdata = rs2_data_i;
                    end
                    default: begin
                        perip_mask = 2'b00;
                        perip_wdata = 32'b0;
                    end
                endcase
            end
            default: begin
                perip_mask = 2'b00;
                perip_wdata = 32'b0;
            end
        endcase
    end
endmodule