module adder8(
    input  [7:0] a,
    input  [7:0] b,
    input        cin,
    output [7:0] sum,
    output       cout
);

    // The 9-bit result represents the full addition including carry out.
    // We concatenate cout and sum to capture the overflow bit.
    wire [8:0] full_result;

    assign full_result = a + b + cin;
    assign sum = full_result[7:0];
    assign cout = full_result[8];

endmodule
