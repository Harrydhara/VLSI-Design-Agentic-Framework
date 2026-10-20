module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // The specification requires {cout, sum} = a + b + cin.
    // Since it is purely combinational, we use an assign statement.
    assign {cout, sum} = a + b + cin;

endmodule
