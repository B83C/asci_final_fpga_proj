`timescale 1ns / 1ps

module seven_seg (
    input  logic            clk,
    input  logic            rstn,
    input  logic [3:0]      brightness,
    input  logic [3:0][6:0] seg_in,
    input  logic [3:0]      dp,
    output logic [3:0]      an,
    output logic [7:0]      seg
);

  logic [16:0] refresh_cnt;
  logic [ 1:0] digit_sel;

  always_ff @(posedge clk, negedge rstn) begin
    if (!rstn) refresh_cnt <= 0;
    else refresh_cnt <= refresh_cnt + 1;
  end

  assign digit_sel = refresh_cnt[16:15];

  logic [3:0] pwm_cnt;
  always_ff @(posedge clk, negedge rstn) begin
    if (!rstn) pwm_cnt <= 0;
    else pwm_cnt <= pwm_cnt + 1;
  end

  wire       pwm_on = pwm_cnt < brightness;

  wire [6:0] seg_mux = seg_in[digit_sel];
  wire       dp_mux = dp[digit_sel];

  assign seg = {~dp_mux, seg_mux};

  always_comb begin
    an = 4'b1111;
    if (pwm_on) begin
      an[digit_sel] = 0;
    end
  end

endmodule
