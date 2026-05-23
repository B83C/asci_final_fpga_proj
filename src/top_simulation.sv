`timescale 1ns / 1ps
`include "defs.svh"

module top_simulation (
    input clk,
    input rstn,

    input [1:0] buttons,

    output reg [1:0] leds,

    output hsync,
    output hblank,
    output vsync,
    output vblank,
    output active,
    output fsync,

    output logic [7:0] r,
    output logic [7:0] g,
    output logic [7:0] b
);
  vga_if vga_bus ();

  top_vga #(
  // .CLK_HZ(30)
  ) vga_ (
      .*,
      .vga(vga_bus.producer)
  );

  assign hsync = vga_bus.hsync;
  assign hblank = vga_bus.hblank;
  assign vsync = vga_bus.vsync;
  assign vblank = vga_bus.vblank;
  assign active = vga_bus.active;
  assign fsync = vga_bus.fsync;

  assign r = vga_bus.r;
  assign g = vga_bus.g;
  assign b = vga_bus.b;


endmodule
