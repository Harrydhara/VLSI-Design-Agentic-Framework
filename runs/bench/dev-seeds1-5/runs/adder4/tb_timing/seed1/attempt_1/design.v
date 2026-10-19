module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // The 5-bit result is the concatenation of cout and sum.
    // We use a temporary wire to perform the addition.
    wire [4:0] full_result;

    assign full_result = a + b + cin;
    assign {cout, sum} = full_result;

endmodule
