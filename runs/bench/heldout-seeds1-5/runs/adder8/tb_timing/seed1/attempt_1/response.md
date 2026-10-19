```verilog
module adder8(
    input  [7:0] a,
    input  [7:0] b,
    input        cin,
    output [7:0] sum,
    output       cout
);

    // The 9-bit result represents the full addition including carry out.
    // We concatenate cout and sum to capture the overflow bit.
    wire [8:0] full_result;

    assign full_result = a + b + cin;
    assign sum = full_result[7:0];
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

    // Reference model variables
    reg [8:0] model;
    integer passed = 0;
    integer total = 0;

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

    task test_case(input [7:0] ta, input [7:0] tb_val, input tcin);
        begin
            a = ta;
            b = tb_val;
            cin = tcin;
            model = ta + tb_val + tcin;
            #1; // Wait for combinational logic to settle
            check;
        end
    endtask

    initial begin
        // Initialize
        a = 0; b = 0; cin = 0; model = 0;

        // Corner Case: All Zeros
        test_case(8'd0, 8'd0, 1'b0);

        // Corner Case: Max values without overflow
        test_case(8'd127, 8'd127, 1'b0);

        // Corner Case: Cin only
        test_case(8'd0, 8'd0, 1'b1);

        // Corner Case: Overflow (Max + Max)
        test_case(8'd255, 8'd255, 1'b1);

        // Corner Case: Single bit transitions
        test_case(8'd1, 8'd1, 1'b0);
        test_case(8'd255, 8'd0, 1'b1);
        test_case(8'd255, 8'd1, 1'b0); // sum=0, cout=1

        // Random-ish patterns
        test_case(8'd10, 8'd20, 1'b0);
        test_case(8'd100, 8'd150, 1'b0);
        test_case(8'd100, 8'd150, 1'b1);
        test_case(8'd200, 8'd100, 1'b0);
        test_case(8'd200, 8'd100, 1'b1);

        // Boundary: 255 + 0 + 0 = 255 (cout 0)
        test_case(8'd255, 8'd0, 1'b0);
        // Boundary: 255 + 0 + 1 = 0 (cout 1)
        test_case(8'd255, 8'd0, 1'b1);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```