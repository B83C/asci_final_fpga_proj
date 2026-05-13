vivado:
    vivado -mode batch -source build.tcl

vivado_bitstream:
    vivado -mode batch -source write_bitstream.tcl

upload:
    openFPGALoader -c ft4232 --freq 30M --bitstream ./build/bitstream.bit

surfer:
    surfer  -s build/state.bincode  server --file ./build/vcd.fst --bind-address 0.0.0.0 --port 8888
    
# surfer:
#     surfer ./build/vcd.fst -s build/state.bincode

test:
    MARLIN_TEST_BUILD_DIR=./build cargo test -- --show-output
    
run:
    cargo run 

run_verbose:
    cargo run -- --dump-vcd --num-frames 10
