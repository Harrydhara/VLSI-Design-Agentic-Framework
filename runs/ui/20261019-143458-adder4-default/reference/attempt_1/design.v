module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // The specification requires {cout, sum} = a + b + cin.
    // Since it is purely combinational, we use an assign statement.
    // Verilog handles the concatenation and bit-width expansion automatically 
    // when performing addition if the target width is sufficient.
    assign {cout, sum} = a + b + cin;

endmodule
