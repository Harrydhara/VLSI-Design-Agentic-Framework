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

    // Perform the addition using concatenation to capture the carry bit
    assign full_result = a + b + cin;

    // Split the result into sum and cout
    assign sum  = full_result[3:0];
    assign cout = full_result[4];

endmodule
```

```verilog
module tb;
    reg [3:0] a;
    reg [3:0] b;
    reg       cin;
    wire [3:0] sum;
    wire       cout;

    integer passed = 0;
    integer total = 0;

    // Reference model values
    reg [4:0] model_res;

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
            if ({cout, sum} === model_res) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: a=%d b=%d cin=%b expected=%d actual=%d", 
                         a, b, cin, model_res, {cout, sum});
            end
        end
    endtask

    initial begin
        // Initialize inputs
        a = 0; b = 0; cin = 0;
        
        // Test Case 1: Zeroes
        a = 4'd0; b = 4'd0; cin = 1'b0;
        model_res = 5'd0;
        #1; check;

        // Test Case 2: Simple addition
        a = 4'd5; b = 4'd3; cin = 1'b0;
        model_res = 5'd8;
        #1; check;

        // Test Case 3: Addition with carry-in
        a = 4'd5; b = 4'd3; cin = 1'b1;
        model_res = 5'd9;
        #1; check;

        // Test Case 4: Max values (no overflow)
        a = 4'd7; b = 4'd8; cin = 1'b0;
        model_res = 5'd15;
        #1; check;

        // Test Case 5: Overflow (cout=1)
        a = 4'd15; b = 4'd0; cin = 1'b1;
        model_res = 5'd16;
        #1; check;

        // Test Case 6: Max overflow
        a = 4'd15; b = 4'd15; cin = 1'b1;
        model_res = 5'd31;
        #1; check;

        // Test Case 7: Boundary carry-out
        a = 4'd10; b = 4'd6; cin = 1'b0;
        model_res = 5'd16;
        #1; check;

        // Test Case 8: All ones except cin
        a = 4'hf; b = 4'hf; cin = 1'b0;
        model_res = 5'd30;
        #1; check;

        // Test Case 9: Random pattern
        a = 4'd2; b = 4'd4; cin = 1'b1;
        model_res = 5'd7;
        #1; check;

        // Test Case 10: Single bit carry
        a = 4'b0001; b = 4'b0001; cin = 1'b1;
        model_res = 5'd3;
        #1; check;

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```