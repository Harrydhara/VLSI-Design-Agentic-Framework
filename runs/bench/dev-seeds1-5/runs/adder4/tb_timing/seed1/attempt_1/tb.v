module tb;

    reg [3:0] a;
    reg [3:0] b;
    reg       cin;
    wire [3:0] sum;
    wire       cout;

    integer passed;
    integer total;

    // Reference model for the expected values
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
                $display("FAIL: time=%0d a=%0d b=%0d cin=%b expected={cout=%b, sum=%b} actual={cout=%b, sum=%b}", 
                         $time, a, b, cin, $onehot(model_result[4]), model_result[3:0], cout, sum);
            end
        end
    endtask

    task test_case(input [3:0] ta, input [3:0] tb_val, input tcin);
        begin
            a = ta;
            b = tb_val;
            cin = tcin;
            model_result = ta + tb_val + tcin;
            #1; // Wait for combinational logic to settle
            check;
        end
    endtask

    initial begin
        // Initialize
        a = 0;
        b = 0;
        cin = 0;
        passed = 0;
        total = 0;

        // Test Case 1: Zeroes
        test_case(4'd0, 4'd0, 1'b0);

        // Test Case 2: Simple addition without carry
        test_case(4'd1, 4'd2, 1'b0);

        // Test Case 3: Addition with cin
        test_case(4'd5, 4'd5, 1'b1);

        // Test Case 4: Max values (no overflow)
        test_case(4'd7, 4'd8, 1'b0);

        // Test Case 5: Overflow/Carry out
        test_case(4'd15, 4'd0, 1'b1); // 15 + 0 + 1 = 16 (cout=1, sum=0)
        test_case(4'd15, 4'd15, 1'b1); // 15 + 15 + 1 = 31 (cout=1, sum=15)
        test_case(4'd10, 4'd10, 1'b0); // 10 + 10 = 20 (cout=1, sum=4)

        // Test Case 6: Boundary transitions
        test_case(4'd0, 4'd0, 1'b1);
        test_case(4'd7, 4'd8, 1'b1); // 7 + 8 + 1 = 16 (cout=1, sum=0)

        // Test Case 7: All combinations of cin and small numbers
        test_case(4'd1, 4'd1, 1'b0);
        test_case(4'd1, 4'd1, 1'b1);

        // Exhaustive check for a few more patterns to be sure
        test_case(4'd8, 4'd8, 1'b0); // 16 -> cout=1, sum=0
        test_case(4'd4, 4'd2, 1'b1); // 7 -> cout=0, sum=7

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
