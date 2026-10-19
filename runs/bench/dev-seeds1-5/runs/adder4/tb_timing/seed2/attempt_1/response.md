```verilog
module adder4(
    input  [3:0] a,
    input  [3:0] b,
    input        cin,
    output [3:0] sum,
    output       cout
);

    // The 5-bit result of the addition including carry-in
    wire [4:0] full_result;

    // Perform the addition
    assign full_result = a + b + cin;

    // Split the result into cout and sum
    assign cout = full_result[4];
    assign sum  = full_result[3:0];

endmodule
```

```verilog
module tb;
    reg [3:0] a;
    reg [3:0] b;
    reg       cin;
    wire [3:0] sum;
    wire       cout;

    integer passed;
    integer total;

    // Reference model values
    reg [4:0] model_result;

    adder4 dut (
        .a(a),
        .b(b),
        .cin(cin),
        .sum(sum),
        .cout(cout)
    );

    task check;
        begin
            total = total + 1;
            if ({cout, sum} === model_result) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d a=%0d b=%0d cin=%b expected={cout,sum}=%b actual={cout,sum}=%b", 
                         $time, a, b, cin, model_result, {cout, sum});
            end
        end
    endtask

    initial begin
        // Initialize
        a = 0;
        b = 0;
        cin = 0;
        passed = 0;
        total = 0;
        model_result = 0;

        // Test Case 1: Zeroes
        a = 4'd0; b = 4'd0; cin = 1'b0;
        model_result = a + b + cin;
        #1;
        check;

        // Test Case 2: Simple addition without carry
        a = 4'd2; b = 4'd3; cin = 1'b0;
        model_result = a + b + cin;
        #1;
        check;

        // Test Case 3: Addition with cin
        a = 4'd5; b = 4'd2; cin = 1'b1;
        model_result = a + b + cin;
        #1;
        check;

        // Test Case 4: Max values (overflow)
        a = 4'hf; b = 4'hf; cin = 1'b1;
        model_result = a + b + cin; // 15+15+1 = 31 (5'b11111)
        #1;
        check;

        // Test Case 5: Max values (no cin)
        a = 4'hf; b = 4'hf; cin = 1'b0;
        model_result = a + b + cin; // 30 (5'b11110)
        #1;
        check;

        // Test Case 6: Boundary carry out
        a = 4'h8; b = 4'h8; cin = 1'b0;
        model_result = a + b + cin; // 16 (5'b10000)
        #1;
        check;

        // Test Case 7: All ones sum
        a = 4'h7; b = 4'h8; cin = 1'b0;
        model_result = a + b + cin; // 15 (5'b01111)
        #1;
        check;

        // Test Case 8: Random pattern
        a = 4'd10; b = 4'd3; cin = 1'b1;
        model_result = a + b + cin; // 14 (5'b01110)
        #1;
        check;

        // Test Case 9: Carry out check
        a = 4'd12; b = 4'd5; cin = 1'b0;
        model_result = a + b + cin; // 17 (5'b10001)
        #1;
        check;

        // Test Case 10: Full range sweep
        begin : sweep
            integer i, j, k;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    for (k = 0; k < 2; k = k + 1) begin
                        a = i; b = j; cin = k;
                        model_result = i + j + k;
                        #1;
                        check;
                    end
                end
            end
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```