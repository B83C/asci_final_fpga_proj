interface vga_if;
  logic hsync, hblank, vsync, vblank, active, fsync;
  logic [7:0] r, g, b;

  modport consumer(input hsync, hblank, vsync, vblank, active, fsync, r, g, b);
  modport producer(output hsync, hblank, vsync, vblank, active, fsync, r, g, b);
endinterface
