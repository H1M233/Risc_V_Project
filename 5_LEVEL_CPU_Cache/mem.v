`include "rv32I.vh"

module mem(
    // from ex_mem
    input      [31:0]   inst_i,
    input      [4:0]    rd_addr_i,
    input      [31:0]   rd_data_i,
    input               regs_wen,
    input               mem_req_load_i,

    // from DRAM
    (* max_fanout = 30 *)
    input      [31:0]   perip_rdata,

    // to mem_wb
    (* max_fanout = 30 *)
    output reg [31:0]   rd_data_o,
    (* max_fanout = 30 *)
    output reg          regs_wen_o,

    // to mem_wb & hazrd
    (* max_fanout = 30 *)
    output reg [4:0]    rd_addr_o,

    // dcache_ack
    input               dcache_ack
);
    wire [6:0]  opcode  = inst_i[6:0];
    wire [2:0]  funct3  = inst_i[14:12];

    always@(*) begin
        rd_data_o   = rd_data_i;
        rd_addr_o   = rd_addr_i;
        regs_wen_o  = mem_req_load_i ? dcache_ack : regs_wen;    // 添加与 Dcache 的握手机制来保证 LOAD 正确
        
        case(opcode)
            `TYPE_L: begin
                case(funct3)
                    `LB: begin
                        rd_data_o   = {{24{perip_rdata[7]}}, perip_rdata[7:0]};
                    end
                    `LH: begin
                        rd_data_o   = {{16{perip_rdata[15]}}, perip_rdata[15:0]};
                    end
                    `LW: begin
                        rd_data_o   = perip_rdata;
                    end
                    `LBU: begin
                        rd_data_o   = {24'b0, perip_rdata[7:0]};
                    end
                    `LHU: begin
                        rd_data_o   = {16'b0, perip_rdata[15:0]};
                    end
                    default: begin
                        rd_data_o   = 32'b0;
                    end
                endcase
            end
            `TYPE_S: begin
                // ...
            end
            default: begin
                // ...
            end
        endcase
    end
endmodule