`include "alu_def.svh"
`include "switch.vh"
module alu_Bext(
    input  logic        clk,
    input  logic        rst,
    input  logic        flush,

    input  logic [31:0] value1,
    input  logic [31:0] value2,
    input  decode_t     ipkg,

    output logic        ctrl,
    output logic [31:0] result
);
    // Zba
    logic [31:0] zba_res;
    `ifdef ENABLE_B_ZBA
    wire [31:0] sh1add_res = (value1 << 1) + value2;
    wire [31:0] sh2add_res = (value1 << 2) + value2;
    wire [31:0] sh3add_res = (value1 << 3) + value2;
    
    always_comb begin
        unique case (1'b1)
            ipkg.sel_sh1add : zba_res = sh1add_res;
            ipkg.sel_sh2add : zba_res = sh2add_res;
            ipkg.sel_sh3add : zba_res = sh3add_res;
            default : zba_res = 32'b0;
        endcase
    end
    `endif
    
    // Zbb
    logic [31:0] zbb_res;
    `ifdef ENABLE_B_ZBB
    wire        value1_is_zero = ~(|value1);
    wire  [4:0] shamt_zbb      = value2[4:0];
    logic [7:0] value1_byte [0:3];
    always_comb begin
        for (int i = 0; i < 4; i++) value1_byte[i] = value1[8*i +: 8];
    end
    
    wire [31:0] andn_res = value1 & ~value2;
    wire [31:0] orn_res  = value1 | ~value2;
    wire [31:0] xnor_res = ~(value1 ^ value2);
    
    wire [31:0] clz_res = {26'b0, value1_is_zero, clz_result};
    function automatic logic [3:0] clz8(input logic [7:0] data);
        for (int i = 7; i >= 0; i--) begin
            if (data[i]) return {1'b1, 3'(7 - i)};
        end
        return {1'b0, 3'b0};
    endfunction
    logic [4:0] clz_result;
    always_comb begin
        clz_result = 5'b0;
        for (int i = 3; i >= 0; i--) begin
            logic [3:0] clz_byte = clz8(value1_byte[i]);
            if (clz_byte[3]) begin
                clz_result = (8 * 5'(3 - i)) + clz_byte[2:0];
                break;
            end
        end
    end

    wire [31:0] ctz_res = {26'b0, value1_is_zero, ctz_result};
    function automatic logic [3:0] ctz8(input logic [7:0] data);
        for (int i = 0; i < 8; i++) begin
            if (data[i]) return {1'b1, 3'(i)};
        end
        return {1'b0, 3'b0};
    endfunction
    logic [4:0] ctz_result;
    always_comb begin
        ctz_result = 5'b0;
        for (int i = 0; i < 4; i++) begin
            logic [3:0] ctz_byte = ctz8(value1_byte[i]);

            if (ctz_byte[3]) begin
                ctz_result = 5'(8 * i) + ctz_byte[2:0];
                break;
            end
        end
    end

    wire [31:0] cpop_res = cpop32(value1);
    function automatic logic [5:0] cpop32(input logic [31:0] data); // 加法数
        logic [1:0] stage0 [15:0];
        logic [2:0] stage1 [7:0];
        logic [3:0] stage2 [3:0];
        logic [4:0] stage3 [1:0];
        
        // 树形 ADD
        for (int i = 0; i < 16; i++) stage0[i] = data[2*i+1] + data[2*i];
        for (int i = 0; i < 8; i++)  stage1[i] = stage0[2*i] + stage0[2*i+1];
        for (int i = 0; i < 4; i++)  stage2[i] = stage1[2*i] + stage1[2*i+1];
        for (int i = 0; i < 2; i++)  stage3[i] = stage2[2*i] + stage2[2*i+1];

        return stage3[0] + stage3[1];
    endfunction

    cmp_result_t cmp; 
    assign cmp = fast_compare(value1, value2);
    wire [31:0] max_res  = (cmp.lts) ? value2 : value1;
    wire [31:0] maxu_res = (cmp.ltu) ? value2 : value1;
    wire [31:0] min_res  = (cmp.lts) ? value1 : value2;
    wire [31:0] minu_res = (cmp.ltu) ? value1 : value2;
    
    wire [31:0] sext_b_res = {{24{value1[7]}}, value1[7:0]};
    wire [31:0] sext_h_res = {{16{value1[15]}}, value1[15:0]};
    wire [31:0] zext_h_res = {16'b0, value1[15:0]};

    wire [31:0] rol_res = (value1 << shamt_zbb) | (value1 >> (32 - shamt_zbb));
    wire [31:0] ror_res = (value1 >> shamt_zbb) | (value1 << (32 - shamt_zbb)); // same to rori

    wire [31:0] orc_b_res = {{8{|value1_byte[3]}}, {8{|value1_byte[2]}}, {8{|value1_byte[1]}}, {8{|value1_byte[0]}}};

    wire [31:0] rev8_res = {value1_byte[0], value1_byte[1], value1_byte[2], value1_byte[3]};

    always_comb begin
        unique case (1'b1)
            ipkg.sel_andn   : zbb_res = andn_res;
            ipkg.sel_orn    : zbb_res = orn_res;
            ipkg.sel_xnor   : zbb_res = xnor_res;
            ipkg.sel_clz    : zbb_res = clz_res;
            ipkg.sel_ctz    : zbb_res = ctz_res;
            ipkg.sel_cpop   : zbb_res = cpop_res;
            ipkg.sel_max    : zbb_res = max_res;
            ipkg.sel_maxu   : zbb_res = maxu_res;
            ipkg.sel_min    : zbb_res = min_res;
            ipkg.sel_minu   : zbb_res = minu_res;
            ipkg.sel_sext_b : zbb_res = sext_b_res;
            ipkg.sel_sext_h : zbb_res = sext_h_res;
            ipkg.sel_zext_h : zbb_res = zext_h_res;
            ipkg.sel_rol    : zbb_res = rol_res;
            ipkg.sel_ror    : zbb_res = ror_res;
            ipkg.sel_orc_b  : zbb_res = orc_b_res;
            ipkg.sel_rev8   : zbb_res = rev8_res;
            default : zbb_res = 32'b0;
        endcase
    end
    `endif

    // Zbc
    logic [31:0] zbc_res;
    `ifdef ENABLE_B_ZBC
    wire [31:0] clmul_res  = clmul_tree(value1, value2)[31:0];
    wire [31:0] clmulh_res = clmul_tree(value1, value2)[63:32];
    wire [31:0] clmulr_res = rev_bits(clmul_tree(rev_bits(value1), rev_bits(value2)));
    function automatic logic [31:0] rev_bits(input logic [31:0] data);
        for (int i = 0; i < 32; i++) begin
            rev_bits[i] = data[31 - i];
        end
    endfunction
    function automatic logic [63:0] clmul_tree(input logic [31:0] a, b);
        logic [63:0] pp [0:31];  // 32个部分积
        logic [63:0] stage0 [0:15];
        logic [63:0] stage1 [0:7];
        logic [63:0] stage2 [0:3];
        logic [63:0] stage3 [0:1];
        
        // 生成部分积
        for (int i = 0; i < 32; i++) pp[i] = a[i] ? ({32'b0, b} << i) : 64'b0;
        
        // 树形 XOR
        for (int i = 0; i < 16; i++) stage0[i] = pp[2*i] ^ pp[2*i+1];
        for (int i = 0; i < 8; i++)  stage1[i] = stage0[2*i] ^ stage0[2*i+1];
        for (int i = 0; i < 4; i++)  stage2[i] = stage1[2*i] ^ stage1[2*i+1];
        for (int i = 0; i < 2; i++)  stage3[i] = stage2[2*i] ^ stage2[2*i+1];
        
        return stage3[0] ^ stage3[1];
    endfunction

    always_comb begin
        unique case (1'b1)
            ipkg.sel_clmul  : zbc_res = clmul_res;
            ipkg.sel_clmulh : zbc_res = clmulh_res;
            ipkg.sel_clmulr : zbc_res = clmulr_res;
            default : zbc_res = 32'b0;
        endcase
    end
    `endif
    
    // Zbs
    logic [31:0] zbs_res;
    `ifdef ENABLE_B_ZBS
    wire [4:0]  shamt_zbs = value2[4:0];
    wire [31:0] bclr_res = value1 & ~(1 << shamt_zbs);  // same to bclri
    wire [31:0] bext_res = (value1 >> shamt_zbs) & 1;   // same to bexti
    wire [31:0] binv_res = value1 ^ (1 << shamt_zbs);   // same to binvi
    wire [31:0] bset_res = value1 | (1 << shamt_zbs);   // same to bseti

    always_comb begin
        unique case (1'b1)
            ipkg.sel_bclr : zbs_res = bclr_res;
            ipkg.sel_bext : zbs_res = bext_res;
            ipkg.sel_binv : zbs_res = binv_res;
            ipkg.sel_bset : zbs_res = bset_res;
            default : zbs_res = 32'b0;
        endcase
    end
    `endif

    // Zbkb
    logic [31:0] zbkb_res;
    `ifdef ENABLE_B_ZBKB
    wire [31:0] pack_res  = {value2[15:0], value1[15:0]};
    wire [31:0] packh_res = {16'b0, value2[7:0], value1[7:0]};

    wire [31:0] brev8_res = brev8(value1);
    function automatic logic [31:0] brev8(input logic [31:0] data);
        for (int b = 0; b < 4; b++) begin
            for (int i = 0; i < 8; i++) begin
                brev8[8 * b + i] = data[8 * b + (7 - i)];
            end
        end
    endfunction

    wire [31:0] zip_res = zip(value1);
    function automatic logic [31:0] zip(input logic [31:0] data);
        for (int i = 0; i < 16; i++) begin
            zip[2 * i]     = data[i];
            zip[2 * i + 1] = data[i + 16];
        end
    endfunction

    wire [31:0] unzip_res = unzip(value1);
    function automatic logic [31:0] unzip(input logic [31:0] data);
        for (int i = 0; i < 16; i++) begin
            unzip[i]      = data[2 * i];
            unzip[i + 16] = data[2 * i + 1];
        end
    endfunction
    
    always_comb begin
        unique case (1'b1)
            ipkg.sel_pack  : zbkb_res = pack_res;
            ipkg.sel_packh : zbkb_res = packh_res;
            ipkg.sel_brev8 : zbkb_res = brev8_res;
            ipkg.sel_zip   : zbkb_res = zip_res;
            ipkg.sel_unzip : zbkb_res = unzip_res;
            default : zbkb_res = 32'b0;
        endcase
    end
    `endif

    // Zbkx
    logic [31:0] zbkx_res;
    `ifdef ENABLE_B_ZBKX
    wire [31:0] xperm4_res = xperm4(value1, value2);
    function automatic logic [31:0] xperm4(input logic [31:0] a, b);
        for (int i = 0; i < 8; i++) begin
            logic [3:0] idx = b[i*4 +: 4];
            logic [3:0] lut = a[idx*4 +: 4];
            logic [3:0] val = (idx[3]) ? 4'b0 : lut;
            xperm4[i*4 +: 4] = val;
        end
    endfunction

    wire [31:0] xperm8_res = xperm8(value1, value2);
    function automatic logic [31:0] xperm8(input logic [31:0] a, b);
        for (int i = 0; i < 4; i++) begin
            logic [7:0] idx = b[i*8 +: 8];
            logic [7:0] lut = a[idx*8 +: 8];
            logic [7:0] val = (|idx[7:2]) ? 8'b0 : lut;
            xperm8[i*8 +: 8] = val;
        end
    endfunction

    always_comb begin
        unique case (1'b1)
            ipkg.sel_xperm4 : zbkx_res = xperm4_res;
            ipkg.sel_xperm8 : zbkx_res = xperm8_res;
            default : zbkx_res = 32'b0;
        endcase
    end
    `endif

    // 暂停控制
    assign ctrl = 1'b0;

    // 选择输出
    always_comb begin
        unique case (1'b1)
            ipkg.is_Bext_zba  : result = zba_res;
            ipkg.is_Bext_zbb  : result = zbb_res;
            ipkg.is_Bext_zbc  : result = zbc_res;
            ipkg.is_Bext_zbs  : result = zbs_res;
            ipkg.is_Bext_zbkb : result = zbkb_res;
            ipkg.is_Bext_zbkx : result = zbkx_res;
            default : result = 32'b0;
        endcase
    end
endmodule