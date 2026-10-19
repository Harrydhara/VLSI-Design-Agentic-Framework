```verilog
module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // The requirement is purely combinational.
    // We can implement this using the concatenation operator 
    // to capture the full 5-bit result of the addition.
    
    wire [4:0] full_result;

    assign full_result = a + b + cin;
    assign sum  = full_result[3:0];
    assign cout = full_result[4];

endmodule
```

```verilog
module tb();

    reg [3:0] a;
    reg [3:0] b;
    reg       cin;
    wire [3:0] sum;
    wire       cout;

    integer i, j, k;
    integer passed;
    integer total;

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
                    a = i;
                    b = j;
                    cin = k;
                    
                    // Calculate expected values using a larger bit-width to avoid overflow in testbench logic
                    // We use 5 bits because max value is 15 + 15 + 1 = 31.
                    begin : check
                        reg [4:0] expected_full;
                        reg [3:0] expected_sum;
                        reg       expected_cout;
                        
                        expected_full = a + b + cin;
                        expected_sum  = expected_full[3:0];
                        expected_cout = expected_full[4];
                        
                        total = total + 1;
                        
                        if (sum === expected_sum && cout === expected_cout) begin
                            passed = passed + 1;
                        end else begin
                            $display("FAIL: a=%d, b=%d, cin=%d | Expected sum=%d, cout=%b | Actual sum=%d, cout=%b",
                                     a, b, cin, expected_sum, expected_cout, sum, cout);
                        end
                    end
                end
            end
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```