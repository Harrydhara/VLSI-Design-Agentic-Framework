module tb();

    reg [3:0] a;
    reg [3:0] b;
    reg       cin;
    wire [3:0] sum;
    wire       cout;

    integer i, j, k;
    integer passed;
    integer total;
    reg [4:0] expected;
    reg [4:0] actual;

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

        // Exhaustive testing of all input combinations (2^4 * 2^4 * 2^1 = 512 cases)
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                for (k = 0; k < 2; k = k + 1) begin
                    a = i;
                    b = j;
                    cin = k;
                    
                    // Calculate expected result using a 5-bit temporary variable
                    expected = a + b + cin;
                    
                    // Wait for combinational logic to settle (not strictly needed in sim, but good practice)
                    #1;
                    
                    actual = {cout, sum};
                    total = total + 1;

                    if (actual === expected) begin
                        passed = passed + 1;
                    end else begin
                        $display("FAIL: a=%d, b=%d, cin=%b | Expected={cout,sum}=%d, Actual=%d", 
                                 a, b, cin, expected, actual);
                    end
                end
            end
        end

        // Specific corner cases check (redundant due to exhaustive loop but good for clarity)
        // Case: Max values
        a = 4'hF; b = 4'hF; cin = 1'b1; #1;
        expected = 5'd31;
        actual = {cout, sum};
        total = total + 1;
        if (actual === expected) passed = passed + 1;
        else $display("FAIL: a=%d, b=%d, cin=%b | Expected=%d, Actual=%d", a, b, cin, expected, actual);

        // Case: Zeroes
        a = 4'h0; b = 4'h0; cin = 1'b0; #1;
        expected = 5'd0;
        actual = {cout, sum};
        total = total + 1;
        if (actual === expected) passed = passed + 1;
        else $display("FAIL: a=%d, b=%d, cin=%b | Expected=%d, Actual=%d", a, b, cin, expected, actual);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
