module tb;
    reg [7:0] a;
    reg [7:0] b;
    reg       cin;
    wire [7:0] sum;
    wire       cout;

    integer passed;
    integer total;
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

    task test_case(input [7:0] ta, input [7:0] tb_val, input tcin);
        begin
            a = ta;
            b = tb_val;
            cin = tcin;
            model = ta + tb_val + tcin;
            #1; // Combinational delay
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
        model = 0;

        // Test Case 1: Zeroes
        test_case(8'd0, 8'd0, 1'b0);

        // Test Case 2: Simple addition
        test_case(8'd10, 8'd20, 1'b0);

        // Test Case 3: Addition with carry in
        test_case(8'd10, 8'd20, 1'b1);

        // Test Case 4: Max values without overflow
        test_case(8'd127, 8'd127, 1'b0);

        // Test Case 5: Boundary - sum reaches 255
        test_case(8'd255, 8'd0, 1'b0);

        // Test Case 6: Overflow (cout = 1)
        test_case(8'd255, 8'd1, 1'b0);
        test_case(8'd255, 8'd255, 1'b0);
        test_case(8'd255, 8'd255, 1'b1);

        // Test Case 7: Carry in triggers overflow
        test_case(8'd127, 8'd127, 1'b1); // 127+127+1 = 255 (cout=0)
        test_case(8'd128, 8'd127, 1'b1); // 128+127+1 = 256 (cout=1)

        // Test Case 8: Random patterns
        test_case(8'hAA, 8'h55, 1'b0);
        test_case(8'hFF, 8'hFF, 1'b1);
        test_case(8'h01, 8'h02, 1'b0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
