```verilog
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
```

```verilog
module tb;

    reg [3:0] a;
    reg [3:0] b;
    reg       cin;
    wire [3:0] sum;
    wire       cout;

    integer i, j, k;
    integer passed;
    integer total;
    reg [4:0] expected_full;
    reg [4:0] actual_full;

    adder4 uut (
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
                    // Apply inputs
                    a = i[3:0];
                    b = j[3:0];
                    cin = k[0];
                    
                    // Calculate expected result using 5-bit arithmetic to capture carry
                    expected_full = a + b + cin;
                    
                    // Wait for combinational logic to settle (not strictly needed in sim, but good practice)
                    #1;

                    // Capture actual result
                    actual_full = {cout, sum};

                    total = total + 1;
                    if (actual_full === expected_full) begin
                        passed = passed + 1;
                    end else begin
                        $display("FAIL: a=%d, b=%d, cin=%d | Expected={cout=%b, sum=%b} (%d), Actual={cout=%b, sum=%b} (%d)",
                                 a, b, cin, cout, sum, expected_full, cout, sum, actual_full);
                    end
                end
            end
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```