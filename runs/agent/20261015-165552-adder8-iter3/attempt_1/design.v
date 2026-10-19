module adder8(
    input  [7:0] a,
    input  [7:0] b,
    input        cin,
    output [7:0] sum,
    output       cout
);

    // The 9-bit result is the concatenation of cout and sum.
    // We use a single assignment to ensure it's purely combinational.
    assign {cout, sum} = a + b + cin;

endmodule
