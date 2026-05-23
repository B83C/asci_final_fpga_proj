`timescale 1ns / 1ps
`include "defs.svh"

module state (
    input clk,
    input ready,
    input halt,
    input [1:0] bi,
    output state_t sys_state
);
  logic   hold = 0;
  state_t state = IDLE;
  assign sys_state = state;

  always @(posedge clk) begin
    if (hold && !ready) begin
      hold <= 0;
    end
    case (state)
      IDLE: begin
        if (ready && !hold) begin
          hold  <= 1;
          state <= INIT;
        end
      end
      INIT: begin
        if (ready && !hold) begin
          hold <= 1;
        end else if (!hold) begin
          state <= TRIGGERED;
          hold  <= 1;
        end
      end
      TRIGGERED: begin
        if (halt) begin
          state <= SPAM;
          hold  <= 0;
        end else if (ready && !hold) begin
          state <= MEASURING;
          hold  <= 1;
        end
      end
      MEASURING: begin
        if (ready && !hold) begin
          state <= MEASURED;
          hold  <= 1;
        end
      end
      MEASURED: begin
        if (ready && !hold) begin
          state <= IDLE;
          hold  <= 1;
        end
      end
      SPAM: begin
        if (ready && !hold) begin
          state <= IDLE;
          hold  <= 1;
        end
      end
      default: begin
      end
    endcase
  end
endmodule
