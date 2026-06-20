`timescale 1ns / 1ps
`include "defs.svh"

module top_basys3 #(
    parameter SIM_MODE = 0
) (
    input clk,
    input rstn,
    input btn_center,
    input btn_up,
    input btn_down,
    input btn_left,
    input btn_right,
    output logic [3:0] an,
    output logic [7:0] seg,
    output logic [15:0] led,
    output buzz
);

  localparam MS_CNT = SIM_MODE ? 100 : 100000;
  localparam DB_MS = SIM_MODE ? 2 : 10;
  localparam DB_MAX = MS_CNT * DB_MS;
  localparam TIMEOUT_MS = SIM_MODE ? 15 : 5000;
  localparam HIST_DEPTH = 8;

  // === Counter-based debouncing (10ms at 100MHz) ===
  wire [4:0] bi;
  logic bc, bu, bd, bl;
  logic [$clog2(DB_MAX)-1:0] dbc, dbu, dbd, dbl;

  always @(posedge clk, negedge rstn) begin
    if (!rstn) begin dbc <= 0; bc <= 0; end
    else begin
      if (btn_center != bc) begin
        if (dbc == DB_MAX - 1) begin bc <= btn_center; dbc <= 0; end
        else dbc <= dbc + 1;
      end else dbc <= 0;
    end
  end
  always @(posedge clk, negedge rstn) begin
    if (!rstn) begin dbu <= 0; bu <= 0; end
    else begin
      if (btn_up != bu) begin
        if (dbu == DB_MAX - 1) begin bu <= btn_up; dbu <= 0; end
        else dbu <= dbu + 1;
      end else dbu <= 0;
    end
  end
  always @(posedge clk, negedge rstn) begin
    if (!rstn) begin dbd <= 0; bd <= 0; end
    else begin
      if (btn_down != bd) begin
        if (dbd == DB_MAX - 1) begin bd <= btn_down; dbd <= 0; end
        else dbd <= dbd + 1;
      end else dbd <= 0;
    end
  end
  always @(posedge clk, negedge rstn) begin
    if (!rstn) begin dbl <= 0; bl <= 0; end
    else begin
      if (btn_left != bl) begin
        if (dbl == DB_MAX - 1) begin bl <= btn_left; dbl <= 0; end
        else dbl <= dbl + 1;
      end else dbl <= 0;
    end
  end

  assign bi = {1'b0, bl, bd, bu, bc};  // bi[0]=center, bi[1]=up, bi[2]=down, bi[3]=left

  // === FSM state ===
  state_t sys_state;

  // === 1ms tick ===
  wire ms_passed;
  generic_counter #(
      .MAX(MS_CNT)
  ) ms_generator (
      .clk(clk),
      .rstn(rstn),
      .en(1'b1),
      .ending(ms_passed),
      .x()
  );

  wire reset_counter = (sys_state == MEASURED) && bi[3];

  wire ms_done;

  // === Latency counter (oneshot) ===
  wire [$clog2(TIMEOUT_MS) - 1:0] ms_elapsed;
  generic_counter #(
      .MAX(TIMEOUT_MS),
      .ONESHOT(1)
  ) ms_counter (
      .clk(clk),
      .rstn(rstn && !reset_counter),
      .en(ms_passed && sys_state == MEASURING),
      .ending(ms_done),
      .x(ms_elapsed)
  );

  // === Random delay ===
  wire [$clog2(5000) - 1:0] randomised_delay;
  lfsr #(
      .MAX(5000),
      .MIN(2000)
  ) rand_gen (
      .clk (clk),
      .rstn(rstn),
      .en  (sys_state == IDLE && bi[0]),
      .out (randomised_delay)
  );

  // === Countdown counter ===
  wire countdown_done;
  generic_countdown_counter #(
      .MAX(10000)
  ) ms_countdown (
      .clk(clk),
      .rstn(rstn && !reset_counter),
      .load_val(randomised_delay),
      .load(sys_state == INIT),
      .en(ms_passed && sys_state == TRIGGERED),
      .done(countdown_done)
  );

  // === Spam detection ===
  logic [2:0] spam_count;
  logic hold_spam = 0;

  always @(posedge clk, negedge rstn) begin
    if (!rstn) begin
      spam_count <= 0;
      hold_spam  <= 0;
    end else begin
      if (sys_state == TRIGGERED) begin
        if (hold_spam && !bi[0]) hold_spam <= 0;
        if (bi[0] && !hold_spam) begin
          hold_spam  <= 1;
          spam_count <= spam_count + 1;
        end
      end else begin
        spam_count <= 0;
        hold_spam  <= 0;
      end
    end
  end

  wire halt;
  assign halt = (sys_state == TRIGGERED) && (spam_count >= 5);

  // === FSM ready signal (your original style) ===
  wire ready = rstn && ((sys_state == IDLE) ? bi[0] :
                  (sys_state == TRIGGERED) ? countdown_done && ms_passed :
                  (sys_state == MEASURING) ? bi[0] || ms_done :
                  (sys_state == MEASURED) ? bi[3] :
                  (sys_state == SPAM) ? bi[3] :
                  0);

  // === FSM instantiation ===
  state system_state (
      .clk(clk),
      .ready(ready),
      .halt(halt),
      .bi(bi[1:0]),
      .sys_state(sys_state)
  );

  // === Data capture (shift-register history, like top_vga) ===
  localparam LATENCY_W = 13;
  logic [LATENCY_W - 1:0] measured_latency;
  logic timed_out;
  logic [LATENCY_W - 1:0] history[0:HIST_DEPTH-1];
  logic [$clog2(HIST_DEPTH)-1:0] hist_wr;  // count of writes
  logic [$clog2(HIST_DEPTH)-1:0] hist_rd;
  logic [LATENCY_W + 2:0] avg_latency;

  logic hold_up = 0;
  logic hold_down = 0;

  always @(posedge clk, negedge rstn) begin
    if (!rstn) begin
      measured_latency <= 0;
      timed_out <= 0;
      hist_wr <= 0;
      hist_rd <= 0;
      avg_latency <= 0;
      hold_up <= 0;
      hold_down <= 0;
      for (int i = 0; i < HIST_DEPTH; i++) history[i] <= 0;
    end else begin
      if (reset_counter) timed_out <= 0;

      unique case (sys_state)
        MEASURING: begin
          if (ready && !ms_done) begin
            measured_latency <= ms_elapsed;
            history[0] <= ms_elapsed;
            for (int i = 1; i < HIST_DEPTH; i++) history[i] <= history[i-1];
            if (history[HIST_DEPTH-1] == 0) begin
              for (int i = 1; i < HIST_DEPTH; i++) history[i] <= ms_elapsed;
              avg_latency <= ms_elapsed;
            end else begin
              avg_latency <= avg_latency + (ms_elapsed / HIST_DEPTH) -
                             (history[HIST_DEPTH-1] / HIST_DEPTH);
            end
            hist_wr <= hist_wr + 1;
            hist_rd <= 0;
          end
          if (ms_done && !bi[0] && !timed_out) begin
            timed_out <= 1;
            history[0] <= ms_elapsed;
            for (int i = 1; i < HIST_DEPTH; i++) history[i] <= history[i-1];
            if (history[HIST_DEPTH-1] == 0) begin
              for (int i = 1; i < HIST_DEPTH; i++) history[i] <= ms_elapsed;
              avg_latency <= ms_elapsed;
            end else begin
              avg_latency <= avg_latency + (ms_elapsed / HIST_DEPTH) -
                             (history[HIST_DEPTH-1] / HIST_DEPTH);
            end
            hist_wr <= hist_wr + 1;
            hist_rd <= 0;
          end
        end

        MEASURED: begin
          if (bi[1] && !hold_up) begin
            hold_up <= 1;
            if (hist_rd > 0) hist_rd <= hist_rd - 1;
            else if (hist_wr >= HIST_DEPTH) hist_rd <= 3'(HIST_DEPTH - 1);
          end
          if (hold_up && !bi[1]) hold_up <= 0;
          if (bi[2] && !hold_down) begin
            hold_down <= 1;
            if (hist_rd < 3'(HIST_DEPTH - 1) && hist_rd + 1 < hist_wr) hist_rd <= hist_rd + 1;
            else hist_rd <= 0;
          end
          if (hold_down && !bi[2]) hold_down <= 0;
        end

        default: begin
        end
      endcase
    end
  end

  // === Animation controller ===
  wire [3:0][6:0] disp_seg;
  wire [3:0] disp_dp;
  wire [3:0] disp_br;

  anim_ctrl #(
      .SIM_MODE  (SIM_MODE),
      .HIST_DEPTH(HIST_DEPTH)
  ) u_anim (
      .clk(clk),
      .rstn(rstn),
      .sys_state(sys_state),
      .ms_tick(ms_passed),
      .random_delay(randomised_delay),
      .measured_latency(measured_latency),
      .avg_latency(avg_latency[LATENCY_W-1:0]),
      .timed_out(timed_out),
      .history(history),
      .hist_rd(hist_rd),
      .hist_wr(hist_wr),
      .bi_center(bi[0]),
      .seg_out(disp_seg),
      .dp_out(disp_dp),
      .brightness(disp_br),
      .anim_fade_done(),
      .countdown_go()
  );

  // === 7-segment driver ===
  seven_seg u_seg (
      .clk(clk),
      .rstn(rstn),
      .brightness(disp_br),
      .seg_in(disp_seg),
      .dp(disp_dp),
      .an(an),
      .seg(seg)
  );

  // === Buzzer control ===
  logic [2:0] buzz_tune;
  logic buzz_play;
  state_t sys_state_d1;

  always @(posedge clk, negedge rstn) begin
    if (!rstn) begin
      sys_state_d1 <= IDLE;
    end else begin
      sys_state_d1 <= sys_state;
    end
  end

  assign buzz_play = (sys_state == MEASURED && sys_state_d1 != MEASURED);

  always @(posedge clk, negedge rstn) begin
    if (!rstn) begin
      buzz_tune <= 0;
    end else begin
      if (timed_out) buzz_tune <= 4;
      else if (measured_latency < 200) buzz_tune <= 0;
      else if (measured_latency < 300) buzz_tune <= 1;
      else if (measured_latency < 400) buzz_tune <= 2;
      else buzz_tune <= 3;
    end
  end

  buzzer u_buzz (
      .clk(clk),
      .rstn(rstn),
      .ms_tick(ms_passed),
      .play(buzz_play),
      .tune_sel(buzz_tune),
      .buzz(buzz)
  );

  // === LEDs ===
  assign led[0] = (sys_state == MEASURED);
  assign led[15:1] = 0;

endmodule
