set_property -dict {PACKAGE_PIN M19 IOSTANDARD LVCMOS33} [get_ports clk50]
create_clock -period 20 -name clk50 -waveform {0.000 10.000} -add [get_ports clk50]

set_property -dict {PACKAGE_PIN N22 IOSTANDARD TMDS_33} [get_ports tmds_tx_clk_p]
set_property -dict {PACKAGE_PIN P22 IOSTANDARD TMDS_33} [get_ports tmds_tx_clk_n]

set_property -dict {PACKAGE_PIN M21 IOSTANDARD TMDS_33} [get_ports tmds_tx_data_p[0]]
set_property -dict {PACKAGE_PIN M22 IOSTANDARD TMDS_33} [get_ports tmds_tx_data_n[0]]

set_property -dict {PACKAGE_PIN L21 IOSTANDARD TMDS_33} [get_ports tmds_tx_data_p[1]]
set_property -dict {PACKAGE_PIN L22 IOSTANDARD TMDS_33} [get_ports tmds_tx_data_n[1]]

set_property -dict {PACKAGE_PIN J21 IOSTANDARD TMDS_33} [get_ports tmds_tx_data_p[2]]
set_property -dict {PACKAGE_PIN J22 IOSTANDARD TMDS_33} [get_ports tmds_tx_data_n[2]]

set_property -dict {PACKAGE_PIN V14 IOSTANDARD LVCMOS33 PULLTYPE PULLUP} [get_ports buttons[0]]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33 PULLTYPE PULLUP} [get_ports buttons[1]]

set_property -dict {PACKAGE_PIN P20 IOSTANDARD LVCMOS33} [get_ports leds[0]]
set_property -dict {PACKAGE_PIN P21 IOSTANDARD LVCMOS33} [get_ports leds[1]]
