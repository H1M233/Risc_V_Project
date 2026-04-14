module DRAM(
    input   wire            clk,
    input   wire[32 - 1:0]  addr_i,
    input   wire[3:0]       w_en_i,       // 分别设置4个写使能
    output  wire[32 - 1:0]  r_data_o
);

    wire[11:0]  w_addr = w_addr_i[13:2];

    // 字节0
    dual_ram #(
        .DW         (8),
        .AW         (12),
        .MEM_NUM    (4096)
    )ram_byte0
    (
        .clk        (clk),
        .rst        (rst),
        .w_addr_i   (w_addr),
        .w_data_i   (w_data_i[7:0]),
        .w_en_i     (w_en_i[0]),
        .r_data_o   (r_data_o[7:0]),
        .r_addr_i   (r_addr),
        .r_en_i     (r_en_i)
    );

    // 字节1
    dual_ram #(
        .DW         (8),
        .AW         (12),
        .MEM_NUM    (4096)
    )ram_byte1
    (
        .clk        (clk),
        .rst        (rst),
        .w_addr_i   (w_addr),
        .w_data_i   (w_data_i[15:8]),
        .w_en_i     (w_en_i[1]),
        .r_data_o   (r_data_o[15:8]),
        .r_addr_i   (r_addr),
        .r_en_i     (r_en_i)
    );

    // 字节2
    dual_ram #(
        .DW         (8),
        .AW         (12),
        .MEM_NUM    (4096)
    )ram_byte2
    (
        .clk        (clk),
        .rst        (rst),
        .w_addr_i   (w_addr),
        .w_data_i   (w_data_i[23:16]),
        .w_en_i     (w_en_i[2]),
        .r_data_o   (r_data_o[23:16]),
        .r_addr_i   (r_addr),
        .r_en_i     (r_en_i)
    );

    // 字节3
    dual_ram #(
        .DW         (8),
        .AW         (12),
        .MEM_NUM    (4096)
    )ram_byte3
    (
        .clk        (clk),
        .rst        (rst),
        .w_addr_i   (w_addr),
        .w_data_i   (w_data_i[31:24]),
        .w_en_i     (w_en_i[3]),
        .r_data_o   (r_data_o[31:24]),
        .r_addr_i   (r_addr),
        .r_en_i     (r_en_i)
    );
endmodule