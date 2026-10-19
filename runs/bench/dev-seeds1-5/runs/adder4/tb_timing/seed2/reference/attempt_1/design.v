module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // The 5-bit result of the addition including carry-in
    wire [4:0] full_result;

    // Perform the addition
    assign full_result = a + b + cin;

    // Split the result into cout and sum
    assign cout = full_result[4];
    assign sum  = full_result[3:0];

endmodule
