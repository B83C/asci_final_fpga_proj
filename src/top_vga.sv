`timescale 1ns / 1ps
`include "defs.svh"

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

  // Should last only 1 pulse
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


  // Maximum of 10s
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

  // In milliseconds
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
          // if (latency_buffer[2])
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

  // wire measure_now = randomised_delay == ms_elapsed;

  wire hsync, hblank, vsync, vblank, active, fsync;

  integer count;
  parameter unsigned H = 1280;
  parameter unsigned V = 720;
  parameter unsigned N_H = $clog2(H);
  parameter unsigned N_V = $clog2(V);

  wire [N_H - 1:0] x;
  wire [N_V - 1:0] y;

  logic [1:0] sw;

  wire xc_end, yc_end, hactive, vactive;

  parameter unsigned C_H = 8;
  parameter unsigned C_V = 8;
  parameter unsigned SCALE_X = 2;
  parameter unsigned SCALE_Y = 2;

  parameter unsigned HCC = H / (C_H * SCALE_X);
  parameter unsigned VCC = V / (C_V * SCALE_Y);
  parameter unsigned X_BOUND = HCC * (C_H * SCALE_X) + 1;
  parameter unsigned Y_BOUND = VCC * (C_V * SCALE_Y) + 1;

  timing_counter #(
      .DISP(1280),
      .FP(110),
      .SW(40),
      .BP(220),
      .N(N_H)
  ) xc (
      .pixclk(clk),
      .rstn(rstn),
      .en(1),

      .sync(hsync),
      .x(x),
      .active(hactive),
      .ending(xc_end)
  );

  timing_counter #(
      .DISP(720),
      .FP(5),
      .SW(5),
      .BP(20),
      .N(N_V)
  ) yc (
      .pixclk(clk),
      .rstn(rstn),
      .en(xc_end),

      .sync(vsync),
      .x(y),
      .active(vactive),
      .ending(yc_end)
  );

  assign active = hactive && vactive;


  logic [$clog2(C_H) - 1:0] x_cntr = 0;
  logic [$clog2(C_V) - 1:0] y_cntr = 0;
  logic [$clog2(HCC) - 1:0] c_x = 0;
  logic [$clog2(VCC) - 1:0] c_y = 0;

  logic [$clog2(SCALE_X) - 1:0] scale_cntr_x = 0;
  logic [$clog2(SCALE_Y) - 1:0] scale_cntr_y = 0;

  (* ram_style = "block" *) logic [7:0] text_buffer[HCC * VCC];
  logic [7:0] read_ascii;

  wire rstn_x, rstn_y;
  logic [$clog2(C_H) - 1:0] glyph_pixel_x;
  logic [$clog2(C_V) - 1:0] glyph_pixel_y;
  logic [$clog2(X_BOUND) - 1:0] ascii_x;
  logic [$clog2(Y_BOUND) - 1:0] ascii_y;
  wire sx_ending, cx_ending;
  generic_counter #(
      .MAX(SCALE_X)
  ) sx (
      .clk(clk),
      .rstn(rstn && !xc_end),
      .en(hactive && 1),
      .ending(sx_ending),
      .x()
  );
  generic_counter #(
      .MAX(C_H)
  ) cx (
      .clk(clk),
      .rstn(rstn && !xc_end),
      .en(hactive && sx_ending),
      .ending(cx_ending),
      .x(glyph_pixel_x)
  );
  generic_counter #(
      .MAX(X_BOUND)
  ) xp (
      .clk(clk),
      .rstn(rstn && !xc_end),
      .en(hactive && cx_ending && sx_ending),
      .ending(),
      .x(ascii_x)
  );
  wire sy_ending, cy_ending;
  generic_counter #(
      .MAX(SCALE_Y)
  ) sy (
      .clk(clk),
      .rstn(rstn && !(xc_end && yc_end)),
      .en(vactive && xc_end),
      .ending(sy_ending),
      .x()
  );
  generic_counter #(
      .MAX(C_V)
  ) cy (
      .clk(clk),
      .rstn(rstn && !(xc_end && yc_end)),
      .en(vactive && xc_end && sy_ending),
      .ending(cy_ending),
      .x(glyph_pixel_y)
  );
  generic_counter #(
      .MAX(Y_BOUND)
  ) yp (
      .clk(clk),
      .rstn(rstn && !(xc_end && yc_end)),
      .en(vactive && xc_end && cy_ending && sy_ending),
      .ending(),
      .x(ascii_y)
  );

  wire [7:0] ascii_out;

  typedef enum {
    CENTER,
    LEFT,
    RIGHT
  } anchor_t;

  typedef struct {
    int x;
    int y;
  } pos_t;

  function automatic pos_t DS(int x, int y, string Str, anchor_t anchor = LEFT);
    int shift = 0;
    case (anchor)
      CENTER:  shift = Str.len() / 2;
      RIGHT:   shift = Str.len();
      default: shift = 0;
    endcase
    for (int j = 0; j < Str.len(); j++) begin
      text_buffer[y*HCC+x+j-shift] = unsigned'(Str[j]);
    end
    DS.x = x + Str.len() - shift;
    DS.y = y;
  endfunction

  pos_t p0, p1, p2, p3, p4, p5, p6, p7;
  initial begin
    p0 = DS(5, 6, "System State", LEFT);
    p1 = DS(5, 8, "Current: ", LEFT);
    p2 = DS(5, 10, "Latency: ", LEFT);
    void'(DS(p2.x + 5, p2.y, "ms", LEFT));
    p3 = DS(51, 16, "START", CENTER);
    p4 = DS(51, 24, "RESET", CENTER);
    p5 = '{x: 5, y: 14};
    p6 = DS(40, 1, "Human Reflex Tester", CENTER);
    p7 = DS(5, 12, "Average: ", LEFT);
    void'(DS(p7.x + 5, p7.y, "ms", LEFT));
  end

  // TODO：Make the text overlay instead of writing to the text buffer
  logic [7:0] buffer[10];
  always_comb begin
    case (sys_state)
      IDLE: buffer = {>>8{"      IDLE"}};
      INIT: buffer = {>>8{"      INIT"}};
      TRIGGERED: buffer = {>>8{"   WAITING"}};
      MEASURING: buffer = {>>8{" MEASURING"}};
      MEASURED: buffer = {>>8{"  MEASURED"}};
      SPAM: buffer = {>>8{"  SPAMMED!"}};
      default: buffer = {>>8{"UNDEFINED"}};
    endcase
  end

  logic [7:0] prompt[20];
  always_comb begin
    if (sys_state == SPAM) prompt = {>>8{"spam: dont cheat    "}};
    else if (sys_state == MEASURING) prompt = {>>8{"  >> press now <<   "}};
    else if (timed_out) prompt = {>>8{"     timed out!     "}};
    else prompt = {>>8{"                    "}};
  end

  function automatic [19:0] bin2bcd(input [14:0] bin);
    reg [19:0] bcd = 0;
    for (int i = 14; i >= 0; i = i - 1) begin
      if (bcd[3:0] >= 5) bcd[3:0] = bcd[3:0] + 3;
      if (bcd[7:4] >= 5) bcd[7:4] = bcd[7:4] + 3;
      if (bcd[11:8] >= 5) bcd[11:8] = bcd[11:8] + 3;
      if (bcd[15:12] >= 5) bcd[15:12] = bcd[15:12] + 3;
      if (bcd[19:16] >= 5) bcd[19:16] = bcd[19:16] + 3;
      bcd = {bcd[18:0], bin[i]};
    end
    return bcd;
  endfunction

  wire [19:0] bcd = bin2bcd(measured_latency);

  logic [7:0] measured_latency_bcd[5];

  assign measured_latency_bcd = '{
          "0" + bcd[19:16],
          "0" + bcd[15:12],
          "0" + bcd[11:8],
          "0" + bcd[7:4],
          "0" + bcd[3:0]
      };

  wire [19:0] avg_bcd = bin2bcd(latency_avg);

  logic [7:0] avg_bcd_digits[5];

  assign avg_bcd_digits = '{
          "0" + avg_bcd[19:16],
          "0" + avg_bcd[15:12],
          "0" + avg_bcd[11:8],
          "0" + avg_bcd[7:4],
          "0" + avg_bcd[3:0]
      };

  // ── Text buffer block RAM (inferred) ──
  // Stage 0: Registered address — multiplication by HCC (80) done as (y << 6) + (y << 4) to avoid DSP
  reg [$clog2(HCC*VCC)-1:0] text_rd_addr;
  reg [$clog2(Y_BOUND)-1:0] ascii_y_d_0;
  reg [$clog2(X_BOUND)-1:0] ascii_x_d_0;
  always @(posedge clk) begin
    // text_rd_addr <= (ascii_y * HCC) + ascii_x;
    ascii_y_d_0  <= ascii_y;
    ascii_x_d_0  <= ascii_x;
    // Temporary fix
    text_rd_addr <= (ascii_y << 6) + (ascii_y << 4) + ascii_x;
  end

  // Stage 1: BRAM output register + first coordinate delay
  reg [7:0] text_rd_q;
  reg [$clog2(Y_BOUND)-1:0] ascii_y_d;
  reg [$clog2(X_BOUND)-1:0] ascii_x_d;
  always @(posedge clk) begin
    text_rd_q <= text_buffer[text_rd_addr];
    ascii_y_d <= ascii_y_d_0;
    ascii_x_d <= ascii_x_d_0;
  end

  logic [7:0] react_text[5];
  initial begin
    react_text = {>>8{"REACT"}};
    // react_text = '{"R", "E", "A", "C", "T"};
  end
  reg latency_area, avg_area;
  // Stage 2: Overlay mux (uses ascii_y_d/ascii_x_d from stage 1)
  always @(posedge clk) begin
    read_ascii <= text_rd_q;
    foreach (buffer[i]) begin
      if (p1.y == ascii_y_d && ascii_x_d == (p1.x + unsigned'(i))) begin
        read_ascii <= buffer[i];
      end
    end
    foreach (measured_latency_bcd[i]) begin
      if (p2.y == ascii_y_d && ascii_x_d == (p2.x + unsigned'(i))) begin
        read_ascii <= measured_latency_bcd[i];
      end
    end
    foreach (avg_bcd_digits[i]) begin
      if (p7.y == ascii_y_d && ascii_x_d == (p7.x + unsigned'(i))) begin
        read_ascii <= avg_bcd_digits[i];
      end
    end
    foreach (react_text[i]) begin
      if (sys_state == MEASURING && p3.y == ascii_y_d && ascii_x_d == (p3.x - 5 + unsigned'(i))) begin
        read_ascii <= react_text[i];
      end
    end
    foreach (prompt[i]) begin
      if (p5.y == ascii_y_d && ascii_x_d == (p5.x + unsigned'(i))) begin
        read_ascii <= prompt[i];
      end
    end
    latency_area <= (p2.y == ascii_y_d) && (ascii_x_d >= p2.x) && (ascii_x_d <= p2.x + 6);
    avg_area <= (p7.y == ascii_y_d) && (ascii_x_d >= p7.x) && (ascii_x_d <= p7.x + 6);
  end

  reg latency_area_d1, latency_area_d2;
  reg avg_area_d1, avg_area_d2;
  always @(posedge clk) begin
    latency_area_d1 <= latency_area;
    latency_area_d2 <= latency_area_d1;
    avg_area_d1 <= avg_area;
    avg_area_d2 <= avg_area_d1;
  end

  // Nord colors
  localparam logic [23:0] DARKBG = 24'h2E3440;  // dark bg
  localparam logic [23:0] PANEL = 24'h3B4252;  // panel
  localparam logic [23:0] N2 = 24'h434C5E;
  localparam logic [23:0] BORDER = 24'h4C566A;  // border
  localparam logic [23:0] TEXTLIGHT = 24'hD8DEE9;  // text light
  localparam logic [23:0] N5 = 24'hE5E9F0;
  localparam logic [23:0] TEAL = 24'h8FBCBB;  // teal
  localparam logic [23:0] LIGHTBLUE = 24'h88C0D0;  // light blue
  localparam logic [23:0] BLUE = 24'h81A1C1;  // blue
  localparam logic [23:0] DARKBLUE = 24'h5E81AC;  // dark blue
  localparam logic [23:0] RED = 24'hBF616A;  // red
  localparam logic [23:0] ORANGE = 24'hD08770;  // orange
  localparam logic [23:0] YELLOW = 24'hEBCB8B;  // yellow
  localparam logic [23:0] GREEN = 24'hA3BE8C;  // green

  function automatic logic [23:0] get_latency_color(input [14:0] lat);
    if (lat < 100) return DARKBLUE;
    if (lat < 150) return GREEN;
    if (lat < 250) return YELLOW;
    if (lat < 400) return ORANGE;
    return RED;
  endfunction

  // R, G, B
  localparam logic [7:0][2:0] TextFG = TEXTLIGHT;

  // ASCII glyph ROM (1 cycle latency)
  wire [C_V - 1 : 0][C_H - 1 : 0] char_buf;
  reg  [C_V - 1 : 0][C_H - 1 : 0] char_buf_q;

  ram #(
      .WIDTH(C_H * C_V),
      .DEPTH(128),
      .BINARY_FILE("ascii.rom")
  ) ascii (
      .clk (clk),
      .addr(read_ascii[6:0]),
      .data(char_buf)
  );


  always @(posedge clk) char_buf_q <= char_buf;


  typedef enum {
    FILLED,
    HOLLOW
  } style_t;

  typedef struct packed {
    logic [10:0] x0;
    logic [10:0] y0;
    logic [10:0] x1;
    logic [10:0] y1;
    logic [23:0] color;
    style_t style;
  } rect_t;

  // UI layout constants
  localparam unsigned HDR_H = 56;
  localparam unsigned CARD_X = 40;
  localparam unsigned CARD_Y = 80;
  localparam unsigned CARD_W = 570;
  localparam unsigned CARD_H = 580;

  // Button positions (right card)
  localparam unsigned BT1_X = CARD_X + CARD_W + 72;
  localparam unsigned BT1_Y = 220;
  localparam unsigned BT1_W = 240;
  localparam unsigned BT1_H = 80;
  localparam unsigned BT2_X = BT1_X;
  localparam unsigned BT2_Y = BT1_Y + BT1_H + 60;
  localparam unsigned BT2_W = 240;
  localparam unsigned BT2_H = 60;
  localparam unsigned SHADOW = 6;

  localparam rect_t Rectangles[0:7] = '{
      // Background
      '{
          0,
          0,
          H,
          V,
          DARKBG,
          FILLED
      },
      // Header bar
      '{
          0,
          0,
          H,
          HDR_H,
          PANEL,
          FILLED
      },
      // Left card fill + border
      '{
          CARD_X,
          CARD_Y,
          CARD_X + CARD_W,
          CARD_Y + CARD_H,
          PANEL,
          FILLED
      },
      '{CARD_X, CARD_Y, CARD_X + CARD_W, CARD_Y + CARD_H, BORDER, HOLLOW},
      // Right card fill + border
      '{
          BT1_X - 30,
          CARD_Y,
          BT1_X + BT1_W + 30,
          CARD_Y + CARD_H,
          PANEL,
          FILLED
      },
      '{BT1_X - 30, CARD_Y, BT1_X + BT1_W + 30, CARD_Y + CARD_H, BORDER, HOLLOW},
      // Button 1 shadow
      '{
          BT1_X + SHADOW,
          BT1_Y + SHADOW,
          BT1_X + BT1_W + SHADOW,
          BT1_Y + BT1_H + SHADOW,
          DARKBG,
          FILLED
      },
      // Button 2 shadow
      '{
          BT2_X + SHADOW / 2,
          BT2_Y + SHADOW / 2,
          BT2_X + BT2_W + SHADOW / 2,
          BT2_Y + BT2_H + SHADOW / 2,
          DARKBG,
          FILLED
      }
  };

  function automatic draw(logic [N_H -1:0] x, logic [N_V -1:0] y, rect_t rect);

    unique case (rect.style)
      FILLED: begin
        draw = (x >= rect.x0 && x < rect.x1 && y >= rect.y0 && y < rect.y1);
      end
      HOLLOW: begin
        draw = (x >= rect.x0 &&
         x <  rect.x1 &&
         y >= rect.y0 &&
         y <  rect.y1) && (x == rect.x0 ||
         x ==  rect.x1 - 1 ||
         y == rect.y0 ||
         y ==  rect.y1 - 1);
      end
    endcase

  endfunction

  logic [23:0] pixel_color;

  always_comb begin
    pixel_color = DARKBG;
    foreach (Rectangles[i]) begin
      if (draw(x, y, Rectangles[i])) begin
        pixel_color = Rectangles[i].color;
      end
    end

    // Button 1 body (dynamic color based on button state)
    if (draw(x, y, '{BT1_X, BT1_Y, BT1_X + BT1_W, BT1_Y + BT1_H, 24'h000000, FILLED})) begin
      pixel_color = bi[0] ? BLUE : DARKBLUE;
    end
    // Button 2 body
    if (draw(x, y, '{BT2_X, BT2_Y, BT2_X + BT2_W, BT2_Y + BT2_H, 24'h000000, FILLED})) begin
      pixel_color = bi[1] ? BLUE : BORDER;
    end
  end


  logic [7:0] r, g, b;

  function automatic void draw_rgb(logic [N_H -1:0] x, logic [N_V -1:0] y, rect_t rect);
    if (draw(x, y, rect)) begin
      {r, g, b} <= rect.color;
    end
  endfunction


  assign {r, g, b} = pixel_color;


  logic [7:0] out_r, out_g, out_b;

  wire [$clog2(C_H) - 1:0] glyph_pixel_x_, glyph_pixel_y_;

  wire pixel_is_char = char_buf_q[glyph_pixel_y_][glyph_pixel_x_];
  // wire pixel_is_char = char_buf_q[glyph_pixel_y_][glyph_pixel_x_];

  // Last stage
  always @(posedge clk) begin
    {vga.r, vga.g, vga.b} <= pixel_is_char ?
        (latency_area_d2 ? get_latency_color(measured_latency) :
         avg_area_d2 ? get_latency_color(latency_avg) : TextFG) : {out_r, out_g, out_b};
  end

  localparam int Latencies = 6;
  pipe #(
      .STAGES(Latencies - 1),
      .M($clog2(C_H))
  ) gpx (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(glyph_pixel_x),
      .y(glyph_pixel_x_)
  );
  pipe #(
      .STAGES(Latencies - 1),
      .M($clog2(C_V))
  ) gpy (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(glyph_pixel_y),
      .y(glyph_pixel_y_)
  );

  pipe #(
      .STAGES(Latencies - 1),
      .M(8)
  ) r_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(r),
      .y(out_r)
  );
  pipe #(
      .STAGES(Latencies - 1),
      .M(8)
  ) g_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(g),
      .y(out_g)
  );
  pipe #(
      .STAGES(Latencies - 1),
      .M(8)
  ) b_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(b),
      .y(out_b)
  );


  pipe #(
      .STAGES(Latencies)
  ) hsync_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(hsync),
      .y(vga.hsync)
  );
  pipe #(
      .STAGES(Latencies)
  ) vsync_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(vsync),
      .y(vga.vsync)
  );
  pipe #(
      .STAGES(Latencies)
  ) hblank_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(hblank),
      .y(vga.hblank)
  );
  pipe #(
      .STAGES(Latencies)
  ) vblank_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(vblank),
      .y(vga.vblank)
  );
  pipe #(
      .STAGES(Latencies)
  ) fsync_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(fsync),
      .y(vga.fsync)
  );
  pipe #(
      .STAGES(Latencies)
  ) active_ (
      .clk(clk),
      .rstn(rstn),
      .en(1),
      .x(active),
      .y(vga.active)
  );
endmodule
