`timescale 1ns / 1ps

module tb_debouncer;
  logic clk = 0;
  logic rstn;
  logic raw_input;
  logic debounced_output;

  // DEPTH=8 → shift register must see 8 consecutive identical samples
  // → output changes after 8 consecutive cycles
  debouncer #(
      .DEPTH(8),
      .INVERT(1)
  ) dut (
      .*
  );

  always #5 clk = ~clk;

  `define CHECK(expr, msg) \
      if (!(expr)) $warning("FAIL %s at t=%0t", msg, $time); \
      else $display("PASS %s", msg)

  // Wait for debounced to reach value v with timeout
  task wait_for(input v, input int timeout = 500);
    while (debounced_output !== v && timeout > 0) begin
      @(posedge clk);
      timeout = timeout - 1;
    end
    if (timeout == 0) $fatal(0, "timeout waiting for debounced=%0b", v);
  endtask

  // Wait N posedges
  task wait_cycles(input int n);
    repeat (n) @(posedge clk);
  endtask

  initial begin
    $display("=== debouncer testbench (DEPTH=8) ===");
    rstn      = 1;
    raw_input = 1;  // inactive (active-low with INVERT=1)
    @(posedge clk);
    rstn = 0;
    wait_cycles(4);
    rstn = 1;

    // Wait for clock_divider to settle
    wait_cycles(4);
    `CHECK(debounced_output == 0, "reset: output low");

    // ────────────────────────────────────────────────────
    // 1. Press → output goes high and stays high for many cycles
    // ────────────────────────────────────────────────────
    $display("--- long press ---");
    raw_input = 0;
    wait_for(1);
    `CHECK(debounced_output == 1, "press: output goes high");

    // Verify stability: once output is high, it should stay high
    // for at least 40 consecutive cycles
    for (int i = 0; i < 40; i++) begin
      `CHECK(debounced_output == 1, $sformatf("press: stable at cycle %0d", i));
      @(posedge clk);
    end

    // ────────────────────────────────────────────────────
    // 2. Hold (keep pressed) → output still stable
    // ────────────────────────────────────────────────────
    $display("--- hold ---");
    wait_cycles(10);
    `CHECK(debounced_output == 1, "hold: still high");

    // ────────────────────────────────────────────────────
    // 3. Release → output goes low
    // ────────────────────────────────────────────────────
    $display("--- release ---");
    raw_input = 1;
    wait_for(0);
    `CHECK(debounced_output == 0, "release: output goes low");

    // ────────────────────────────────────────────────────
    // 4. Glitch rejection (1-cycle active pulse)
    // ────────────────────────────────────────────────────
    $display("--- glitch ---");
    raw_input = 0;
    @(posedge clk);  // 1-cycle low pulse
    raw_input = 1;
    wait_cycles(40);
    // Counter never reaches threshold → output stays low
    `CHECK(debounced_output == 0, "glitch: output unchanged");

    // ────────────────────────────────────────────────────
    // 5. Press again
    // ────────────────────────────────────────────────────
    $display("--- press again ---");
    raw_input = 0;
    wait_for(1);
    `CHECK(debounced_output == 1, "press-again: output goes high");

    // ────────────────────────────────────────────────────
    // 6. Reset while pressed → output forced low
    // ────────────────────────────────────────────────────
    $display("--- reset ---");
    rstn = 0;
    @(posedge clk);
    `CHECK(debounced_output == 0, "reset: output forced low");

    // ────────────────────────────────────────────────────
    // 7. Press after reset
    // ────────────────────────────────────────────────────
    $display("--- press after reset ---");
    rstn = 1;
    wait_cycles(10);
    raw_input = 0;
    wait_for(1);
    `CHECK(debounced_output == 1, "press-after-reset: output goes high");

    $display("=== ALL TESTS PASSED ===");
    $finish;
  end

  initial begin
    if ($test$plusargs("trace")) begin
      $dumpfile("tests/tb_debouncer.fst");
      $dumpvars(0, tb_debouncer);
    end
  end
endmodule
