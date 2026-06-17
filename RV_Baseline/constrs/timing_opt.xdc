# 设置 pblock
# create_pblock pblock_EX_stage

# add_cells_to_pblock [get_pblocks pblock_EX_stage] \
#     [get_cells -hier -filter {NAME =~ "*EX*" || NAME =~ "*IF2_ID*" || NAME =~ "*ID_EX*" || NAME =~ "*EX_MEM*" || NAME =~ "*PC*" || NAME =~ "*EX_MEM*" || NAME =~ "*DCACHE*"}]

# resize_pblock [get_pblocks pblock_EX_stage] \
#     -add {SLICE_X2Y150:SLICE_X79Y199}

# ### pblock 模式
# set_property CONTAIN_ROUTING true       [get_pblocks pblock_EX_stage]
# set_property EXCLUDE_PLACEMENT false    [get_pblocks pblock_EX_stage]
# set_property SNAPPING_MODE ON           [get_pblocks pblock_EX_stage]

# 跨时域
# set_false_path -from [get_clocks clk_out1_pll] -to [get_clocks clk_out2_pll]
# set_false_path -from [get_clocks clk_out2_pll] -to [get_clocks clk_out1_pll]

# 保持 IP 核结构
set_property KEEP_HIERARCHY SOFT [get_cells -hierarchical *pll_inst*]
# set_property KEEP_HIERARCHY SOFT [get_cells -hierarchical *Mem_IROM*]
set_property KEEP_HIERARCHY SOFT [get_cells -hierarchical *Mem_DRAM*]

# 扇出限制
set_property MAX_FANOUT 30 [get_nets -hierarchical *pipe_hold*]
set_property MAX_FANOUT 30 [get_nets -hierarchical *pred_flush*]
set_property MAX_FANOUT 30 [get_nets -hierarchical *hazard_en*]
set_property MAX_FANOUT 30 [get_nets -hierarchical *pc_o*]