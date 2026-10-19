module adder8(
    input  [7:0] a,
    input  [7:0] b,
    input        cin,
    output [7:0] sum,
    output       cout
);

    // The 9-bit result of the addition including carry-in and carry-out.
    // We concatenate cout and sum to represent the full arithmetic result.
    assign {cout, sum} = a + b + cin;

endmodule
