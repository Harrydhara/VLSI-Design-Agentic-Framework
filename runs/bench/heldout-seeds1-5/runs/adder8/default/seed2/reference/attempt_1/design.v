module adder8(
    input  [7:0] a,
    input  [7:0] b,
    input        cin,
    output [7:0] sum,
    output       cout
);

    // The 9-bit result is the concatenation of cout and sum.
    // We perform the addition using a 9-bit intermediate value to capture the carry.
    assign {cout, sum} = a + b + cin;

endmodule
