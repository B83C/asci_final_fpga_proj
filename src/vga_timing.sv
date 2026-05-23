`timescale 1ns / 1ps
`include "defs.svh"

module vga_timing #(
    parameter unsigned H = 1280,
    parameter unsigned V = 720,
    parameter N_H = $clog2(H),
    parameter N_V = $clog2(V)
) (
    input clk,
    input rstn,

    output hsync,
    output vsync,
    output hactive,
    output vactive,
    output xc_end,
    output yc_end,
    output [N_H-1:0] x,
    output [N_V-1:0] y
);

  timing_counter #(
      .DISP(1280),
      .FP(110),
      .SW(40),
      .BP(220),
      .N(N_H)
  ) xc (
      .pixclk(clk),
      .rstn(rstn),
      .en(1),

      .sync(hsync),
      .x(x),
      .active(hactive),
      .ending(xc_end)
  );

  timing_counter #(
      .DISP(720),
      .FP(5),
      .SW(5),
      .BP(20),
      .N(N_V)
  ) yc (
      .pixclk(clk),
      .rstn(rstn),
      .en(xc_end),

      .sync(vsync),
      .x(y),
      .active(vactive),
      .ending(yc_end)
  );
endmodule

