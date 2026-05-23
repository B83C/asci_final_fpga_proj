`timescale 1ns / 1ps
`include "defs.svh"

module top (
    input clk50,
    input rstn_,

    input [1:0] buttons,

    output reg [1:0] leds,

    output logic tmds_tx_clk_n,
    output logic tmds_tx_clk_p,

    output logic [2:0] tmds_tx_data_p,
    output logic [2:0] tmds_tx_data_n
);

  wire rstn;
  reg [7:0] rstncnt;
  wire pixclk, serdes_clk;
  wire locked;
  always @(posedge pixclk or negedge locked) begin
    if (~locked) begin
      rstncnt <= 0;
    end else begin
      if (rstncnt != 8'hff) begin
        rstncnt <= rstncnt + 1;
      end
    end
  end

  assign rstn = (rstncnt == 8'hff) ? 1'b1 : 1'b0;

  clk_wiz_0 cl_inst (
      // Clock out ports
      .clk_375(serdes_clk),
      .clk_75 (pixclk),
      // Status and control signals
      .reset  (0),
      .locked (locked),
      // Clock in ports
      .clk_in1(clk50)
  );

  vga_if vga_bus ();
  tmds_bus_if tmds_bus ();

  top_dvi dvi (
      .pixclk(pixclk),
      .serdes_clk(serdes_clk),
      .rstn(rstn),
      .vga(vga_bus.consumer),
      .tmds_output(tmds_bus)
  );

  top_vga vga_ (
      .*,
      .clk(pixclk),
      .vga(vga_bus.producer)
  );

  assign tmds_tx_clk_n  = tmds_bus.tmds_tx_clk_n;
  assign tmds_tx_clk_p  = tmds_bus.tmds_tx_clk_p;

  assign tmds_tx_data_p = tmds_bus.tmds_tx_data_p;
  assign tmds_tx_data_n = tmds_bus.tmds_tx_data_n;

endmodule

