`timescale 1ns / 1ps

module tmds_serdes (
    input pixclk,
    input serdes_clk,
    input rstn,
    input [9:0] tmds_p,
    output tmds_tx_serial_p,
    output tmds_tx_serial_n
);
  wire shiftout[2];
  wire tmds_tx_serial;

  OSERDESE2 #(
      .DATA_RATE_OQ  ("DDR"),     // DDR, SDR
      .DATA_RATE_TQ  ("SDR"),     // DDR, BUF, SDR
      .DATA_WIDTH    (10),        // Parallel data width (2-8,10,14)
      .INIT_OQ       (1'b0),      // Initial value of OQ output (1'b0,1'b1)
      .INIT_TQ       (1'b0),      // Initial value of TQ output (1'b0,1'b1)
      .SERDES_MODE   ("MASTER"),  // MASTER, SLAVE
      .SRVAL_OQ      (1'b0),      // OQ output value when RST is used (1'b0,1'b1)
      .SRVAL_TQ      (1'b0),      // TQ output value when RST is used (1'b0,1'b1)
      .TBYTE_CTL     ("FALSE"),   // Enable tristate byte operation (FALSE, TRUE)
      .TBYTE_SRC     ("FALSE"),   // Tristate byte source (FALSE, TRUE)
      .TRISTATE_WIDTH(1)          // 3-state converter width (1,4)
  ) OSERDESE2_inst (
      .OFB      (),                // 1-bit output: Feedback path for data
      .OQ       (tmds_tx_serial),  // 1-bit output: Data path output
      // SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
      .SHIFTOUT1(),
      .SHIFTOUT2(),
      .TBYTEOUT (),                // 1-bit output: Byte group tristate
      .TFB      (),                // 1-bit output: 3-state control
      .TQ       (),                // 1-bit output: 3-state control
      .CLK      (serdes_clk),      // High-speed clock
      .CLKDIV   (pixclk),          // Pixel clock
      // D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
      .D1       (tmds_p[0]),       // Data inputs
      .D2       (tmds_p[1]),
      .D3       (tmds_p[2]),
      .D4       (tmds_p[3]),
      .D5       (tmds_p[4]),
      .D6       (tmds_p[5]),
      .D7       (tmds_p[6]),
      .D8       (tmds_p[7]),
      .OCE      (1'b1),            // 1-bit input: Output data clock enable
      .RST      (!rstn),           // 1-bit input: Reset
      // SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
      .SHIFTIN1 (shiftout[0]),
      .SHIFTIN2 (shiftout[1]),
      // T1 - T4: 1-bit (each) input: Parallel 3-state inputs
      .T1       (1'b0),
      .T2       (1'b0),
      .T3       (1'b0),
      .T4       (1'b0),
      .TBYTEIN  (1'b0),            // 1-bit input: Byte group tristate
      .TCE      (1'b0)             // 1-bit input: 3-state clock enable
  );

  OSERDESE2 #(
      .DATA_RATE_OQ  ("DDR"),    // DDR, SDR
      .DATA_RATE_TQ  ("SDR"),    // DDR, BUF, SDR
      .DATA_WIDTH    (10),       // Parallel data width (2-8,10,14)
      .INIT_OQ       (1'b0),     // Initial value of OQ output (1'b0,1'b1)
      .INIT_TQ       (1'b0),     // Initial value of TQ output (1'b0,1'b1)
      .SERDES_MODE   ("SLAVE"),  // MASTER, SLAVE
      .SRVAL_OQ      (1'b0),     // OQ output value when RST is used (1'b0,1'b1)
      .SRVAL_TQ      (1'b0),     // TQ output value when RST is used (1'b0,1'b1)
      .TBYTE_CTL     ("FALSE"),  // Enable tristate byte operation (FALSE, TRUE)
      .TBYTE_SRC     ("FALSE"),  // Tristate byte source (FALSE, TRUE)
      .TRISTATE_WIDTH(1)         // 3-state converter width (1,4)
  ) OSERDESE2_inst_2 (
      .OFB      (),             // 1-bit output: Feedback path for data
      .OQ       (),             // 1-bit output: Data path output
      // SHIFTOUT1 / SHIFTOUT2: 1-bit (each) output: Data output expansion (1-bit each)
      .SHIFTOUT1(shiftout[0]),
      .SHIFTOUT2(shiftout[1]),
      .TBYTEOUT (),             // 1-bit output: Byte group tristate
      .TFB      (),             // 1-bit output: 3-state control
      .TQ       (),             // 1-bit output: 3-state control
      .CLK      (serdes_clk),   // High-speed clock
      .CLKDIV   (pixclk),       // Pixel clock
      // D1 - D8: 1-bit (each) input: Parallel data inputs (1-bit each)
      .D1       (0),            // Data inputs
      .D2       (0),
      .D3       (tmds_p[8]),
      .D4       (tmds_p[9]),
      .D5       (0),
      .D6       (0),
      .D7       (0),
      .D8       (0),
      .OCE      (1'b1),         // 1-bit input: Output data clock enable
      .RST      (!rstn),        // 1-bit input: Reset
      // SHIFTIN1 / SHIFTIN2: 1-bit (each) input: Data input expansion (1-bit each)
      .SHIFTIN1 (1'b0),
      .SHIFTIN2 (1'b0),
      // T1 - T4: 1-bit (each) input: Parallel 3-state inputs
      .T1       (1'b0),
      .T2       (1'b0),
      .T3       (1'b0),
      .T4       (1'b0),
      .TBYTEIN  (1'b0),         // 1-bit input: Byte group tristate
      .TCE      (1'b0)          // 1-bit input: 3-state clock enable
  );

  OBUFDS ob (
      .I (tmds_tx_serial),
      .O (tmds_tx_serial_p),
      .OB(tmds_tx_serial_n)
  );
endmodule


