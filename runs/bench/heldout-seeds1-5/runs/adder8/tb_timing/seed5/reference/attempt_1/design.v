module adder8(
    input  [7:0] a,
    input  [7:0] b,
    input        cin,
    output [7:0] sum,
    output       cout
);

    // The 9-bit result captures the full addition including carry out.
    // We concatenate cout and sum to represent the 9-bit value.
    wire [8:0] full_result;

    assign full_result = a + b + cin;
    assign {cout, sum} = full_result;

endmodule
