`timescale 1ns / 1ps

//TODO Marlin does not support constant expression for now
module generic_countdown_counter #(
    parameter unsigned MAX = 65536,
    parameter unsigned N   = $clog2(MAX)
) (
    input clk,
    input rstn,
    input en,

    input [N - 1:0] load_val,
    input load,

    output done
);
  reg [N - 1:0] counter = 0;

  assign done = counter == 0;

  always @(posedge clk, negedge rstn) begin
    if (!rstn) begin
      counter <= 0;
    end else begin
      if (en && !done) begin
        counter <= counter - 1;
      end else if (load && done) begin
        counter <= load_val;
      end
    end
  end
endmodule

module test_generic_countdown_counter (
    input clk,
    input rstn,
    input en,

    input [15:0] load_val,
    input load,

    output done
);
  generic_countdown_counter cnt (
      .clk(clk),
      .rstn(rstn),
      .en(en),
      .load_val(load_val),
      .load(load),
      .done(done)
  );

endmodule

