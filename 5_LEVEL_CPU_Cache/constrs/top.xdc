set_property BEL BUFG [get_cells pll_inst/inst/clkout2_buf]
set_property LOC BUFGCTRL_X0Y0 [get_cells pll_inst/inst/clkout2_buf]
set_property BEL PLLE2_ADV [get_cells pll_inst/inst/plle2_adv_inst]
set_property LOC PLLE2_ADV_X1Y1 [get_cells pll_inst/inst/plle2_adv_inst]

### 前推 / 冲刷 关键路径
set_max_delay -datapath_only \
    -from [get_pins -hierarchical -filter { NAME =~ "*forwarding_rs*_data_o*/Q*" || NAME =~ "*forwarding_rs*_hit_ex_o*/Q*" || NAME =~ "*forwarding_ex_rd_data_o*"}] \
    -to [get_pins -hierarchical -filter { NAME =~  "*forwarding_ex_rd_data_o*/D*" || NAME =~  "*pred_flush_r*/D*" }] \
    3.200

set_max_delay -datapath_only \
    -from [get_pins -hierarchical -filter { NAME =~ "*inst_o*/Q*"}] \
    -to [get_pins -hierarchical -filter { NAME =~ "*pred_taken*/D*"}] \
    3.200

set_max_delay -datapath_only \
    -from [get_pins -hierarchical -filter { NAME =~ "*inst_packaged_o*/Q*" || NAME =~ "*value2_o*/Q*"}] \
    -to [get_pins -hierarchical -filter { NAME =~  "*forwarding_ex_rd_data_o*/D*" || NAME =~  "*pred_flush_r*/D*" }] \
    3.200

### DRAM 读内容前推关键路径
set_max_delay -datapath_only \
    -from [get_pins -hierarchical -filter { NAME =~ "*dout*/Q*"}] \
    -to [get_pins -hierarchical -filter { NAME =~ "*forwarding_rs*_data_o*/D*"}] \
    3.200
