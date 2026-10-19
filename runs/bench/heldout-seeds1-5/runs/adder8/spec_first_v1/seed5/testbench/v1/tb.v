module tb;
    // Inputs
    reg [7:0] a;
    reg [7:0] b;
    reg cin;

    // Outputs
    wire [7:0] sum;
    wire cout;

    // Internal variables for verification
    reg [8:0] expected_result;
    reg [7:0] expected_sum;
    reg       expected_cout;
    integer i, j, k;
    integer passed;
    integer total;

    // Instantiate the Design Under Test (DUT)
    adder8 dut (
        .a(a),
        .b(b),
        .cin(cin),
        .sum(sum),
        .cout(cout)
    );

    initial begin
        passed = 0;
        total = 0;

        // Test Case 1: Exhaustive testing of a small subset to ensure correctness
        // We will iterate through all combinations of a, b, and cin if possible,
        // but for an 8-bit adder (2^8 * 2^8 * 2 = 131072 combinations), 
        // we can perform the full sweep in a reasonable simulation time.

        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                for (k = 0; k < 2; k = k + 1) begin
                    // Apply inputs
                    a = i;
                    b = j;
                    cin = k;

                    // Reference Model Calculation
                    expected_result = i + j + k;
                    expected_sum = expected_result[7:0];
                    expected_cout = expected_result[8];

                    // Wait for combinational logic to settle
                    #1;

                    total = total + 1;

                    // Check outputs
                    if (sum !== expected_sum || cout !== expected_cout) begin
                        $display("FAIL: a=%d, b=%d, cin=%b | Expected sum=%d, cout=%b | Actual sum=%d, cout=%b",
                                 a, b, cin, expected_sum, expected_cout, sum, cout);
                    end else begin
                        passed = passed + 1;
                    end
                end
            end
        end

        // Test Case 2: Specific Corner Cases (Redundant due to exhaustive sweep, but good for clarity)
        // Zeroes
        a = 8'd0; b = 8'd0; cin = 1'b0; #1;
        total = total + 1;
        if (sum !== 8'd0 || cout !== 1'b0) begin
            $display("FAIL: a=%d, b=%d, cin=%b | Expected sum=0, cout=0 | Actual sum=%d, cout=%b", a, b, cin, sum, cout);
        end else passed = passed + 1;

        // Max values with carry
        a = 8'hFF; b = 8'hFF; cin = 1'b1; #1;
        total = total + 1;
        if (sum !== 8'hFF || cout !== 1'b1) begin
            $display("FAIL: a=%d, b=%d, cin=%b | Expected sum=255, cout=1 | Actual sum=%d, cout=%b", a, b, cin, sum, cout);
        end else passed = passed + 1;

        // Max values without carry-in
        a = 8'hFF; b = 8'hFF; cin = 1'b0; #1;
        total = total + 1;
        if (sum !== 8'hFE || cout !== 1'b1) begin
            $display("FAIL: a=%d, b=%d, cin=%b | Expected sum=254, cout=1 | Actual sum=%d, cout=%b", a, b, cin, sum, cout);
        end else passed = passed + 1;

        // Final Summary
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
