`timescale 1ns/1ps
module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // Using concatenation to perform the addition in one step.
    // The result of (a + b + cin) is 5 bits wide.
    // We assign the lower 4 bits to 'sum' and the MSB to 'cout'.
    assign {cout, sum} = a + b + cin;

endmodule
