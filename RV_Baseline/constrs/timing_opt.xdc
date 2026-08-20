# 保持 IP 核结构
# set_property KEEP_HIERARCHY SOFT [get_cells -hierarchical *pll_inst*]
# set_property KEEP_HIERARCHY SOFT [get_cells -hierarchical *Mem_IROM*]
# set_property KEEP_HIERARCHY SOFT [get_cells -hierarchical *Mem_DRAM*]

# 扇出限制
#set_property MAX_FANOUT 30 [get_nets -hierarchical *pc_o*]

