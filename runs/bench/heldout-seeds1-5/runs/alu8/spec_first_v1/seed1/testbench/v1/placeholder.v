module alu8(
    input  [7:0] a,
    input  [7:0] b,
    input  [2:0] op,
    output [7:0] y,
    output       zero,
    output       carry,
    output       overflow,
    output       negative
);
  assign y = 8'd0;
  assign zero = 1'd0;
  assign carry = 1'd0;
  assign overflow = 1'd0;
  assign negative = 1'd0;
endmodule
