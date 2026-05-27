# 设置 EX 的 pblock
# create_pblock pblock_EX_stage

# add_cells_to_pblock [get_pblocks pblock_EX_stage] \
#     [get_cells -hier -filter {NAME =~ "*EX*" || NAME =~ "*IF2_ID*" || NAME =~ "*ID_EX*" || NAME =~ "*EX_MEM*" || NAME =~ "*PC*" || NAME =~ "*EX_MEM*" || NAME =~ "*DCACHE*"}]

# resize_pblock [get_pblocks pblock_EX_stage] \
#     -add {SLICE_X2Y150:SLICE_X79Y199}

# ### 关键设置：此区域允许其他无关逻辑混入，但会尽量引导布线器就近布线
# set_property CONTAIN_ROUTING true       [get_pblocks pblock_EX_stage]
# set_property EXCLUDE_PLACEMENT false    [get_pblocks pblock_EX_stage]
# set_property SNAPPING_MODE ON           [get_pblocks pblock_EX_stage]

set_property KEEP_HIERARCHY SOFT [get_cells -hierarchical *pll_inst*]
set_property KEEP_HIERARCHY SOFT [get_cells -hierarchical *Mem_IROM*]
set_property KEEP_HIERARCHY SOFT [get_cells -hierarchical *Mem_DRAM*]

# 限制扇出
set_property MAX_FANOUT 30 [get_nets -hierarchical *pipe_hold*]
set_property MAX_FANOUT 30 [get_nets -hierarchical *pred_flush*]
set_property MAX_FANOUT 30 [get_nets -hierarchical *hazard_en*]
set_property MAX_FANOUT 30 [get_nets -hierarchical *hit_tagv*]

# 用 320MHz 去约束 clk2_constrs_320MHz
# create_clock -period 3.125 -name clk2_constrs_320MHz -waveform {0 1.5625} [get_nets *cpu_clk*]
# set_clock_groups -asynchronous \
#     -group [get_clocks clk2_constrs_320MHz] \
#     -group [get_clocks clk_out1_pll] \
#     -group [get_clocks clk_out2_pll]