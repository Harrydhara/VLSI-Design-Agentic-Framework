```verilog
module adder8(
    input  [7:0] a,
    input  [7:0] b,
    input        cin,
    output [7:0] sum,
    output       cout
);

    // The 9-bit result is the concatenation of cout and sum.
    // We use a wire to hold the intermediate 9-bit calculation.
    wire [8:0] full_result;

    assign full_result = a + b + cin;
    
    assign sum  = full_result[7:0];
    assign cout = full_result[8];

endmodule
```

```verilog
module tb;
    reg [7:0] a;
    reg [7:0] b;
    reg       cin;
    wire [7:0] sum;
    wire       cout;

    integer passed = 0;
    integer total = 0;

    // Reference model for the expected values
    reg [8:0] model;

    adder8 dut (
        .a(a),
        .b(b),
        .cin(cin),
        .sum(sum),
        .cout(cout)
    );

    task check;
        begin
            total = total + 1;
            if ({cout, sum} === model) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d a=%0d b=%0d cin=%b expected_sum=%0d expected_cout=%b actual_sum=%0d actual_cout=%b", 
                         $time, a, b, cin, model[7:0], model[8], sum, cout);
            end
        end
    endtask

    task test_case(input [7:0] va, input [7:0] vb, input vcin);
        begin
            a = va;
            b = vb;
            cin = vcin;
            model = va + vb + vcin;
            #1; // Wait for combinational logic to settle
            check;
        end
    endtask

    initial begin
        // Initialize inputs
        a = 0; b = 0; cin = 0; model = 0;

        // Corner Case: All zeros
        test_case(8'd0, 8'd0, 1'b0);

        // Corner Case: Max values without overflow
        test_case(8'd127, 8'd127, 1'b0);

        // Corner Case: cin only
        test_case(8'd0, 8'd0, 1'b1);

        // Corner Case: a + b = 255 (no cout)
        test_case(8'd200, 8'd55, 1'b0);

        // Corner Case: a + b + cin = 256 (cout=1, sum=0)
        test_case(8'd255, 8'd0, 1'b1);
        test_case(8'd128, 8'd127, 1'b1);

        // Corner Case: a + b = 256 (cout=1, sum=0)
        test_case(8'd128, 8'd128, 1'b0);

        // Corner Case: Max possible result (255+255+1 = 511)
        test_case(8'd255, 8'd255, 1'b1);

        // Random values
        test_case(8'd42, 8'd88, 1'b0);
        test_case(8'd250, 8'd10, 1'b1);
        test_case(8'd1, 8'd1, 1'b1);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```