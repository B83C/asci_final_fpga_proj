`timescale 1ns / 1ps

module debouncer #(
    parameter unsigned DEPTH  = 64,
    parameter unsigned INVERT = 1
) (
    input clk,
    input rstn,
    input raw_input,
    output reg debounced_output
);
  localparam unsigned Next2Pos = ($clog2(DEPTH) + 1);
  localparam unsigned CyclesRounded = 1 << Next2Pos;
  localparam unsigned MIDPOINT = Next2Pos - 1;
  // To eliminate meta-stability
  logic [1 + DEPTH:0] buffers;
  always @(posedge clk, negedge rstn) begin
    buffers <= {buffers[DEPTH:0], raw_input ^ 1'(INVERT)};
    if (!rstn) begin
      buffers <= 0;
    end
  end

  typedef enum {
    ALL_ONES,
    ALL_ZEROS
  } local_state_t;

  local_state_t ss = ALL_ZEROS;

  wire all_ones = &buffers[1+:DEPTH];
  wire all_zeros = !(|buffers[1+:DEPTH]);

  always @(posedge clk, negedge rstn) begin
    if (!rstn) begin
      debounced_output <= 0;
    end else begin
      unique case (ss)
        ALL_ONES: begin
          if (all_zeros) begin
            debounced_output <= 0;
            ss <= ALL_ZEROS;
          end
          if (!debounced_output) debounced_output <= 1;

        end
        ALL_ZEROS: begin
          if (all_ones) begin
            debounced_output <= 1;
            ss <= ALL_ONES;
          end
          if (debounced_output) debounced_output <= 0;
        end
      endcase

    end
  end

endmodule

