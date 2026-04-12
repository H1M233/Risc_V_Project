module open_risc_v_soc(
    input   wire        clk,
    input   wire        rst
);

    // open_risc_v to rom
    wire[31:0]  open_risc_v_inst_addr_o;
    
    // rom to open_risc_v
    wire[31:0]  rom_inst_o;

    // open_risc_v to ram
    wire[31:0]  open_risc_v_r_addr_o;
    wire        open_risc_v_r_en_o;
    wire[3:0]   open_risc_v_w_en_o;
    wire[31:0]  open_risc_v_w_addr_o;
    wire[31:0]  open_risc_v_w_data_o;

    // ram to open_risc_v
    wire[31:0]  ram_r_data_o;

    open_risc_v open_risc_v_inst(
        .clk            (clk),
        .rst            (rst),           

        // rom
        .inst_i         (rom_inst_o),
        .inst_addr_o    (open_risc_v_inst_addr_o),

        // ram - read
        .ram_r_en_o     (open_risc_v_r_en_o),
        .ram_r_addr_o   (open_risc_v_r_addr_o),
        .ram_r_data_i   (ram_r_data_o),

        // ram - write
        .ram_w_en_o     (open_risc_v_w_en_o),
        .ram_w_addr_o   (open_risc_v_w_addr_o),
        .ram_w_data_o   (open_risc_v_w_data_o)
    );

    rom rom_inst(
        .inst_addr_i    (open_risc_v_inst_addr_o),
        .inst_o         (rom_inst_o)
    );

    ram ram_inst(
        .clk            (clk),
        .rst            (rst),
        .w_en_i         (open_risc_v_w_en_o),
        .w_addr_i       (open_risc_v_w_addr_o),
        .w_data_i       (open_risc_v_w_data_o),
        .r_en_i         (open_risc_v_r_en_o),
        .r_addr_i       (open_risc_v_r_addr_o),
        .r_data_o       (ram_r_data_o)
    );

endmodule