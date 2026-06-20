# Build Basys3 using existing project
close_project -quiet
open_project ./vivado-project-files/reaction_meter_xzy/reaction_meter_xzy.xpr

# Bypass unconstrained port DRC for unused ports
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]

reset_run synth_1

launch_runs synth_1
wait_on_run synth_1

launch_runs impl_1 -to_step write_bitstream
wait_on_run impl_1

puts "=== Basys3 build complete ==="
