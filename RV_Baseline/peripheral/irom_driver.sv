`timescale 1ns / 1ps
module irom_driver(
    input  logic        clk				,

    input  logic [31:0] perip_addr		,
    output logic [31:0] perip_rdata		,

    input  logic        arvalid         ,
    input  logic        ren             ,
    output logic        ready           ,
    output logic        rvalid          
);
    logic [11:0] irom_addr;
    assign irom_addr = perip_addr[13:2];

    IROM Mem_IROM (
        // .clka       (clk),
        // .addra      (irom_addr),
        // .douta      (perip_rdata),
        // .ena        (ren)
        .a              (irom_addr),
        .spo            (perip_rdata)
    );

    // 握手信号
    assign ready = 1'b1;
    always_ff @(posedge clk) begin
        // rvalid      <= (ren) ? arvalid : 0;
    end
    assign rvalid = ren & arvalid;
endmodule
