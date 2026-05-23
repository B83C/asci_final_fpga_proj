# Synthesize top_vga and write netlist for librelane
# Usage: vivado -mode batch -source ys/synth_netlist.tcl

open_project ../asic-vivado/hdmi_test/hdmi_test.xpr

remove_files [get_files -filter {IS_AVAILABLE == 0}]
add_files [glob -nocomplain ./src/*.sv]

set_property top top_vga [current_fileset]

# Ignore constraint files — they reference top ports, not top_vga ports
set_property IS_ENABLED false [get_files *.xdc]

reset_run synth_1
launch_runs synth_1
wait_on_run synth_1

open_run synth_1
write_verilog -force ./build/top_vga_synth.vivado.v
puts "Netlist written to ./build/top_vga_synth.vivado.v"
