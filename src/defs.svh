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

`endif
