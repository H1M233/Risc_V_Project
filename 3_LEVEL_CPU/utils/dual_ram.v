
    // 采用时序ram可以减少资源占用

    module dual_ram #(
        parameter DW = 32,          // 位宽
        parameter AW = 12,          // 地址线
        parameter MEM_NUM = 4096    // 深度
    )
    (
        input   wire            clk,
        input   wire            rst,

        // 写入
        input   wire[AW - 1:0]  w_addr_i,
        input   wire[DW - 1:0]  w_data_i,
        input   wire            w_en_i,
        
        // 读取
        output  wire[DW - 1:0]  r_data_o,
        input   wire[AW - 1:0]  r_addr_i,
        input   wire            r_en_i
    );

        // RAM读需要两个周期, 写只需要一个周期
        // 处理读写冲突(读写同一地址): 当同时读写时, 应读上一时钟周期的值
        reg             r_w_flag;       // 是否冲突
        reg[DW - 1:0]   w_data_reg;     // w_data_i在上一时钟周期的值
        wire[DW - 1:0]  r_data_wire;    // 用于连接dual_ram_templete_inst的r_data_o
        assign          r_data_o = (r_w_flag) ? w_data_reg : r_data_wire;

        always@(posedge clk) begin
            w_data_reg <= w_data_i;
        end

        always@(posedge clk) begin
            if(rst && r_en_i && w_en_i && r_addr_i == w_addr_i)
                r_w_flag <= 1'b1;
            else
                r_w_flag <= 1'b0;
        end

        dual_ram_templete #(
            .DW         (DW),
            .AW         (AW),
            .MEM_NUM    (MEM_NUM)
        )dual_ram_templete_inst
        (
            .clk        (clk),
            .rst        (rst),
            .w_addr_i   (w_addr_i),
            .w_data_i   (w_data_i),
            .w_en_i     (w_en_i),
            .r_data_o   (r_data_wire),
            .r_addr_i   (r_addr_i),
            .r_en_i     (r_en_i)
        );

    endmodule


    // 例化
    module dual_ram_templete #(
        parameter DW = 32,          // 位宽
        parameter AW = 12,          // 地址线
        parameter MEM_NUM = 4096    // 深度
    )
    (
        input   wire            clk,
        input   wire            rst,

        // 写入
        input   wire[AW - 1:0]  w_addr_i,
        input   wire[DW - 1:0]  w_data_i,
        input   wire            w_en_i,
        
        // 读取
        output  reg[DW - 1:0]   r_data_o,
        input   wire[AW - 1:0]  r_addr_i,
        input   wire            r_en_i
    );
        reg[DW - 1:0] memory[0:MEM_NUM - 1];

        always@(posedge clk) begin
            if(rst && r_en_i)
                r_data_o <= memory[r_addr_i];
        end

        always@(posedge clk) begin
            if(rst && w_en_i)
                memory[w_addr_i] <= w_data_i;
        end

    endmodule