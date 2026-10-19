module tb();

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
                    
                    total = total + 1;

                    // Calculate expected result
                    expected_full = a + b + cin;
                    
                    // Wait for combinational logic to settle (not needed in sim but good practice)
                    #1;

                    // Capture actual result
                    actual_full = {cout, sum};

                    if (actual_full === expected_full) begin
                        passed = passed + 1;
                    end else begin
                        $display("FAIL: a=%d, b=%d, cin=%b | Expected %d, Got %d", 
                                 a, b, cin, expected_full, actual_full);
                    end
                end
            end
        end

        // Corner cases (redundant due to exhaustive test but good for coverage)
        // Case: Max values
        a = 4'hF; b = 4'hF; cin = 1'b1;
        #1;
        total = total + 1;
        expected_full = 5'd31;
        actual_full = {cout, sum};
        if (actual_full === expected_full) passed = passed + 1;
        else begin
            $display("FAIL: a=%d, b=%d, cin=%b | Expected %d, Got %d", a, b, cin, expected_full, actual_full);
        end

        // Case: All zeros
        a = 4'h0; b = 4'h0; cin = 1'b0;
        #1;
        total = total + 1;
        expected_full = 5'd0;
        actual_full = {cout, sum};
        if (actual_full === expected_full) passed = passed + 1;
        else begin
            $display("FAIL: a=%d, b=%d, cin=%b | Expected %d, Got %d", a, b, cin, expected_full, actual_full);
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
