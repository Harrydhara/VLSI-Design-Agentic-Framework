module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // The requirement is {cout, sum} = a + b + cin.
    // Since it's purely combinational, we can use the concatenation operator 
    // with an arithmetic addition to let the synthesizer infer the adder logic.
    assign {cout, sum} = a + b + cin;

endmodule
