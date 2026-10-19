module tb;
    reg [3:0] a;
    reg [3:0] b;
    reg       cin;
    wire [3:0] sum;
    wire       cout;

    integer passed, total;
    reg [4:0] model;

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
            if ({cout, sum} === model) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d a=%0d b=%0d cin=%b expected_sum=%0d expected_cout=%b actual_sum=%0d actual_cout=%b", 
                         $time, a, b, cin, model[3:0], model[4], sum, cout);
            end
        end
    endtask

    task test_case(input [3:0] ta, input [3:0] tb_val, input tcin);
        begin
            a = ta;
            b = tb_val;
            cin = tcin;
            #1; // Combinational delay
            model = ta + tb_val + tcin;
            check;
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // Test Case 1: Zeroes
        test_case(4'd0, 4'd0, 1'b0);
        
        // Test Case 2: Simple addition
        test_case(4'd5, 4'd3, 1'b0);
        
        // Test Case 3: Addition with carry in
        test_case(4'd5, 4'd3, 1'b1);
        
        // Test Case 4: Max values without overflow
        test_case(4'd7, 4'd8, 1'b0);

        // Test Case 5: Overflow (cout = 1)
        test_case(4'd15, 4'd0, 1'b1); // 15 + 0 + 1 = 16 -> sum=0, cout=1
        test_case(4'd15, 4'd15, 1'b1); // 15 + 15 + 1 = 31 -> sum=15, cout=1
        test_case(4'd10, 4'd10, 1'b0); // 10 + 10 = 20 -> sum=4, cout=1

        // Test Case 6: Boundary transitions
        test_case(4'd0, 4'd15, 1'b0);
        test_case(4'd1, 4'd15, 1'b0);
        test_case(4'd1, 4'd15, 1'b1);

        // Test Case 7: All combinations of cin and small numbers
        test_case(4'd1, 4'd1, 1'b0);
        test_case(4'd1, 4'd1, 1'b1);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
