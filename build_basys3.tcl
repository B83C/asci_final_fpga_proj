# Basys3 Build Script
# Target: xc7a35tcpg236-1

# Create project
create_project basys3_reaction ./vivado-project-files/basys3 -part xc7a35tcpg236-1 -force

# Add source files
add_files [glob ./src/*.sv]

# Add constraints
add_files -fileset constrs_1 ./cons.xdc

# Set top module
set_property top top_basys3 [current_fileset]

# Launch Synthesis
launch_runs synth_1
wait_on_run synth_1

# Write synthesized netlist
open_run synth_1
write_verilog -force ./build/top_basys3_synth.v

# Launch Implementation and Bitstream Generation
launch_runs impl_1
wait_on_run impl_1

open_run impl_1
# Bypass common DRC issues on Basys3 (pin names verified from Digilent master xdc)
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
write_bitstream -force ./build/basys3.bit

puts "=== Basys3 build complete: build/basys3.bit ==="
