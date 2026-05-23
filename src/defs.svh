`ifndef DEFS_SVH
`define DEFS_SVH

typedef enum {
  IDLE,
  INIT,
  TRIGGERED,
  MEASURING,
  MEASURED,
  SPAM
} state_t;

// package display_params;
parameter int H = 1280;
parameter int V = 720;
parameter int C_H = 8;
parameter int C_V = 8;
parameter int SCALE_X = 2;
parameter int SCALE_Y = 2;
parameter int H_DISP = 1280;
parameter int H_FP = 110;
parameter int H_SW = 40;
parameter int H_BP = 220;
parameter int V_DISP = 720;
parameter int V_FP = 5;
parameter int V_SW = 5;
parameter int V_BP = 20;
parameter int Latencies = 6;
// endpackage

`endif
