module tb;

    reg [3:0] a;
    reg [3:0] b;
    reg       cin;
    wire [3:0] sum;
    wire       cout;

    integer i, j, k;
    integer passed;
    integer total;
    reg [4:0] expected;

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
                    a = i[3:0];
                    b = j[3:0];
                    cin = k[0];
                    total = total + 1;
                    
                    expected = a + b + cin;

                    // Wait for combinational logic to settle (not strictly needed in sim, but good practice)
                    #1;

                    if ({cout, sum} !== expected) begin
                        $display("FAIL: a=%d, b=%d, cin=%d | Expected {cout,sum}=%d, Got %d", 
                                 a, b, cin, expected, {cout, sum});
                    end else begin
                        passed = passed + 1;
                    end
                end
            end
        end

        // Specific corner cases (redundant due to exhaustive loop but included for completeness)
        // Case: Max values
        a = 4'hF; b = 4'hF; cin = 1'b1;
        total = total + 1;
        #1;
        expected = 5'd31;
        if ({cout, sum} !== expected) begin
             $display("FAIL: a=%d, b=%d, cin=%d | Expected {cout,sum}=%d, Got %d", a, b, cin, expected, {cout, sum});
        end else begin
             passed = passed + 1;
        end

        // Case: Zeroes
        a = 4'h0; b = 4'h0; cin = 1'b0;
        total = total + 1;
        #1;
        expected = 5'd0;
        if ({cout, sum} !== expected) begin
             $display("FAIL: a=%d, b=%d, cin=%d | Expected {cout,sum}=%d, Got %d", a, b, cin, expected, {cout, sum});
        end else begin
             passed = passed + 1;
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
