module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // Combinational 4-bit adder using concatenation to capture the carry out.
    // The expression {cout, sum} = a + b + cin performs the addition
    // and automatically handles the overflow into the cout bit.
    assign {cout, sum} = a + b + cin;

endmodule
