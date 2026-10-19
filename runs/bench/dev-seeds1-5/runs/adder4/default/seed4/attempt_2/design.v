module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // Combinational 4-bit addition with carry-in and carry-out.
    // {cout, sum} represents the full 5-bit result of a + b + cin.
    assign {cout, sum} = a + b + cin;

endmodule
