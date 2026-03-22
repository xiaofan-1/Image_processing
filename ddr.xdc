#IO引脚约束
create_clock -period 37.037 -name sys_clk [get_ports sys_clk]

#----------------------系统时钟---------------------------
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports sys_clk]
#----------------------系统复位---------------------------
set_property -dict {PACKAGE_PIN C22 IOSTANDARD LVCMOS33} [get_ports sys_rst_n]
#----------------------LED---------------------------
set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVCMOS33} [get_ports init_calib_complete]
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS33} [get_ports cam_led0]

#----------------------HDMI TMDS引脚约束---------------------------
set_property -dict {PACKAGE_PIN N21 IOSTANDARD TMDS_33} [get_ports tmds_clk_p]
set_property -dict {PACKAGE_PIN N22 IOSTANDARD TMDS_33} [get_ports tmds_clk_n]
set_property -dict {PACKAGE_PIN R25 IOSTANDARD TMDS_33} [get_ports {tmds_data_p[0]}]
set_property -dict {PACKAGE_PIN P25 IOSTANDARD TMDS_33} [get_ports {tmds_data_n[0]}]
set_property -dict {PACKAGE_PIN P23 IOSTANDARD TMDS_33} [get_ports {tmds_data_p[1]}]
set_property -dict {PACKAGE_PIN P24 IOSTANDARD TMDS_33} [get_ports {tmds_data_n[1]}]
set_property -dict {PACKAGE_PIN N23 IOSTANDARD TMDS_33} [get_ports {tmds_data_p[2]}]
set_property -dict {PACKAGE_PIN N24 IOSTANDARD TMDS_33} [get_ports {tmds_data_n[2]}]

#----------------------ov5640_0---------------------------
set_property -dict {PACKAGE_PIN Y22 IOSTANDARD LVCMOS33} [get_ports camera_clk_0]
set_property -dict {PACKAGE_PIN V18 IOSTANDARD LVCMOS33} [get_ports {camera_data_0[0]}]
set_property -dict {PACKAGE_PIN U20 IOSTANDARD LVCMOS33} [get_ports {camera_data_0[1]}]
set_property -dict {PACKAGE_PIN W26 IOSTANDARD LVCMOS33} [get_ports {camera_data_0[2]}]
set_property -dict {PACKAGE_PIN V26 IOSTANDARD LVCMOS33} [get_ports {camera_data_0[3]}]
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {camera_data_0[4]}]
set_property -dict {PACKAGE_PIN T18 IOSTANDARD LVCMOS33} [get_ports {camera_data_0[5]}]
set_property -dict {PACKAGE_PIN T19 IOSTANDARD LVCMOS33} [get_ports {camera_data_0[6]}]
set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33} [get_ports {camera_data_0[7]}]
set_property -dict {PACKAGE_PIN U19 IOSTANDARD LVCMOS33} [get_ports camera_href_0]
set_property -dict {PACKAGE_PIN Y23 IOSTANDARD LVCMOS33} [get_ports camera_vsync_0]
set_property -dict {PACKAGE_PIN T17 IOSTANDARD LVCMOS33} [get_ports SCL_0]
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports SDA_0]
set_property -dict {PACKAGE_PIN T20 IOSTANDARD LVCMOS33} [get_ports cam_rst_0]

set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property BITSTREAM.CONFIG.CONFIGRATE 33 [current_design]





create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list hdmi_clk_inst/inst/clk_out2]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 16 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {video_rect_read_data_inst0/read_data[0]} {video_rect_read_data_inst0/read_data[1]} {video_rect_read_data_inst0/read_data[2]} {video_rect_read_data_inst0/read_data[3]} {video_rect_read_data_inst0/read_data[4]} {video_rect_read_data_inst0/read_data[5]} {video_rect_read_data_inst0/read_data[6]} {video_rect_read_data_inst0/read_data[7]} {video_rect_read_data_inst0/read_data[8]} {video_rect_read_data_inst0/read_data[9]} {video_rect_read_data_inst0/read_data[10]} {video_rect_read_data_inst0/read_data[11]} {video_rect_read_data_inst0/read_data[12]} {video_rect_read_data_inst0/read_data[13]} {video_rect_read_data_inst0/read_data[14]} {video_rect_read_data_inst0/read_data[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 24 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {vout_data[0]} {vout_data[1]} {vout_data[2]} {vout_data[3]} {vout_data[4]} {vout_data[5]} {vout_data[6]} {vout_data[7]} {vout_data[8]} {vout_data[9]} {vout_data[10]} {vout_data[11]} {vout_data[12]} {vout_data[13]} {vout_data[14]} {vout_data[15]} {vout_data[16]} {vout_data[17]} {vout_data[18]} {vout_data[19]} {vout_data[20]} {vout_data[21]} {vout_data[22]} {vout_data[23]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 13 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {x_act[0]} {x_act[1]} {x_act[2]} {x_act[3]} {x_act[4]} {x_act[5]} {x_act[6]} {x_act[7]} {x_act[8]} {x_act[9]} {x_act[10]} {x_act[11]} {x_act[12]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 16 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {bar_data[0]} {bar_data[1]} {bar_data[2]} {bar_data[3]} {bar_data[4]} {bar_data[5]} {bar_data[6]} {bar_data[7]} {bar_data[8]} {bar_data[9]} {bar_data[10]} {bar_data[11]} {bar_data[12]} {bar_data[13]} {bar_data[14]} {bar_data[15]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 13 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {y_act[0]} {y_act[1]} {y_act[2]} {y_act[3]} {y_act[4]} {y_act[5]} {y_act[6]} {y_act[7]} {y_act[8]} {y_act[9]} {y_act[10]} {y_act[11]} {y_act[12]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list bar_de]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list bar_hs]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list bar_vs]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list de_out_0]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list hs_out_0]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list video_rect_read_data_inst0/read_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list vs_out_0]]
create_debug_core u_ila_1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property port_width 1 [get_debug_ports u_ila_1/clk]
connect_debug_port u_ila_1/clk [get_nets [list camera_clk_0_IBUF_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 16 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {cam_data_0[0]} {cam_data_0[1]} {cam_data_0[2]} {cam_data_0[3]} {cam_data_0[4]} {cam_data_0[5]} {cam_data_0[6]} {cam_data_0[7]} {cam_data_0[8]} {cam_data_0[9]} {cam_data_0[10]} {cam_data_0[11]} {cam_data_0[12]} {cam_data_0[13]} {cam_data_0[14]} {cam_data_0[15]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 1 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list cam_href_0]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 1 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list cam_vsync_0]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
set_property port_width 1 [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list cam_write_en_0]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets camera_clk_0_IBUF_BUFG]
