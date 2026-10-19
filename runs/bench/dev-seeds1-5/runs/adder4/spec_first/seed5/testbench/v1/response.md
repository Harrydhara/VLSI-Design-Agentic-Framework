```verilog
module tb;
    // Inputs
    reg [3:0] a;
    reg [3:0] b;
    reg cin;

    // Outputs
    wire [3:0] sum;
    wire cout;

    // Instantiate the Unit Under Test (UUT)
    adder4 uut (
        .a(a),
        .b(b),
        .cin(cin),
        .sum(sum),
        .cout(cout)
    );

    // Verification variables
    integer i, j, k;
    reg [4:0] expected_full;
    reg [3:0] expected_sum;
    reg expected_cout;
    integer passed;
    integer total;

    initial begin
        passed = 0;
        total = 0;

        // Iterate through all possible input combinations
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                for (k = 0; k < 2; k = k + 1) begin
                    // Apply inputs
                    a = i;
                    b = j;
                    cin = k;
                    
                    // Wait for combinational logic to settle
                    #1;

                    // Reference Model calculation
                    expected_full = a + b + cin;
                    expected_sum = expected_full[3:0];
                    expected_cout = expected_full[4];

                    // Increment total checks
                    total = total + 1;

                    // Check outputs
                    if (sum === expected_sum && cout === expected_cout) begin
                        passed = passed + 1;
                    end else begin
                        $display("FAIL: a=%d, b=%d, cin=%b | Expected sum=%d, cout=%b | Actual sum=%d, cout=%b",
                                 a, b, cin, expected_sum, expected_cout, sum, cout);
                    end
                end
            end
        end

        // Final Summary
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```