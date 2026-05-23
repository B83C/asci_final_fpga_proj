`timescale 1ns / 1ps
`include "defs.svh"
import display_params::*;

module top_vga #(
    parameter unsigned CLK_HZ = 75000000
) (
    input clk,
    input rstn,

    input [1:0] buttons,

    output reg [1:0] leds,

    vga_if vga
);
  wire [1:0] bi;
  generate
    genvar j;
    for (j = 0; j < 2; j++) begin : gen_debouncer
      localparam unsigned STAGES = 16;
      wire stage[STAGES];
      genvar i;
      for (i = 0; i < STAGES; i++) begin : gen_debouncer_stage
        wire out;
        debouncer #(
            .DEPTH (2),
            .INVERT(i == 0)
        ) db (
            .rstn(rstn),
            .clk(clk),
            .raw_input(i == 0 ? buttons[j] : stage[i-1]),
            .debounced_output(out)
        );
        if (i == STAGES - 1) begin : gen_assign_to_final
          assign bi[j] = out;
        end else begin : gen_assign_to_inner_stages
          assign stage[i] = out;
        end
      end
    end
  endgenerate

  state_t sys_state;

  wire reset_counter;

  wire ms_passed;
  generic_counter #(
      .MAX(CLK_HZ / 1000)
  ) ms_generator (
      .clk(clk),
      .rstn(rstn && !reset_counter),
      .en(sys_state == MEASURING || sys_state == TRIGGERED),
      .ending(ms_passed),
      .x()
  );


  wire ms_done;
  wire [$clog2(30000) - 1:0] ms_elapsed;

  generic_counter #(
      .MAX(5000),
      .ONESHOT(1)
  ) ms_counter (
      .clk(clk),
      .rstn(rstn && !reset_counter),
      .en(ms_passed && sys_state == MEASURING),
      .ending(ms_done),
      .x(ms_elapsed)
  );

  logic [$clog2(10000) - 1:0] randomised_delay;
  lfsr #(
      .MAX(5000),
      .MIN(2000)
  ) rand_gen (
      .clk (clk),
      .rstn(rstn),
      .en  (sys_state == IDLE && bi[0]),
      .out (randomised_delay)
  );

  wire countdown_done;

  generic_countdown_counter #(
      .MAX(10000)
  ) ms_countdown (
      .clk(clk),
      .rstn(rstn && !reset_counter),
      .load_val(randomised_delay),
      .load(sys_state == INIT),
      .en(ms_passed && sys_state == TRIGGERED && !bi[0]),
      .done(countdown_done)
  );

  logic [$clog2(30000) - 1:0] measured_latency;
  logic [$clog2(30000) - 1:0] latency_buffer[3];
  logic [$clog2(30000) - 1:0] latency_avg;

  parameter unsigned HIST_DEPTH = 3;


  wire ready = rstn && ((sys_state == IDLE)? bi[0]:
                (sys_state == TRIGGERED)? countdown_done && ms_passed :
                (sys_state == MEASURING)? bi[0] || ms_done :
                (sys_state == MEASURED)? bi[1] :
                (sys_state == SPAM)? bi[1] :
                0);

  logic [5:0] spam_count;
  generic_counter #(
      .MAX(64)
  ) spam_counter (
      .clk((sys_state == TRIGGERED) && bi[0]),
      .rstn(rstn && !(sys_state == IDLE)),
      .en(1),
      .ending(),
      .x(spam_count)
  );
  wire  halt = (sys_state == TRIGGERED) && (spam_count >= 20);
  logic timed_out;

  always @(posedge clk) begin
    if (!rstn || reset_counter) timed_out <= 0;
    if (ms_done && !bi[0]) timed_out <= 1;
  end

  state system_state (
      .clk(clk),
      .ready(ready),
      .halt(halt),
      .bi(bi),
      .sys_state(sys_state)
  );

  assign reset_counter = (sys_state == MEASURED || sys_state == SPAM) && (ready);

  always @(posedge clk) begin
    case (sys_state)
      MEASURING: begin
        if (ready && !ms_done) begin
          measured_latency  <= ms_elapsed;
          latency_buffer[0] <= ms_elapsed;
          latency_buffer[1] <= latency_buffer[0];
          latency_buffer[2] <= latency_buffer[1];
          if (latency_buffer[HIST_DEPTH-1] == 0) begin
            latency_buffer[1] <= ms_elapsed;
            latency_buffer[2] <= ms_elapsed;
            latency_avg <= ms_elapsed;
          end else begin
            latency_avg <= latency_avg + ((ms_elapsed) / HIST_DEPTH) -
            ((latency_buffer[HIST_DEPTH-1]) / HIST_DEPTH);
          end
        end
      end
      default: begin
      end
    endcase
    for (int i = 0; i < 2; i++) begin
      leds[i] <= bi[i];
    end
  end

  localparam N_H = $clog2(H);
  localparam N_V = $clog2(V);

  wire hsync, vsync, hactive, vactive, xc_end, yc_end;
  wire [N_H-1:0] x;
  wire [N_V-1:0] y;

  vga_timing timing (
      .clk(clk),
      .rstn(rstn),
      .hsync(hsync),
      .vsync(vsync),
      .hactive(hactive),
      .vactive(vactive),
      .xc_end(xc_end),
      .yc_end(yc_end),
      .x(x),
      .y(y)
  );

  wire vga_hsync, vga_vsync, vga_active;
  logic [7:0] vga_r, vga_g, vga_b;

  display_pipeline display (
      .clk(clk),
      .rstn(rstn),
      .hactive(hactive),
      .vactive(vactive),
      .xc_end(xc_end),
      .yc_end(yc_end),
      .x(x),
      .y(y),
      .hsync(hsync),
      .vsync(vsync),
      .sys_state(sys_state),
      .bi(bi),
      .measured_latency(measured_latency),
      .latency_avg(latency_avg),
      .timed_out(timed_out),
      .vga_hsync(vga_hsync),
      .vga_vsync(vga_vsync),
      .vga_active(vga_active),
      .vga_r(vga_r),
      .vga_g(vga_g),
      .vga_b(vga_b)
  );

  assign vga.hblank = ~hactive;
  assign vga.vblank = ~vactive;
  assign vga.fsync = vsync;

  assign vga.hsync = vga_hsync;
  assign vga.vsync = vga_vsync;
  assign vga.active = vga_active;
  assign {vga.r, vga.g, vga.b} = {vga_r, vga_g, vga_b};
endmodule
