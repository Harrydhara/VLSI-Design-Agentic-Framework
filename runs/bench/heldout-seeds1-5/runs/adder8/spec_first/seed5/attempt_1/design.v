module adder8(
    input  [7:0] a,
    input  [7:0] b,
    input        cin,
    output [7:0] sum,
    output       cout
);

    // The 9-bit result captures the full addition including the carry out.
    // We concatenate cout and sum to represent the 9-bit value.
    assign {cout, sum} = a + b + cin;

endmodule
