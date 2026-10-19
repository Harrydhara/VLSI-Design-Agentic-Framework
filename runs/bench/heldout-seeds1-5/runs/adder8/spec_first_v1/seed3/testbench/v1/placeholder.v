module adder8(
    input  [7:0] a,
    input  [7:0] b,
    input        cin,
    output [7:0] sum,
    output       cout
);
  assign sum = 8'd0;
  assign cout = 1'd0;
endmodule
