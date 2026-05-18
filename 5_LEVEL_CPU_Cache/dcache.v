`include "rv32I.vh"
`include "switch.vh"

module dcache#(
    parameter INDEX_WIDTH   = 6,
    parameter TAG_WIDTH     = (30 - INDEX_WIDTH)
)(
    input               clk,
    input               rst,

    // CPU/MEM side
    input               cpu_req_load,
    input               cpu_req_store,
    input      [1:0]    cpu_mask,
    input      [31:0]   cpu_addr,
    input      [1:0]    cpu_addr_low,
    (* max_fanout = 20 *)
    input      [31:0]   cpu_wdata,
    input      [3:0]    cpu_we,
    input               cpu_is_signed,
    output     [31:0]   cpu_rdata,
    input               cpu_write_dram,
    output     [31:0]   cpu_rdata_mem,

    // external DROM side
    output reg [31:0]   mem_addr,
    output reg [3:0]    mem_we,
    output reg          mem_wen,
    output reg [31:0]   mem_wdata,
    input      [31:0]   mem_rdata,

    output reg          mem_ack
);
    `ifdef ENABLE_DCACHE
        localparam LINE_NUM = 2 ** INDEX_WIDTH;

        // 两路 FIFO
        (* ram_style = "block" *) reg [7:0] data_b0 [0:LINE_NUM * 2 - 1];
        (* ram_style = "block" *) reg [7:0] data_b1 [0:LINE_NUM * 2 - 1];
        (* ram_style = "block" *) reg [7:0] data_b2 [0:LINE_NUM * 2 - 1];
        (* ram_style = "block" *) reg [7:0] data_b3 [0:LINE_NUM * 2 - 1];
        reg [TAG_WIDTH:0] tagv [0:LINE_NUM * 2 - 1];   // [TAG_WIDTH]:Valid, [TAG_WIDTH-1:0]:Tag
        reg replace_way [0:LINE_NUM - 1];

        integer i;
        initial begin
            for (i = 0; i < LINE_NUM * 2; i = i + 1) tagv[i] = 0;
            for (i = 0; i < LINE_NUM; i = i + 1) replace_way[i] = 0;
        end
        wire [INDEX_WIDTH - 1:0] dcache_index = cpu_addr[INDEX_WIDTH + 1:2];
        wire [TAG_WIDTH - 1:0]   dcache_tag   = cpu_addr[31:INDEX_WIDTH + 2];

        wire [TAG_WIDTH:0] hit_tagv_way0 = tagv[{dcache_index, 1'b0}];
        wire [TAG_WIDTH:0] hit_tagv_way1 = tagv[{dcache_index, 1'b1}];
        wire [TAG_WIDTH - 1:0] hit_tag_way0 = hit_tagv_way0[TAG_WIDTH - 1:0];
        wire [TAG_WIDTH - 1:0] hit_tag_way1 = hit_tagv_way1[TAG_WIDTH - 1:0];
        wire hit_valid_way0 = hit_tagv_way0[TAG_WIDTH];
        wire hit_valid_way1 = hit_tagv_way1[TAG_WIDTH];

        wire hit_way0 = (hit_tag_way0 == dcache_tag && hit_valid_way0);
        wire hit_way1 = (hit_tag_way1 == dcache_tag && hit_valid_way1);
        wire dcache_hit = hit_way0 | hit_way1;
        wire hit_way = ~hit_way0;
        wire miss_replace_way = replace_way[dcache_index];
        reg [7:0] hit_data_b3, hit_data_b2, hit_data_b1, hit_data_b0;

        // 读
        always @(posedge clk) begin
            hit_data_b3 <= data_b3[{dcache_index, hit_way}];
            hit_data_b2 <= data_b2[{dcache_index, hit_way}];
            hit_data_b1 <= data_b1[{dcache_index, hit_way}];
            hit_data_b0 <= data_b0[{dcache_index, hit_way}];
            mem_ack <= dcache_hit;
        end
        
        wire [31:0] hit_data = {hit_data_b3, hit_data_b2, hit_data_b1, hit_data_b0};
        assign cpu_rdata_mem = load_shift(hit_data, mask_r, addr_low_r, is_signed_r);

        // 写 data
        always @(posedge clk) begin
            if (dcache_hit & cpu_req_store) begin
                if (cpu_we[3]) data_b3[{dcache_index, hit_way}] <= cpu_wdata[31:24];
                if (cpu_we[2]) data_b2[{dcache_index, hit_way}] <= cpu_wdata[23:16];
                if (cpu_we[1]) data_b1[{dcache_index, hit_way}] <= cpu_wdata[15:8];
                if (cpu_we[0]) data_b0[{dcache_index, hit_way}] <= cpu_wdata[7:0];
            end
            else if (miss_req && req_load_r2) begin
                data_b3[{miss_index, miss_way}] <= mem_rdata[31:24];
                data_b2[{miss_index, miss_way}] <= mem_rdata[23:16];
                data_b1[{miss_index, miss_way}] <= mem_rdata[15:8];
                data_b0[{miss_index, miss_way}] <= mem_rdata[7:0];
            end
        end

        // 写 tagv
        always @(posedge clk) begin
            if (!dcache_hit && cpu_req_load) begin
                tagv[{dcache_index, miss_replace_way}][TAG_WIDTH] <= 1'b0;      // 使旧数据无效
                replace_way[dcache_index] <= replace_way[dcache_index] + 1'b1;  // FIFO 替换指针更新
            end
            else if (miss_req && req_load_r2) begin
                tagv[{miss_index, miss_way}] <= {1'b1, miss_tag};
            end
        end

        reg miss_req;
        reg [INDEX_WIDTH-1:0] miss_index;
        reg [TAG_WIDTH - 1:0] miss_tag;
        reg miss_way;

        always @(posedge clk) begin
            if (!rst) begin
                miss_req    <= 0;
                miss_index  <= 0;
                miss_tag    <= 0;
                miss_way    <= 0;
            end
            else if (!dcache_hit && cpu_req_load && !miss_req) begin
                miss_req    <= 1'b1;
                miss_index  <= dcache_index;
                miss_tag    <= dcache_tag;
                miss_way    <= miss_replace_way;
            end
            else if (miss_req && req_load_r2) begin
                miss_req    <= 1'b0;
            end
        end
    `else
        always @(posedge clk) begin
            mem_ack <= 1'b0;
        end
    `endif

    reg req_load_r, req_load_r2;
    reg [1:0] mask_r, mask_r2;
    reg [1:0] addr_low_r, addr_low_r2;
    reg is_signed_r, is_signed_r2;
    always @(posedge clk) begin
        if (!rst) begin
            req_load_r      <= 1'b0;
            req_load_r2     <= 1'b0;
            mask_r          <= 2'b0;
            mask_r2         <= 2'b0;
            addr_low_r      <= 2'b0;
            addr_low_r2     <= 2'b0;
            is_signed_r     <= 1'b0;
            is_signed_r2    <= 1'b0;
        end
        else begin
            req_load_r      <= cpu_req_load;
            req_load_r2     <= req_load_r;
            mask_r          <= cpu_mask;
            mask_r2         <= mask_r;
            addr_low_r      <= cpu_addr_low;
            addr_low_r2     <= addr_low_r;
            is_signed_r     <= cpu_is_signed;
            is_signed_r2    <= is_signed_r;
        end
    end
    always @(*) begin
        mem_addr    = cpu_addr;
        mem_we      = (cpu_write_dram) ? cpu_we : 4'b0;
        mem_wen     = cpu_req_store;
        mem_wdata   = cpu_wdata;
    end

    assign cpu_rdata = load_shift(mem_rdata, mask_r2, addr_low_r2, is_signed_r2);

    // 函数：
    function [31:0] load_shift;
        input [31:0] word;
        input [1:0]  mask;
        input [1:0]  addr_low;
        input        is_signed;
        reg   [31:0] shifted_word;
        reg   [7:0]  byte_val;
        reg   [15:0] half_val;
        begin 
            shifted_word = word >> {addr_low, 3'b000};
            byte_val  = shifted_word[7:0];
            half_val  = shifted_word[15:0];
            case (mask)
                2'b01:  // byte
                    load_shift = {{24{byte_val[7] & is_signed}}, byte_val};
                2'b10:  // half
                    load_shift = {{16{half_val[15] & is_signed}}, half_val};
                2'b11:  // word
                    load_shift = shifted_word;
                default: load_shift = 32'b0;
            endcase
        end
    endfunction
endmodule