`timescale 1ns / 1ps

//TODO Marlin does not support constant expression for now
module generic_counter #(
    parameter unsigned MAX =1280,
    parameter unsigned ONESHOT = 0,
    parameter unsigned N = $clog2(MAX)
) (
    input clk,
    input rstn,
    input en,

    output [N - 1:0] x,

    output ending
);
  reg [N - 1:0] counter = 0;

  assign ending = counter == N'(MAX - 1);

  always @(posedge clk, negedge rstn) begin
    if (!rstn) begin
      counter <= 0;
    end else begin
      if (en) counter <= ending ? (ONESHOT ? counter : 0) : counter + 1;
    end
  end

  assign x = counter;
endmodule

module test_generic_counter (
    input clk,
    input rstn,
    input en,

    output [3:0] x,

    output ending
);
  generic_counter #(
      .MAX(16),
      .N  (4)
  ) cnt (
      .clk(clk),
      .rstn(rstn),
      .en(en),
      .x(x),
      .ending(ending)
  );

endmodule

