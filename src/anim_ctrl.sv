`timescale 1ns / 1ps
`include "defs.svh"

module anim_ctrl #(
    parameter SIM_MODE = 0,
    parameter HIST_DEPTH = 8
) (
    input clk,
    input rstn,

    input state_t sys_state,
    input ms_tick,
    input [12:0] random_delay,
    input [12:0] measured_latency,
    input [12:0] avg_latency,
    input timed_out,
    input [12:0] history[0:HIST_DEPTH-1],
    input [$clog2(HIST_DEPTH)-1:0] hist_rd,
    input [$clog2(HIST_DEPTH)-1:0] hist_wr,
    input bi_center,

    output logic [3:0][6:0] seg_out,
    output logic [3:0] dp_out,
    output logic [3:0] brightness,

    output reg anim_fade_done,
    output reg countdown_go
);

  localparam [6:0] SEG_0 = 7'b1000000;
  localparam [6:0] SEG_1 = 7'b1111001;
  localparam [6:0] SEG_2 = 7'b0100100;
  localparam [6:0] SEG_3 = 7'b0110000;
  localparam [6:0] SEG_4 = 7'b0011001;
  localparam [6:0] SEG_5 = 7'b0010010;
  localparam [6:0] SEG_6 = 7'b0000010;
  localparam [6:0] SEG_7 = 7'b1111000;
  localparam [6:0] SEG_8 = 7'b0000000;
  localparam [6:0] SEG_9 = 7'b0010000;
  localparam [6:0] SEG_A = 7'b0001000;
  localparam [6:0] SEG_b = 7'b0000011;
  localparam [6:0] SEG_C = 7'b1000110;
  localparam [6:0] SEG_d = 7'b0100001;
  localparam [6:0] SEG_E = 7'b0000110;
  localparam [6:0] SEG_F = 7'b0001110;
  localparam [6:0] SEG_G = 7'b0000100;
  localparam [6:0] SEG_O = 7'b1000000;
  localparam [6:0] SEG_T = 7'b0000111;
  localparam [6:0] SEG_S = 7'b0010010;
  localparam [6:0] SEG_P = 7'b0001100;
  localparam [6:0] SEG_M = 7'b0101011;
  localparam [6:0] SEG_V = 7'b0100011;  // c,d,e
  localparam [6:0] SEG_BLANK = 7'b1111111;

  function automatic [6:0] hex7(input [3:0] h);
    case (h)
      4'h0: hex7 = SEG_0;
      4'h1: hex7 = SEG_1;
      4'h2: hex7 = SEG_2;
      4'h3: hex7 = SEG_3;
      4'h4: hex7 = SEG_4;
      4'h5: hex7 = SEG_5;
      4'h6: hex7 = SEG_6;
      4'h7: hex7 = SEG_7;
      4'h8: hex7 = SEG_8;
      4'h9: hex7 = SEG_9;
      4'hA: hex7 = SEG_A;
      4'hB: hex7 = SEG_b;
      4'hC: hex7 = SEG_C;
      4'hD: hex7 = SEG_d;
      4'hE: hex7 = SEG_E;
      4'hF: hex7 = SEG_F;
      default: hex7 = SEG_BLANK;
    endcase
  endfunction

  function automatic [15:0] bin2bcd(input [12:0] bin);
    logic [15:0] bcd = 0;
    for (int i = 0; i < 13; i++) begin
      if (bcd[3:0] >= 5) bcd[3:0] = bcd[3:0] + 3;
      if (bcd[7:4] >= 5) bcd[7:4] = bcd[7:4] + 3;
      if (bcd[11:8] >= 5) bcd[11:8] = bcd[11:8] + 3;
      if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
      bcd = {bcd[14:0], bin[12-i]};
    end
    return bcd;
  endfunction

  // Rolling circle
  reg [2:0] roll_cnt;
  reg [9:0] roll_timer;

  // Fade animation
  reg [3:0] fade_step;
  reg [2:0] fade_phase;  // 0=fade_in, 1=fade_out, 2=blank, 3=done

  // Countdown
  reg [12:0] cd_counter;
  reg cd_running;

  // Display phase cycling in MEASURED
  // 0=OK(50t), 1=latency(2000t), 2=AVG(1000t), 3=average(1000t) → back to 1
  reg [1:0] disp_phase;
  reg [10:0] disp_timer;

  reg bi_center_d1;
  wire bi_center_rise;

  always @(posedge clk) bi_center_d1 <= bi_center;
  assign bi_center_rise = bi_center && !bi_center_d1;

  always @(posedge clk, negedge rstn) begin
    if (!rstn) begin
      roll_cnt <= 0;
      roll_timer <= 0;
      fade_step <= 0;
      fade_phase <= 0;
      cd_counter <= 0;
      cd_running <= 0;
      anim_fade_done <= 0;
      countdown_go <= 0;
      disp_phase <= 0;
      disp_timer <= 0;
    end else begin
      // Defaults
      anim_fade_done <= 0;

      case (sys_state)
        IDLE: begin
          fade_step <= 0;
          fade_phase <= 0;
          cd_counter <= 0;
          cd_running <= 0;
          countdown_go <= 0;
          anim_fade_done <= 0;

          // Rolling circle
          if (ms_tick) begin
            if (roll_timer >= 249) begin
              roll_timer <= 0;
              roll_cnt <= roll_cnt + 1;
            end else begin
              roll_timer <= roll_timer + 1;
            end
          end
        end

        INIT: begin
          roll_cnt <= 0;
          roll_timer <= 0;
          if (ms_tick) begin
            if (!anim_fade_done) begin
              if (fade_phase == 0) begin
                // Fade in (15 steps @ 20ms each = 300ms)
                if (fade_step < 15) begin
                  if (roll_timer >= 19) begin
                    roll_timer <= 0;
                    fade_step <= fade_step + 1;
                  end else begin
                    roll_timer <= roll_timer + 1;
                  end
                end else begin
                  fade_step <= 15;
                  fade_phase <= 1;
                  roll_timer <= 0;
                end
              end else if (fade_phase == 1) begin
                // Fade out (15 steps @ 20ms each = 300ms)
                if (fade_step > 0) begin
                  if (roll_timer >= 19) begin
                    roll_timer <= 0;
                    fade_step <= fade_step - 1;
                  end else begin
                    roll_timer <= roll_timer + 1;
                  end
                end else begin
                  fade_step <= 0;
                  fade_phase <= 2;
                  roll_timer <= 0;
                end
              end else if (fade_phase == 2) begin
                // Blank phase (200ms)
                if (roll_timer >= 199) begin
                  roll_timer <= 0;
                  fade_phase <= 3;
                end else begin
                  roll_timer <= roll_timer + 1;
                end
              end else begin
                anim_fade_done <= 1;
              end
            end
          end
        end

        TRIGGERED: begin
          if (!cd_running && !countdown_go) begin
            cd_counter <= random_delay;
            cd_running <= 1;
          end

          if (ms_tick && cd_running) begin
            if (cd_counter == 0) begin
              cd_running <= 0;
              countdown_go <= 1;
            end else begin
              cd_counter <= cd_counter - 1;
            end
          end

          // Rolling circle during countdown
          if (ms_tick && cd_running) begin
            if (roll_timer >= 49) begin
              roll_timer <= 0;
              roll_cnt <= roll_cnt + 1;
            end else begin
              roll_timer <= roll_timer + 1;
            end
          end
        end

        MEASURED: begin
          if (disp_phase == 0) begin
            disp_phase <= 1;
            disp_timer <= 0;
          end else if (ms_tick) begin
            if (disp_timer == 0) begin
              // Phase timer starts fresh or resets
            end
            disp_timer <= disp_timer + 1;
            case (disp_phase)
              1: if (disp_timer >= 2000) begin disp_phase <= 2; disp_timer <= 0; end  // latency
              2: if (disp_timer >= 1000) begin disp_phase <= 3; disp_timer <= 0; end  // AVG
              3: if (disp_timer >= 1000) begin disp_phase <= 1; disp_timer <= 0; end  // average → back
            endcase
          end
        end

        default: begin
          roll_cnt <= 0;
          roll_timer <= 0;
          fade_step <= 0;
          fade_phase <= 0;
          disp_phase <= 0;
          disp_timer <= 0;
        end
      endcase
    end
  end

  reg bi_center_rise_d1;
  always @(posedge clk) bi_center_rise_d1 <= bi_center_rise;

  // Display combinational decode
  logic [3:0] disp_brightness;
  logic [3:0][6:0] disp_seg;
  logic [3:0] disp_dp;

  always @(*) begin
    disp_seg = '{SEG_BLANK, SEG_BLANK, SEG_BLANK, SEG_BLANK};
    disp_dp = 4'b1111;
    disp_brightness = 4'hF;

    case (sys_state)
      IDLE: begin
        disp_seg[roll_cnt[1:0]] = SEG_8;
      end

      INIT: begin
        disp_seg = '{SEG_8, SEG_8, SEG_8, SEG_8};
        disp_brightness = fade_step;
      end

      TRIGGERED: begin
        if (countdown_go) begin
          disp_seg[3] = SEG_BLANK;
          disp_seg[2] = SEG_G;
          disp_seg[1] = SEG_O;
          disp_seg[0] = SEG_BLANK;
        end else begin
          disp_seg[roll_cnt[1:0]] = SEG_8;
        end
      end

      MEASURING: begin
        disp_seg = '{SEG_BLANK, SEG_BLANK, SEG_BLANK, SEG_BLANK};
      end

      MEASURED: begin
        if (timed_out) begin
          disp_seg[3] = SEG_BLANK;
          disp_seg[2] = SEG_T;
          disp_seg[1] = SEG_O;
          disp_seg[0] = SEG_BLANK;
        end else if (disp_phase == 0) begin
          disp_seg[3] = SEG_BLANK;
          disp_seg[2] = SEG_O;
          disp_seg[1] = SEG_BLANK;
          disp_seg[0] = SEG_BLANK;
          disp_dp = 4'b1011;  // dot on 'O' -> "OK."
        end else if (disp_phase == 2) begin
          disp_seg[3] = SEG_BLANK;
          disp_seg[2] = SEG_A;
          disp_seg[1] = SEG_V;
          disp_seg[0] = SEG_G;
        end else if (disp_phase == 3) begin
          logic [15:0] bcd;
          bcd = bin2bcd(avg_latency);
          disp_seg[3] = hex7(bcd[15:12]);
          disp_seg[2] = hex7(bcd[11:8]);
          disp_seg[1] = hex7(bcd[7:4]);
          disp_seg[0] = hex7(bcd[3:0]);
        end else begin
          logic [15:0] bcd;
          logic [12:0] disp_val;
          if (hist_rd == 0) disp_val = measured_latency;
          else disp_val = history[hist_rd];
          bcd = bin2bcd(disp_val);
          disp_seg[3] = hex7(bcd[15:12]);
          disp_seg[2] = hex7(bcd[11:8]);
          disp_seg[1] = hex7(bcd[7:4]);
          disp_seg[0] = hex7(bcd[3:0]);
        end
      end

      SPAM: begin
        disp_seg[3] = SEG_S;
        disp_seg[2] = SEG_P;
        disp_seg[1] = SEG_A;
        disp_seg[0] = SEG_M;
      end
    endcase
  end

  assign seg_out = disp_seg;
  assign dp_out = disp_dp;
  assign brightness = disp_brightness;

endmodule
