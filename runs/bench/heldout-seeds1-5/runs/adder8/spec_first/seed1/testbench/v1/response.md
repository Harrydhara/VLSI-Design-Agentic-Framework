```verilog
module tb;
    // Inputs
    reg [7:0] a;
    reg [7:0] b;
    reg cin;

    // Outputs
    wire [7:0] sum;
    wire cout;

    // Integer for tracking results
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

        // Test Case 1: Exhaustive testing of all combinations
        // Since 8-bit + 8-bit + 1-bit is 9 bits, there are 2^8 * 2^8 * 2 = 2^17 combinations.
        // However, to keep simulation time reasonable for a testbench template while ensuring coverage,
        // we will iterate through all inputs using nested loops.
        
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                for (k = 0; k < 2; k = k + 1) begin
                    // Apply inputs
                    a = i;
                    b = j;
                    cin = k;

                    // Combinational delay simulation: 
                    // Since the DUT is purely combinational, we must wait for logic to settle.
                    #1;

                    // Reference Model Calculation
                    // {cout, sum} = a + b + cin
                    begin
                        reg [8:0] expected_full;
                        expected_full = a + b + cin;
                        
                        total = total + 1;

                        if ({cout, sum} !== expected_full) begin
                            $display("FAIL: a=%d, b=%d, cin=%b | Expected {cout,sum}=%d, Got {cout,sum}=%d", 
                                     a, b, cin, expected_full, {cout, sum});
                        end else begin
                            passed = passed + 1;
                        end
                    end
                end
            end
        end

        // Test Case 2: Specific Corner Cases (Redundant due to exhaustive loop but good for verification)
        // Max values
        a = 8'hFF; b = 8'hFF; cin = 1'b1; #1;
        total = total + 1;
        if ({cout, sum} !== 9'd511) begin
            $display("FAIL: a=%d, b=%d, cin=%b | Expected {cout,sum}=511, Got %d", a, b, cin, {cout, sum});
        end else passed = passed + 1;

        a = 8'hFF; b = 8'hFF; cin = 1'b0; #1;
        total = total + 1;
        if ({cout, sum} !== 9'd510) begin
            $display("FAIL: a=%d, b=%d, cin=%b | Expected {cout,sum}=510, Got %d", a, b, cin, {cout, sum});
        end else passed = passed + 1;

        a = 8'h00; b = 8'h00; cin = 1'b0; #1;
        total = total + 1;
        if ({cout, sum} !== 9'd0) begin
            $display("FAIL: a=%d, b=%d, cin=%b | Expected {cout,sum}=0, Got %d", a, b, cin, {cout, sum});
        end else passed = passed + 1;

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```