// Thin wrapper around top_vga that converts the vga_if interface
// to individual output ports for the flatten / librelane flow.
// This avoids slang errors about unconnected interface ports at the top level.
`include "defs.svh"

module top_vga_flat #(
    parameter unsigned CLK_HZ = 75000000
) (
    input clk,
    input rstn,
    input [1:0] buttons,
    output reg [1:0] leds,
    output vga_hsync,
    output vga_vsync,
    output vga_hblank,
    output vga_vblank,
    output vga_active,
    output vga_fsync,
    output logic [7:0] vga_r,
    output logic [7:0] vga_g,
    output logic [7:0] vga_b
);
  vga_if bus ();

  top_vga inner (
      .clk(clk),
      .rstn(rstn),
      .buttons(buttons),
      .leds(leds),
      .vga(bus)
  );

  assign vga_hsync = bus.hsync;
  assign vga_vsync = bus.vsync;
  assign vga_hblank = bus.hblank;
  assign vga_vblank = bus.vblank;
  assign vga_active = bus.active;
  assign vga_fsync = bus.fsync;
  assign {vga_r, vga_g, vga_b} = {bus.r, bus.g, bus.b};
endmodule
