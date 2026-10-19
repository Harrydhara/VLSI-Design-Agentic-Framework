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

        // Test Case 1: Exhaustive testing of all combinations
        // Since it's an 8-bit adder, there are 2^8 * 2^8 * 2 = 2^17 combinations.
        // 2^17 = 131,072. This is small enough for a simulation to handle quickly.
        
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                for (k = 0; k < 2; k = k + 1) begin
                    // Apply inputs
                    a = i;
                    b = j;
                    cin = k;

                    // Calculate expected value using reference model
                    expected_result = a + b + cin;

                    // Wait for combinational logic to settle (not strictly necessary in sim, but good practice)
                    #1;

                    // Capture actual result
                    actual_result = {cout, sum};

                    total = total + 1;

                    if (actual_result !== expected_result) begin
                        $display("FAIL: a=%d, b=%d, cin=%b | Expected={cout=%b, sum=%d}=%d, Actual={cout=%b, sum=%d}=%d", 
                                 a, b, cin, 
                                 expected_result[8], expected_result[7:0], expected_result,
                                 cout, sum, actual_result);
                    end else begin
                        passed = passed + 1;
                    end
                end
            end
        end

        // Specific Corner Cases (redundant due to exhaustive test, but good for clarity)
        // Zeroes
        check_case(8'h00, 8'h00, 1'b0);
        // Max values
        check_case(8'hFF, 8'hFF, 1'b1);
        // Carry-in only
        check_case(8'h00, 8'h00, 1'b1);
        // One bit below overflow
        check_case(8'hFF, 8'h00, 1'b0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    // Task to handle specific corner case checks if needed manually
    task check_case(input [7:0] ta, input [7:0] tb_val, input tcin);
        reg [8:0] exp;
        begin
            a = ta;
            b = tb_val;
            cin = tcin;
            exp = ta + tb_val + tcin;
            #1;
            total = total + 1;
            if ({cout, sum} !== exp) begin
                $display("FAIL: a=%d, b=%d, cin=%b | Expected=%d, Actual=%d", ta, tb_val, tcin, exp, {cout, sum});
            end else begin
                passed = passed + 1;
            end
        end
    endtask

endmodule
```