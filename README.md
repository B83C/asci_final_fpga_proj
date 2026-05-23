# Human Reflex Tester (FPGA)

A reaction-time testing game on FPGA. Press button 0 to start, wait for a random delay (200–300 ms), press button 0 again as fast as possible, and see your latency displayed on screen. Button 1 resets.

Builds for **Xilinx 7-series** (Vivado) and **librelane** (yosys + open-source ASIC flow).

## How It Works

The design is structured around a handshake-driven FSM:

| State | Meaning |
|---|---|
| `IDLE` | Waiting for button 0 to start |
| `INIT` | Wait for button release, then arm the countdown |
| `TRIGGERED` | Random delay countdown; button 0 pauses it, 3+ rapid presses trigger `SPAM` |
| `MEASURING` | Measuring elapsed time until button 0 press (or timeout at 5000 ms) |
| `MEASURED` | Display latency; hold until button 1 resets |
| `SPAM` | Cheat detected; hold until button 1 resets |

The FSM uses a **ready/hold handshake** (`state.sv`): a state asserts `ready` when its exit condition is met, and sets `hold=1` on transition. The next state fires when `ready=1 → 0 → 1` (button release), preventing retriggering from a held button.

Latency values feed into a **moving-average buffer** (depth 3) so the display shows both the latest reading and an average. Text is color-coded by latency range (darkblue < 100 ms, green < 150, yellow < 250, orange < 400, red ≥ 400).

A **binary-to-BCD converter** (`bin2bcd` via double-dabble) converts the measured latency into decimal digits for the on-screen display.

**Anti-cheat:** during the random delay, pressing button 0 pauses the countdown. If button 0 is pressed ≥ 3 times during `TRIGGERED`, the machine transitions to `SPAM` and locks up until button 1 resets.

## Project Structure

```
src/
  top.sv              — Top-level: clocking, reset, DVI TX (Xilinx-specific)
  top_vga.sv          — Game logic: FSM, random delay, latency measurement, display pipeline
  state.sv            — FSM with ready/hold handshake
  debouncer.sv        — Shift-register debouncer (parameters: DEPTH, INVERT)
  vga_timing.sv       — VGA sync/blank timing generation
  display_pipeline.sv — Character pipeline: text buffer, overlay mux, glyph ROM, rect drawing
  vga_if.sv           — VGA signal interface
  tmds_bus_if.sv      — TMDS bus interface
  tmds_encoder.sv     — TMDS encoding (Xilinx-specific)
  tmds_serdes.sv      — OSERDESE2 serializer (Xilinx-specific)
  top_dvi.sv          — DVI output stage (Xilinx-specific)
  generic_counter.sv  — Configurable up-counter
  generic_countdown_counter.sv — Configurable countdown with load
  lfsr.sv             — Linear-feedback shift register for random delay
  timing_counter.sv   — VGA-style counter with sync/blank/dead zones
  pipe.sv             — Generic pipeline register stage (generate-based)
  ram.sv              — Block RAM wrapper with $readmemh init
  defs.svh            — Shared definitions: state_t enum, display_params package
  ascii.rom           — 8×8 ASCII glyph ROM data

tests/
  tb_state.sv         — Standalone Verilator testbench for state.sv (20 tests)
  tb_debouncer.sv     — Standalone Verilator testbench for debouncer.sv

ys/
  top_vga.ys          — Yosys synthesis script (slang SV frontend)
  synth_netlist.tcl   — Vivado Tcl to synthesize top_vga and write netlist

librelane/
  config.json         — librelane configuration targeting top_vga

build.tcl             — Full Vivado build: synthesis → implementation → bitstream
justfile              — Build recipes
```

## Build & Run

### FPGA (Vivado)

```sh
# Full build: synth → impl → bitstream
just vivado

# Upload to board (Digilent FT4232)
just upload
```

### Synthesis-Only Flows

```sh
# Yosys (generic gates, for librelane / open-source P&R)
just yosys        # → build/top_vga_synth.v + build/top_vga_synth.json

# Vivado netlist (Xilinx primitives)
just vivado_netlist  # → build/top_vga_synth.vivado.v
```

### Simulation & Testing

```sh
# Verilator testbenches
just verilator tb=state       # → runs tb_state tests
just verilator tb=debouncer   # → runs tb_debouncer tests

# Rust / marlin tests (requires marlin SV compilation)
just test <test_name>
```

## Display Layout

```
┌─────────────────────────────────────────────────┐
│░░░░░░░░ Human Reflex Tester ░░░░░░░░░░░░░░░░░░░│  ← header bar
├───────────────────────┬─────────────────────────┤
│                       │  ┌─────────┐            │
│  System State         │  │  START  │            │
│  Current:  MEASURED   │  └─────────┘            │
│  Latency:  342 ms     │  ┌─────────┐            │
│  Average:  315 ms     │  │  RESET  │            │
│                       │  └─────────┘            │
│    >> press now <<    │                         │
└───────────────────────┴─────────────────────────┘
```

Text overlays (state name, latency digits, prompt) are rendered on top of the static text buffer via a **pipeline overlay mux** with 5 coordinate-delay stages + 1 output stage (`Latencies = 6`).

## Port Map

| Port | Direction | Description |
|---|---|---|
| `clk` | input | 75 MHz pixel clock |
| `rstn` | input | Active-low reset |
| `buttons[1:0]` | input | Button 0 = start/measure, button 1 = reset (active low) |
| `leds[1:0]` | output | Button state passthrough |
| `vga` (interface) | output | VGA signals: hsync, vsync, hblank, vblank, active, fsync, r[7:0], g[7:0], b[7:0] |

For synthesis as a standalone module, the `vga_if` interface port can be replaced with individual outputs (see `top_vga.sv` for the interface definition).

## License

MIT
