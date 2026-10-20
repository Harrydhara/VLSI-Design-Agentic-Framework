`timescale 1ns/1ps
module tb();

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
                    a = i[3:0];
                    b = j[3:0];
                    cin = k[0];
                    
                    total = total + 1;
                    
                    // Calculate expected values using a larger bit width to prevent overflow in testbench logic
                    // We use 5 bits because max value is 15+15+1 = 31.
                    if ({1'b0, a} + {1'b0, b} + {1'b0, cin}) !== ({cout, sum}) then begin
                        // This block shouldn't be reachable if logic is correct, but we use it for verification
                    end

                    // Manual calculation of expected result
                    // We use a 5-bit temporary variable to hold the truth
                    begin : check_logic
                        reg [4:0] expected;
                        expected = a + b + cin;
                        if ({cout, sum} !== expected) begin
                            $display("FAIL: a=%d, b=%d, cin=%b | Expected={cout=%b, sum=%d}, Actual={cout=%b, sum=%d}", 
                                     a, b, cin, expected[4], expected[3:0], cout, sum);
                        end else begin
                            passed = passed + 1;
                        end
                    end
                end
            end
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
