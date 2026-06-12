`include "alu.vh"
`include "switch.vh"
module alu_lsu(
    input  logic clk,
    input  logic rst,
    input  logic flush,

    input  logic [31:0]  rs1,
    input  logic [31:0]  rs2,
    input  logic [31:0]  mem_addr,
    input  logic [1:0]   addr_low,
    input  logic         regs_wen,
    input  decode_t      ipkg,

    input  logic         atom_req_load,
    input  logic         atom_req_store,
    input  logic [31:0]  atom_addr,
    input  logic [31:0]  atom_wdata,

    output ex_lsu_data_t dpkg
);
    always_comb begin 
        dpkg.req_load   = (ipkg.is_load & regs_wen) | atom_req_load;  // dcache 读使能
        dpkg.req_store  = ipkg.is_store | atom_req_store;             // dcache 写使能
        dpkg.addr       = (atom_req_load | atom_req_store) ? atom_addr : mem_addr;
        dpkg.write_dram = (dpkg.addr >= `DRAM_ADDR_START && dpkg.addr < `DRAM_ADDR_END);

        unique case (1'b1)
            atom_req_store: begin
                dpkg.wdata = atom_wdata;
                dpkg.we    = 4'b1111;
            end
            ipkg.sel_sb: begin // byte
                case (addr_low)
                    2'b00: begin 
                        dpkg.wdata = {24'b0, rs2[7:0]};
                        dpkg.we    = 4'b0001;
                    end
                    2'b01: begin
                        dpkg.wdata = {16'b0, rs2[7:0], 8'b0};
                        dpkg.we    = 4'b0010;
                    end
                    2'b10: begin
                        dpkg.wdata = {8'b0, rs2[7:0], 16'b0};
                        dpkg.we    = 4'b0100;
                    end
                    2'b11: begin
                        dpkg.wdata = {rs2[7:0], 24'b0};
                        dpkg.we    = 4'b1000;
                    end
                    default: begin
                        dpkg.wdata = 32'b0;
                        dpkg.we    = 4'b0000;
                    end
                endcase
            end
            ipkg.sel_sh: begin // half
                case (addr_low[1])
                    1'b0: begin
                        dpkg.wdata = {16'b0, rs2[15:0]};
                        dpkg.we    = 4'b0011;
                    end
                    1'b1: begin
                        dpkg.wdata = {rs2[15:0], 16'b0};
                        dpkg.we    = 4'b1100;
                    end
                    default: begin
                        dpkg.wdata = 32'b0;
                        dpkg.we    = 4'b0000;
                    end
                endcase
            end
            ipkg.sel_sw: begin // word
                dpkg.wdata = rs2;
                dpkg.we    = 4'b1111;
            end
            default: begin
                dpkg.wdata = 32'b0;
                dpkg.we    = 4'b0000;
            end
        endcase
    end

endmodule