```verilog
module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // The result of a 4-bit addition with carry-in can be up to 5 bits.
    // We concatenate cout and sum to represent the full arithmetic result.
    assign {cout, sum} = a + b + cin;

endmodule
```