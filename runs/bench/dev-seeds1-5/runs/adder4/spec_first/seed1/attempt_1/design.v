module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // The result of the 4-bit addition with carry-in is a 5-bit value.
    // We concatenate cout and sum to represent this full result.
    assign {cout, sum} = a + b + cin;

endmodule
