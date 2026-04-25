`include "rv32I.vh"

module dcache(
    input               clk,
    input               rst,

    // CPU/MEM side
    input               cpu_req,
    input               cpu_wen,
    input      [1:0]    cpu_mask,
    input      [31:0]   cpu_addr,
    input      [31:0]   cpu_wdata,
    output     [31:0]   cpu_rdata,
    output              stall,

    // external DROM side
    output     [31:0]   mem_addr,
    output              mem_wen,
    output     [1:0]    mem_mask,
    output     [31:0]   mem_wdata,
    input      [31:0]   mem_rdata
);
    // 直接映射 cache：64 行，每行 1 个 32-bit word
    localparam INDEX_WIDTH = 6;
    localparam TAG_WIDTH   = 24;
    localparam LINE_NUM    = 64;

    wire [INDEX_WIDTH-1:0] index = cpu_addr[INDEX_WIDTH+1:2];   // addr[7:2]
    wire [TAG_WIDTH-1:0]   tag   = cpu_addr[31:INDEX_WIDTH+2];  // addr[31:8]

    (* ram_style = "distributed" *) reg [31:0]          data_array  [0:LINE_NUM-1];
    (* ram_style = "distributed" *) reg [TAG_WIDTH-1:0] tag_array   [0:LINE_NUM-1];
    reg                                                valid_array [0:LINE_NUM-1];

    wire load_req;
    wire store_req;
    wire tag_match;
    wire hit;
    wire load_hit;
    wire load_miss;
    wire store_hit;

    assign load_req  = cpu_req & ~cpu_wen;
    assign store_req = cpu_req &  cpu_wen;

    assign tag_match = ~|(tag_array[index] ^ tag);
    assign hit       = valid_array[index] & tag_match;

    assign load_hit  = load_req  & hit;
    assign load_miss = load_req  & ~hit;
    assign store_hit = store_req & hit;

    // load miss 时冻结流水线
    assign stall = rst & load_miss;

    // ============================================================
    // 外部 DROM 访问
    //
    // load：
    //   无论 LB/LH/LW，都读完整 word，用于 cache refill。
    //
    // store：
    //   写穿透，保持原始 addr/mask/wdata。
    //
    // 这里不能依赖 hit/miss，避免 tag compare 进入外部 RAM 路径。
    // ============================================================
    assign mem_addr  = load_req ? {cpu_addr[31:2], 2'b00} : cpu_addr;
    assign mem_mask  = load_req ? 2'b10                   : cpu_mask;
    assign mem_wen   = store_req;
    assign mem_wdata = cpu_wdata;

    // 把完整 word 根据 addr[1:0] 和 mask 移到低位
    function [31:0] load_shift;
        input [31:0] word;
        input [1:0]  addr_low;
        input [1:0]  mask;
        begin
            case(mask)
                // byte
                2'b00: begin
                    case(addr_low)
                        2'b00: load_shift = {24'b0, word[7:0]};
                        2'b01: load_shift = {24'b0, word[15:8]};
                        2'b10: load_shift = {24'b0, word[23:16]};
                        2'b11: load_shift = {24'b0, word[31:24]};
                        default: load_shift = 32'b0;
                    endcase
                end

                // half word
                2'b01: begin
                    if(addr_low[1])
                        load_shift = {16'b0, word[31:16]};
                    else
                        load_shift = {16'b0, word[15:0]};
                end

                // word
                2'b10: begin
                    load_shift = word;
                end

                default: begin
                    load_shift = word;
                end
            endcase
        end
    endfunction

    // store hit 时更新 cache 里的旧 word
    function [31:0] store_merge;
        input [31:0] old_word;
        input [31:0] wdata;
        input [1:0]  addr_low;
        input [1:0]  mask;
        begin
            store_merge = old_word;

            case(mask)
                // SB
                2'b00: begin
                    case(addr_low)
                        2'b00: store_merge[7:0]   = wdata[7:0];
                        2'b01: store_merge[15:8]  = wdata[7:0];
                        2'b10: store_merge[23:16] = wdata[7:0];
                        2'b11: store_merge[31:24] = wdata[7:0];
                        default: store_merge = old_word;
                    endcase
                end

                // SH
                2'b01: begin
                    if(addr_low[1])
                        store_merge[31:16] = wdata[15:0];
                    else
                        store_merge[15:0]  = wdata[15:0];
                end

                // SW
                2'b10: begin
                    store_merge = wdata;
                end

                default: begin
                    store_merge = old_word;
                end
            endcase
        end
    endfunction

    // ============================================================
    // 关键时序优化点
    //
    // 原来 miss 时：
    //   cpu_rdata = load_shift(mem_rdata, ...)
    //
    // 这样会形成：
    //   EX_MEM/mem_addr_o_reg
    //   -> 外部 Mem_DRAM
    //   -> DCache
    //   -> MEM
    //   -> MEM_WB
    //
    // 现在 miss 时不再旁路 mem_rdata。
    // miss 周期只 refill cache，同时 stall 流水线；
    // 下一拍同一条 load 重新访问，此时 hit，从 cache 输出。
    // ============================================================
    assign cpu_rdata = load_hit ? load_shift(data_array[index], cpu_addr[1:0], cpu_mask)
                                : 32'b0;

    integer i;

    always @(posedge clk) begin
        if(!rst) begin
            // 只清 valid，不清 tag/data，减少 reset 扇出
            for(i = 0; i < LINE_NUM; i = i + 1) begin
                valid_array[i] <= 1'b0;
            end
        end
        else begin
            // load miss：
            // 当前周期 stall=1，MEM/WB 不会写入这个 miss 数据。
            // 时钟沿把外部完整 word 填入 cache。
            // 下一周期 hit，再从 cache 输出给 MEM/WB。
            if(load_miss) begin
                valid_array[index] <= 1'b1;
                tag_array[index]   <= tag;
                data_array[index]  <= mem_rdata;
            end

            // store hit：
            // 外部写穿透，同时更新 cache 副本。
            // store miss：不分配 cache line。
            if(store_hit) begin
                data_array[index] <= store_merge(
                    data_array[index],
                    cpu_wdata,
                    cpu_addr[1:0],
                    cpu_mask
                );
            end
        end
    end

endmodule