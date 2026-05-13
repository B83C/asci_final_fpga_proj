open_project ../asic-vivado/hdmi_test/hdmi_test.xpr

remove_files [get_files -filter {IS_AVAILABLE == 0}]

add_files [glob -nocomplain ./src/*.sv]

# Reset runs to ensure a clean build
reset_run synth_1
reset_run impl_1

# Launch Synthesis
launch_runs synth_1
wait_on_run synth_1

# Launch Implementation and Bitstream Generation
# launch_runs impl_1 -to_step write_bitstream
launch_runs impl_1
wait_on_run impl_1

open_run impl_1
write_bitstream -force ./build/bitstream.bit
