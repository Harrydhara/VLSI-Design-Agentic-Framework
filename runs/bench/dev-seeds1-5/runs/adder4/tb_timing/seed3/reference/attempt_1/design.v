module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // The 5-bit result of the addition including carry-in
    wire [4:0] full_result;

    // Perform the addition using concatenation to capture the carry bit
    assign full_result = a + b + cin;

    // Split the result into sum and cout
    assign sum  = full_result[3:0];
    assign cout = full_result[4];

endmodule
