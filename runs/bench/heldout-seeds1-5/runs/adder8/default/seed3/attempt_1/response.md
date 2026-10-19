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
                    
                    expected_full = a + b + cin;
                    actual_full = {cout, sum};

                    if (actual_full !== expected_full) begin
                        $display("FAIL: a=%d, b=%d, cin=%b | Expected %d, Got %d", a, b, cin, expected_full, actual_full);
                    end else begin
                        passed = passed + 1;
                    end
                end
            end
        end

        // Test Case 2: Corner cases (Max values)
        // Max sum: 255 + 255 + 1 = 511
        a = 8'hFF; b = 8'hFF; cin = 1'b1;
        total = total + 1;
        expected_full = 9'd511;
        actual_full = {cout, sum};
        if (actual_full !== expected_full) begin
            $display("FAIL: a=%h, b=%h, cin=%b | Expected %d, Got %d", a, b, cin, expected_full, actual_full);
        end else begin
            passed = passed + 1;
        end

        // Max sum without carry-in: 255 + 255 + 0 = 510
        a = 8'hFF; b = 8'hFF; cin = 1'b0;
        total = total + 1;
        expected_full = 9'd510;
        actual_full = {cout, sum};
        if (actual_full !== expected_full) begin
            $display("FAIL: a=%h, b=%h, cin=%b | Expected %d, Got %d", a, b, cin, expected_full, actual_full);
        end else begin
            passed = passed + 1;
        end

        // Zero case
        a = 8'h00; b = 8'h00; cin = 1'b0;
        total = total + 1;
        expected_full = 9'd0;
        actual_full = {cout, sum};
        if (actual_full !== expected_full) begin
            $display("FAIL: a=%h, b=%h, cin=%b | Expected %d, Got %d", a, b, cin, expected_full, actual_full);
        end else begin
            passed = passed + 1;
        end

        // Boundary case for carry-out transition
        a = 8'h80; b = 8'h80; cin = 1'b0; // 128+128 = 256 (cout=1, sum=0)
        total = total + 1;
        expected_full = 9'd256;
        actual_full = {cout, sum};
        if (actual_full !== expected_full) begin
            $display("FAIL: a=%h, b=%h, cin=%b | Expected %d, Got %d", a, b, cin, expected_full, actual_full);
        end else begin
            passed = passed + 1;
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```