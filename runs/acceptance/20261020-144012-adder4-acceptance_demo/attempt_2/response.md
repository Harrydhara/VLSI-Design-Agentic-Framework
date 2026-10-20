```verilog
// 4-bit binary adder with carry-in and carry-out
module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // The result of (a + b + cin) is 5 bits wide.
    // We assign the lower 4 bits to 'sum' and the MSB to 'cout'.
    assign {cout, sum} = a + b + cin;

endmodule
```

```verilog
`timescale 1ns/1ps

module tb();

    reg [3:0] a;
    reg [3:0] b;
    reg       cin;
    wire [3:0] sum;
    wire       cout;

    integer i, j, k;
    integer passed;
    integer total;
    reg [4:0] expected_full;

    adder4 uut (
        .a(a),
        .b(b),
        .cin(cin)
    );
    // Re-assigning wires to match the module port names correctly in instantiation if needed, 
    // but standard positional or named works. Using named:
    adder4 dut (
        .a(a),
        .b(b),
        .cin(cin),
        .sum(sum),
        .cout(cout)
    );

    initial begin
        passed = 0;
        total = 0;

        // Exhaustive testing of all input combinations
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                for (k = 0; k < 2; k = k + 1) begin
                    a = i[3:0];
                    b = j[3:0];
                    cin = k[0];
                    
                    total = total + 1;
                    expected_full = a + b + cin;

                    // Wait for combinational logic to settle (though in sim it's immediate)
                    #1;

                    if ({cout, sum} !== expected_full) begin
                        $display("FAIL: a=%d, b=%d, cin=%b | Expected={cout=%b, sum=%d}, Actual={cout=%b, sum=%d}", 
                                 a, b, cin, expected_full[4], expected_full[3:0], cout, sum);
                    end else begin
                        passed = passed + 1;
                    end
                end
            end
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```