`timescale 1ns / 1ps

module clk_wiz_0 (
    input  clk_in1,
    input  reset,
    output clk_75,
    output clk_375,
    output locked
);
  reg pixclk = 0;
  reg serdesclk = 0;
  reg lock = 0;

  always #6.667 pixclk = ~pixclk;     // 75 MHz => 13.333 ns period

  always #1.333 serdesclk = ~serdesclk; // 375 MHz => 2.667 ns period

  initial begin
    #200;
    lock = 1;
  end

  assign clk_75  = pixclk;
  assign clk_375 = serdesclk;
  assign locked  = lock;

endmodule
