# 设置 EX 的 pblock
delete_pblocks [get_pblocks pblock_EX_stage]
create_pblock pblock_EX_stage
    
add_cells_to_pblock [get_pblocks pblock_EX_stage] \
    [get_cells -hier -filter {NAME =~ "*EX*" || NAME =~ "*FWD*" || NAME =~ "*ID_EX*" || NAME =~ "*BPU*" || NAME =~ "*PC*"}]
    
resize_pblock [get_pblocks pblock_EX_stage] \
    -add {SLICE_X70Y180:SLICE_X117Y229}

## 关键设置：此区域允许其他无关逻辑混入，但会尽量引导布线器就近布线
set_property CONTAIN_ROUTING true       [get_pblocks pblock_EX_stage]
set_property EXCLUDE_PLACEMENT false    [get_pblocks pblock_EX_stage]
set_property SNAPPING_MODE ON           [get_pblocks pblock_EX_stage]