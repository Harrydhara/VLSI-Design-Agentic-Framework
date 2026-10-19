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

        // Test Case 1: Exhaustive testing of all combinations (2^8 * 2^8 * 2^1 is too large for a quick TB, 
        // but we can cover significant corner cases and patterns)
        
        // We will iterate through specific patterns to ensure coverage
        // Pattern A: All zeros
        check_addition(8'h00, 8'h00, 1'b0);
        
        // Pattern B: Max values with cin=0 (Overflow check)
        check_addition(8'hFF, 8'h00, 1'b0);
        check_addition(8'hFF, 8'h01, 1'b0); // cout should be 1
        
        // Pattern C: Max values with cin=1 (Overflow check)
        check_addition(8'hFF, 8'hFF, 1'b0);
        check_addition(8'hFF, 8'hFF, 1'b1); // cout should be 1, sum 0xFF
        
        // Pattern D: Random sampling to catch logic errors
        for (i = 0; i < 500; i = i + 1) begin
            check_addition($random % 256, $random % 256, $random % 2);
        end

        // Pattern E: Boundary transitions
        check_addition(8'h7F, 8'h01, 1'b0); // Midpoint
        check_addition(8'h80, 8'h80, 1'b0); // MSB set
        check_addition(8'h80, 8'h7F, 1'b1); // Boundary

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
                $display("FAIL: a=%d b=%d cin=%b | Expected {cout,sum}=%d, Got {cout,sum}=%d", 
                         t_a, t_b, t_cin, expected_result, actual_result);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

endmodule
