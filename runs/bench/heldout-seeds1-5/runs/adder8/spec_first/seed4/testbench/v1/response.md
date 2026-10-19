```verilog
module tb;
    // Inputs
    reg [7:0] a;
    reg [7:0] b;
    reg cin;

    // Outputs
    wire [7:0] sum;
    wire cout;

    // DUT instantiation
    adder8 dut (
        .a(a),
        .b(b),
        .cin(cin),
        .sum(sum),
        .cout(cout)
    );

    // Verification variables
    integer i, j, k;
    reg [8:0] expected_result;
    reg [8:0] actual_result;
    integer passed;
    integer total;

    initial begin
        passed = 0;
        total = 0;

        // Test Case 1: Exhaustive testing of all combinations (2^8 * 2^8 * 2^1 is too large, 
        // so we will use a representative set of corner cases and random samples)
        
        // Corner Cases: Zeros, Max values, Carry transitions
        // We'll iterate through specific patterns to ensure coverage.
        
        // Pattern 1: All zeros
        check_addition(8'h00, 8'h00, 1'b0);
        // Pattern 2: Max values with cin=0 (Overflow)
        check_addition(8'hFF, 8'h00, 1'b0);
        check_addition(8'hFF, 8'hFF, 1'b0);
        // Pattern 3: Max values with cin=1 (Max overflow)
        check_addition(8'hFF, 8'hFF, 1'b1);
        // Pattern 4: Boundary around 255
        check_addition(8'hFE, 8'h01, 1'b0);
        check_addition(8'hFE, 8'h01, 1'b1);
        // Pattern 5: Single bit transitions
        check_addition(8'h01, 8'h01, 1'b0);
        check_addition(8'h80, 8'h80, 1'b0);
        check_addition(8'h80, 8'h7F, 1'b0);
        check_addition(8'h80, 8'h7F, 1'b1);

        // Pattern 6: Random sampling for robustness
        for (i = 0; i < 500; i = i + 1) begin
            check_addition($random % 256, $random % 256, $random % 2);
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    task check_addition;
        input [7:0] t_a;
        input [7:0] t_b;
        input       t_cin;
        begin
            total = total + 1;
            a = t_a;
            b = t_b;
            cin = t_cin;

            // Since it's combinational, we use a small delay to allow propagation
            #1;

            expected_result = t_a + t_b + t_cin;
            actual_result = {cout, sum};

            if (actual_result !== expected_result) begin
                $display("FAIL: a=%d, b=%d, cin=%b | Expected {%b, %d} (%d), Actual {%b, %d} (%d)", 
                         t_a, t_b, t_cin, cout, sum, expected_result, cout, sum, actual_result);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

endmodule
```