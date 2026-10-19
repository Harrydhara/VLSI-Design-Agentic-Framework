module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // The 5-bit result captures the full addition including carry out.
    // {cout, sum} = a + b + cin
    assign {cout, sum} = a + b + cin;

endmodule
