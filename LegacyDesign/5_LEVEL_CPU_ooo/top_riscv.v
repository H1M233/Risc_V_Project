`include "rv32I.vh"

module top_riscv #(
    parameter USE_OOO = 1
)(
    input           cpu_rst,
    input           cpu_clk,

    output  [31:0]  irom_addr,
    input   [31:0]  irom_data,

    output  [31:0]  perip_addr,
    output  [3:0]   perip_we,
    output          perip_wen,
    output  [31:0]  perip_wdata,
    input   [31:0]  perip_rdata
);

    generate
        if (USE_OOO) begin : gen_ooo
            ooo_core #(
                .OOO_USE_BPU(0)
            ) CORE (
                .cpu_rst     (cpu_rst),
                .cpu_clk     (cpu_clk),
                .irom_addr   (irom_addr),
                .irom_data   (irom_data),
                .perip_addr  (perip_addr),
                .perip_we    (perip_we),
                .perip_wen   (perip_wen),
                .perip_wdata (perip_wdata),
                .perip_rdata (perip_rdata)
            );
        end else begin : gen_inorder
            top_riscv_inorder CORE (
                .cpu_rst     (cpu_rst),
                .cpu_clk     (cpu_clk),
                .irom_addr   (irom_addr),
                .irom_data   (irom_data),
                .perip_addr  (perip_addr),
                .perip_we    (perip_we),
                .perip_wen   (perip_wen),
                .perip_wdata (perip_wdata),
                .perip_rdata (perip_rdata)
            );
        end
    endgenerate

endmodule
