`timescale 1ns / 1ps

module OBUFDS (
    output O,
    output OB,
    input  I
);
  assign O  =  I;
  assign OB = ~I;
endmodule
