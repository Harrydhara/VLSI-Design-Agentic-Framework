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

        // Exhaustive testing of all possible input combinations
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                for (k = 0; k < 2; k = k + 1) begin
                    a = i[3:0];
                    b = j[3:0];
                    cin = k[0];
                    
                    total = total + 1;
                    expected_full = a + b + cin;
                    actual_full = {cout, sum};

                    if (actual_full !== expected_full) begin
                        $display("FAIL: a=%d, b=%d, cin=%d | Expected={cout=%b, sum=%b}(%d), Actual={cout=%b, sum=%b}(%d)", 
                                 a, b, cin, cout, sum, expected_full, cout, sum, actual_full);
                    end else begin
                        passed = passed + 1;
                    end
                end
            end
        end

        // Specific Corner Cases (redundant due to exhaustive test but good practice)
        // Case: All zeros
        a = 4'd0; b = 4'd0; cin = 1'b0; #1;
        total = total + 1;
        expected_full = 5'd0; actual_full = {cout, sum};
        if (actual_full !== expected_full) begin
            $display("FAIL: a=%d, b=%d, cin=%d | Expected=%d, Actual=%d", a, b, cin, expected_full, actual_full);
        end else passed = passed + 1;

        // Case: All ones (Max value)
        a = 4'hf; b = 4'hf; cin = 1'b1; #1;
        total = total + 1;
        expected_full = 5'd31; actual_full = {cout, sum};
        if (actual_full !== expected_full) begin
            $display("FAIL: a=%d, b=%d, cin=%d | Expected=%d, Actual=%d", a, b, cin, expected_full, actual_full);
        end else passed = passed + 1;

        // Case: Max sum without carry-out (15+15+0 = 30)
        a = 4'hf; b = 4'hf; cin = 1'b0; #1;
        total = total + 1;
        expected_full = 5'd30; actual_full = {cout, sum};
        if (actual_full !== expected_full) begin
            $display("FAIL: a=%d, b=%d, cin=%d | Expected=%d, Actual=%d", a, b, cin, expected_full, actual_full);
        end else passed = passed + 1;

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
