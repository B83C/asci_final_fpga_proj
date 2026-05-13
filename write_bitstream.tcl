open_project ../asic-vivado/hdmi_test/hdmi_test.xpr

open_run impl_1
write_bitstream -force ./build/bitstream.bit
