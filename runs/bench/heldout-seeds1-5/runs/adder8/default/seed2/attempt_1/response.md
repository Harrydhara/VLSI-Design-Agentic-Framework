```verilog
module adder8(
    input  [7:0] a,
    input  [7:0] b,
    input        cin,
    output [7:0] sum,
    output       cout
);

    // The 9-bit result is the concatenation of cout and sum.
    // We perform the addition using a 9-bit intermediate value to capture the carry.
    assign {cout, sum} = a + b + cin;

endmodule
```

```verilog
module tb;

    reg [7:0] a;
    reg [7:0] b;
    reg       cin;
    wire [7:0] sum;
    wire       cout;

    integer i, j, k;
    integer passed;
    integer total;
    reg [8:0] expected_full;
    reg [8:0] actual_full;

    adder8 uut (
        .a(a),
        .b(b),
        .cin(cin),
        .sum(sum),
        .cout(cout)
    );

    initial begin
        passed = 0;
        total = 0;

        // Test Case 1: Exhaustive search for small values (to ensure basic logic)
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                for (k = 0; k < 2; k = k + 1) begin
                    a = i;
                    b = j;
                    cin = k;
                    total = total + 1;
                    check_result();
                end
            end
        end

        // Test Case 2: Corner cases (Max values and carry transitions)
        // Max a, b, cin
        a = 8'hFF; b = 8'hFF; cin = 1'b1;
        total = total + 1;
        check_result();

        // Max a, b, cin=0
        a = 8'hFF; b = 8'hFF; cin = 1'b0;
        total = total + 1;
        check_result();

        // Zeroes
        a = 8'h00; b = 8'h00; cin = 1'b0;
        total = total + 1;
        check_result();

        // Single bit transitions
        a = 8'h01; b = 8'h01; cin = 1'b0;
        total = total + 1;
        check_result();

        a = 8'h80; b = 8'h80; cin = 1'b0;
        total = total + 1;
        check_result();

        // Random patterns to increase coverage
        for (i = 0; i < 50; i = i + 1) begin
            a = $random;
            b = $random;
            cin = $random % 2;
            total = total + 1;
            check_result();
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    task check_result;
        begin
            expected_full = a + b + cin;
            actual_full = {cout, sum};
            if (expected_full === actual_full) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: a=%d, b=%d, cin=%b | Expected={cout=%b, sum=%d}, Actual={cout=%b, sum=%d}", 
                         a, b, cin, $cout(expected_full[8]), expected_full[7:0], cout, sum);
                // Note: Using custom logic for display because $display doesn't support bit-field concatenation easily in all simulators
                $display("FAIL: a=%d, b=%d, cin=%b | Expected %d, Actual %d", 
                         a, b, cin, expected_full, actual_full);
            end
        end
    endtask

endmodule
```