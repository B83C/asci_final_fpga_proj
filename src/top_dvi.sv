`timescale 1ns / 1ps
`include "defs.svh"

module top_dvi (
    input pixclk,
    input serdes_clk,
    input rstn,
    vga_if vga,
    tmds_bus_if tmds_output
);
  wire [1:0] ctl[3];
  wire [7:0] pdata[3];
  wire [9:0] tmds_data[3];

  wire active = vga.active;

  assign pdata[2] = vga.r;
  assign pdata[1] = vga.g;
  assign pdata[0] = vga.b;

  assign ctl[0]   = {vga.vsync, vga.hsync};
  assign ctl[1]   = 2'b00;
  assign ctl[2]   = 2'b00;

  generate
    genvar i;

    for (i = 0; i < 3; i = i + 1) begin : gen_tmds
      wire [9:0] tmds_p;
      tmds_encoder encoder (
          .clk(pixclk),
          .video_data(pdata[i]),
          .control_data(ctl[i]),
          .video_data_enable(active),
          .TMDS(tmds_p)
      );

      tmds_serdes serdes (
          .pixclk(pixclk),
          .serdes_clk(serdes_clk),
          .rstn(rstn),
          .tmds_p(tmds_p),
          .tmds_tx_serial_n(tmds_output.tmds_tx_data_n[i]),
          .tmds_tx_serial_p(tmds_output.tmds_tx_data_p[i])
      );

    end
  endgenerate

  tmds_serdes serdes (
      .pixclk(pixclk),
      .serdes_clk(serdes_clk),
      .rstn(rstn),
      .tmds_p(10'b1111100000),
      .tmds_tx_serial_n(tmds_output.tmds_tx_clk_n),
      .tmds_tx_serial_p(tmds_output.tmds_tx_clk_p)
  );
endmodule
