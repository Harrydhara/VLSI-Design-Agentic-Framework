module tb;

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
                    total = total + 1;

                    // Calculate expected values using a larger bit width to avoid overflow in the testbench logic
                    // We use 5 bits to match {cout, sum}
                    if ({ (a + b + cin) >> 4 }, (a + b + cin) & 4'hF) !== {cout, sum} 
                        begin
                            // This is a bit tricky in Verilog syntax for comparison. 
                        end

                    // More robust check:
                    begin : check
                        reg [4:0] expected;
                        expected = a + b + cin;
                        if ({cout, sum} !== expected) begin
                            $display("FAIL: a=%d, b=%d, cin=%d | Expected {cout,sum}=%d, Got {cout,sum}=%d", 
                                     a, b, cin, expected, {cout, sum});
                        end else begin
                            passed = passed + 1;
                        end
                    end
                end
            end
        end

        // Specific corner cases (though exhaustive covers them)
        // Case: Max values
        a = 4'hF; b = 4'hF; cin = 1'b1;
        total = total + 1;
        if ({cout, sum} !== 5'd31) begin
             $display("FAIL: a=%d, b=%d, cin=%d | Expected {cout,sum}=31, Got %d", a, b, cin, {cout, sum});
        end else begin
             passed = passed + 1;
        end

        // Case: Zeroes
        a = 4'h0; b = 4'h0; cin = 1'b0;
        total = total + 1;
        if ({cout, sum} !== 5'd0) begin
             $display("FAIL: a=%d, b=%d, cin=%d | Expected {cout,sum}=0, Got %d", a, b, cin, {cout, sum});
        end else begin
             passed = passed + 1;
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
