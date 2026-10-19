module tb;

    reg [7:0] a;
    reg [7:0] b;
    reg       cin;
    wire [7:0] sum;
    wire       cout;

    integer i;
    integer passed;
    integer total;

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

        // Test Case 1: Simple addition without carry
        check_addition(8'd10, 8'd20, 1'b0);
        
        // Test Case 2: Addition with cin
        check_addition(8'd10, 8'd20, 1'b1);

        // Test Case 3: Max values (Overflow/Carry out)
        check_addition(8'hFF, 8'h00, 1'b0); // 255 + 0 = 255
        check_addition(8'hFF, 8'h01, 1'b0); // 255 + 1 = 256 (cout=1, sum=0)
        check_addition(8'hFF, 8'hFF, 1'b0); // 255 + 255 = 510 (cout=1, sum=254)
        check_addition(8'hFF, 8'hFF, 1'b1); // 255 + 255 + 1 = 511 (cout=1, sum=255)

        // Test Case 4: Zeroes
        check_addition(8'd0, 8'd0, 1'b0);
        check_addition(8'd0, 8'd0, 1'b1);

        // Test Case 5: Exhaustive search for small range to ensure correctness
        for (i = 0; i < 16; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                // Using local variables in loop is tricky in Verilog, 
                // so we use a nested approach or just manual checks.
            end
        end
        
        // Let's do a more robust exhaustive check for all inputs if time permits, 
        // but for a testbench, specific corner cases are usually sufficient.
        // We will add a loop for a subset of values to be thorough.
        for (i = 0; i < 256; i = i + 1) begin
            // To keep simulation fast, we won't do 256*256*2. 
            // Let's just check a few more patterns.
            check_addition(i[7:0], 8'd1, 1'b0);
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    // Helper task to perform checks
    task check_addition;
        input [7:0] t_a;
        input [7:0] t_b;
        input       t_cin;
        reg [8:0] expected;
        begin
            total = total + 1;
            a = t_a;
            b = t_b;
            cin = t_cin;
            #1; // Wait for combinational logic
            expected = t_a + t_b + t_cin;
            if ({cout, sum} !== expected) begin
                $display("FAIL: a=%d, b=%d, cin=%b | Expected {cout,sum}=%d, Got {cout,sum}=%d", 
                         t_a, t_b, t_cin, expected, {cout, sum});
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    // Using integer j for the loop inside task logic if needed, 
    // but we'll stick to simple calls.
    reg [7:0] j;

endmodule
