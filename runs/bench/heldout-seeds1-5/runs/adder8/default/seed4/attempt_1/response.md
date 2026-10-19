```verilog
module adder8(
    input  [7:0] a,
    input  [7:0] b,
    input        cin,
    output [7:0] sum,
    output       cout
);

    // The 9-bit result is the concatenation of cout and sum.
    // We use a single assignment to ensure it's purely combinational.
    assign {cout, sum} = a + b + cin;

endmodule
```

```verilog
module tb();

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

        // Test Case 1: Basic addition without carry
        test_case(8'd10, 8'd20, 1'b0);
        
        // Test Case 2: Addition with cin
        test_case(8'd10, 8'd20, 1'b1);

        // Test Case 3: Maximum values (Overflow)
        test_case(8'd255, 8'd0,   1'b0);
        test_case(8'd255, 8'd255, 1'b0);
        test_case(8'd255, 8'd255, 1'b1);

        // Test Case 4: Zeroes
        test_case(8'd0,   8'd0,   1'b0);
        test_case(8'd0,   8'd0,   1'b1);

        // Test Case 5: Exhaustive search for small range to ensure correctness
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                for (k = 0; k < 2; k = k + 1) begin
                    test_case(i, j, k);
                end
            end
        end

        // Test Case 6: Boundary values around overflow
        test_case(8'd127, 8'd128, 1'b0); // 255
        test_case(8'd128, 8'd128, 1'b0); // 256 (cout=1)
        test_case(8'd127, 8'd127, 1'b1); // 255

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    task test_case(input [7:0] ta, input [7:0] tb_val, input tcin);
        begin
            a = ta;
            b = tb_val;
            cin = tcin;
            #1; // Wait for combinational logic to settle

            expected_full = ta + tb_val + tcin;
            actual_full   = {cout, sum};

            total = total + 1;
            if (actual_full === expected_full) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: a=%d, b=%d, cin=%b | Expected %d, Got %d", 
                         ta, tb_val, tcin, expected_full, actual_full);
            end
        end
    endtask

endmodule
```