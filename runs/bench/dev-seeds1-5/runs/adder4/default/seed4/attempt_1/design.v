module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // The specification requires {cout, sum} = a + b + cin.
    // Since it is purely combinational and no clock is provided in the header,
    // we use continuous assignment to implement the 4-bit addition logic.
    
    assign {cout, sum} = a + b + cin;

endmodule
