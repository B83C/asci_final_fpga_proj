set export := true
OBJCACHE := "sccache"

# ─── Vivado Build (Nexys Video) ──────────────────────────────
vivado:
    vivado -mode batch -source build.tcl

vivado_bitstream:
    vivado -mode batch -source write_bitstream.tcl

# ─── Basys3 Build ────────────────────────────────────────────
vivado_basys3:
    vivado -mode batch -source build_basys3.tcl

upload_basys3 f="build/basys3.bit":
    openFPGALoader -c digilent_hs2 --freq 10M --bitstream {{f}}

# ─── Waveform Viewer ────────────────────────────────────────
surfer fst="./build/vcd.fst":
    surfer {{fst}}

test tb: 
  verilator  -I./src/ -I./tests --cc {{tb}}.sv --trace-fst --build -CFLAGS -O0 -CFLAGS -fuse-ld=mold --verilate-jobs 16 --threads 4 --hierarchical --timing --binary --Mdir {{tb}}_obj/ -Wno-ASCRANGE -Wno-SELRANGE -Wno-MULTIDRIVEN -Wno-IMPLICITSTATIC -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC
  # verilator --cc {{tb}}.sv --trace-fst --build -CFLAGS -O0 -CFLAGS -fuse-ld=mold --verilate-jobs 16 --threads 4 --hierarchical --timing --binary --Mdir {{tb}}_obj/
  cd ./{{tb}}_obj/ && ./V{{tb}}

verilator tb:
    verilator --binary --build -j \
      -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
      -I./src \
      -o tb_{{tb}} \
      ./tests/tb_{{tb}}.sv ./src/{{tb}}.sv
    ./obj_dir/tb_{{tb}} +trace

verilator_top_basys3:
    CCACHE=1 verilator --binary --build -j --trace-fst \
      -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-CASEOVERLAP -Wno-PINMISSING -Wno-MULTITOP -Wno-IMPLICIT \
      -I./src -I/home/b83c/hw/asic/asic/src \
      --top-module tb_top_basys3 \
      -o tb_top_basys3 \
      ./tests/tb_top_basys3.sv \
      ./src/top_basys3.sv ./src/seven_seg.sv ./src/buzzer.sv ./src/anim_ctrl.sv \
      /home/b83c/hw/asic/asic/src/state.sv \
      /home/b83c/hw/asic/asic/src/debouncer.sv \
      /home/b83c/hw/asic/asic/src/generic_counter.sv \
      /home/b83c/hw/asic/asic/src/generic_countdown_counter.sv \
      /home/b83c/hw/asic/asic/src/lfsr.sv
    ./obj_dir/tb_top_basys3 +trace

verilator_buzzer:
    verilator --binary --build -j \
      -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
      -I./src \
      -o tb_buzzer \
      ./tests/tb_buzzer.sv ./src/buzzer.sv
    ./obj_dir/tb_buzzer

# ─── Run with tracing ────────────────────────────────────────
verilator_trace tb:
    verilator --binary --build -j --trace-fst \
      -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND \
      -I./src \
      -o tb_{{tb}} \
      ./tests/tb_{{tb}}.sv ./src/{{tb}}.sv
    ./obj_dir/tb_{{tb}} +trace

verilator_trace_top_basys3:
    verilator --binary --build -j --trace-fst \
      -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-CASEOVERLAP -Wno-PINMISSING -Wno-MULTITOP -Wno-IMPLICIT \
      -I./src -I/home/b83c/hw/asic/asic/src \
      --top-module tb_top_basys3 \
      -o tb_top_basys3 \
      ./tests/tb_top_basys3.sv \
      ./src/top_basys3.sv ./src/seven_seg.sv ./src/buzzer.sv ./src/anim_ctrl.sv \
      /home/b83c/hw/asic/asic/src/state.sv \
      /home/b83c/hw/asic/asic/src/debouncer.sv \
      /home/b83c/hw/asic/asic/src/generic_counter.sv \
      /home/b83c/hw/asic/asic/src/generic_countdown_counter.sv \
      /home/b83c/hw/asic/asic/src/lfsr.sv
    ./obj_dir/tb_top_basys3 +trace

# ─── Run all verilator tests ────────────────────────────────
test_all:
    just verilator tb=seven_seg
    just verilator_buzzer
    just verilator_top_basys3


all:
    just vivado
    just upload
