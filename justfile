vivado:
    vivado -mode batch -source build.tcl

vivado_bitstream:
    vivado -mode batch -source write_bitstream.tcl

upload:
    openFPGALoader -c ft4232 --freq 30M --bitstream ./build/bitstream.bit

# surfer fst="./build/vcd.fst":
#     surfer  -s build/state.bincode  server --file {{fst}} --bind-address 0.0.0.0 --port 8888
    
surfer fst="./build/vcd.fst":
    surfer {{fst}}

test tests:
    MARLIN_TEST_BUILD_DIR=./build cargo test {{tests}} -- --show-output

# Build & run the state machine testbench with Verilator
verilator tb: 
    verilator --binary --build -j \
      -Wno-WIDTHTRUNC \
      -I./src \
      -o tb_{{tb}} \
      ./tests/tb_{{tb}}.sv ./src/{{tb}}.sv
    ./obj_dir/tb_{{tb}}

# verilator_run: verilator_build

# verilator_clean:
#     rm -rf obj_dir tests/tb_state.fst
    
run:
    cargo run 

run_verbose:
    cargo run -- --dump-vcd --num-frames 10

spade:
    swim build 

all:
    just vivado 
    just upload 
