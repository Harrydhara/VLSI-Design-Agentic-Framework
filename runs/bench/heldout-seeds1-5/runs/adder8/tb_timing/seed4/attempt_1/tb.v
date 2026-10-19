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

    adder8 uut (
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
        // Initialize inputs
        a = 0; b = 0; cin = 0; model = 0;

        // Corner Case: All zeros
        test_case(8'd0, 8'd0, 1'b0);

        // Corner Case: All ones (max sum without carry)
        test_case(8'd127, 8'd127, 1'b0);

        // Corner Case: Max values with cin=0
        test_case(8'd255, 8'd0, 1'b0);
        test_case(8'd255, 8'd255, 1'b0);

        // Corner Case: Carry out trigger
        test_case(8'd255, 8'd0, 1'b1); // sum=0, cout=1
        test_case(8'd255, 8'd1, 1'b0); // sum=0, cout=1
        test_case(8'd255, 8'd255, 1'b1); // sum=255, cout=1

        // Corner Case: cin only
        test_case(8'd0, 8'd0, 1'b1);

        // Random-ish values
        test_case(8'd10, 8'd20, 1'b0);
        test_case(8'd10, 8'd20, 1'b1);
        test_case(8'd100, 8'd150, 1'b0);
        test_case(8'd100, 8'd150, 1'b1);
        test_case(8'd200, 8'd100, 1'b0);
        test_case(8'd200, 8'd100, 1'b1);

        // Exhaustive check for small range (optional, but good for coverage)
        // Let's just do a few more specific ones to ensure no bit errors.
        test_case(8'hAA, 8'h55, 1'b0); // sum=FF, cout=0
        test_case(8'hAA, 8'h55, 1'b1); // sum=00, cout=1
        test_case(8'h55, 8'h55, 1'b1); // sum=AA, cout=0

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
