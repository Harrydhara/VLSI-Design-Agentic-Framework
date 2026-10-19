module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // The requirement is purely combinational.
    // We use a 5-bit intermediate wire to capture the carry bit from the addition.
    wire [4:0] full_result;

    assign full_result = a + b + cin;
    assign sum  = full_result[3:0];
    assign cout = full_result[4];

endmodule
