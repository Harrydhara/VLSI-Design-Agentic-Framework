module adder8(
    input  [7:0] a,
    input  [7:0] b,
    input        cin,
    output [7:0] sum,
    output       cout
);

    // The 9-bit result is the concatenation of cout and sum.
    // We use a wire to hold the intermediate 9-bit calculation.
    wire [8:0] full_result;

    assign full_result = a + b + cin;
    
    assign sum  = full_result[7:0];
    assign cout = full_result[8];

endmodule
