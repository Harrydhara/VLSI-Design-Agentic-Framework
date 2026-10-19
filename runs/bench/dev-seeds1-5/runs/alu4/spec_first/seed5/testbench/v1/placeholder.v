module alu4(
    input  [3:0] a,
    input  [3:0] b,
    input  [2:0] op,
    output [3:0] y,
    output       zero,
    output       carry,
    output       overflow,
    output       negative
);
  assign y = 4'd0;
  assign zero = 1'd0;
  assign carry = 1'd0;
  assign overflow = 1'd0;
  assign negative = 1'd0;
endmodule
