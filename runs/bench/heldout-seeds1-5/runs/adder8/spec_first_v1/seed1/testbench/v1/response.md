```verilog
module tb;
    // Inputs
    reg [7:0] a;
    reg [7:0] b;
    reg cin;

    // Outputs
    wire [7:0] sum;
    wire cout;

    // Instantiate the design under test
    adder8 dut (
        .a(a),
        .b(b),
        .cin(cin),
        .sum(sum),
        .cout(cout)
    );

    // Verification variables
    integer i, j, k;
    reg [8:0] expected_full;
    reg [8:0] actual_full;
    integer passed;
    integer total;

    initial begin
        passed = 0;
        total = 0;

        // Test all combinations of a, b, and cin
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                for (k = 0; k < 2; k = k + 1) begin
                    // Apply inputs
                    a = i;
                    b = j;
                    cin = k;

                    // Reference Model: {cout, sum} = a + b + cin
                    expected_full = a + b + cin;

                    // Wait for combinational logic to settle
                    #1;

                    // Capture actual output
                    actual_full = {cout, sum};

                    total = total + 1;
                    if (actual_full === expected_full) begin
                        passed = passed + 1;
                    end else begin
                        $display("FAIL: a=%d, b=%d, cin=%b | Expected={cout=%b, sum=%d} (%d), Actual={cout=%b, sum=%d} (%d)",
                                 a, b, cin, cout, sum, expected_full, cout, sum, actual_full);
                    end
                end
            end
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```