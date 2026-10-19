module tb;
    // Inputs to DUT
    reg [7:0] a;
    reg [7:0] b;
    reg sel;

    // Outputs from DUT
    wire [7:0] y;

    // Instantiate the Design Under Test (DUT)
    mux2 dut (
        .a(a),
        .b(b),
        .sel(sel),
        .y(y)
    );

    // Reference Model and Verification Logic
    integer passed;
    integer total;

    task check_mux(input [7:0] test_a, input [7:0] test_b, input test_sel);
        reg [7:0] expected_y;
        begin
            // Apply inputs
            a = test_a;
            b = test_b;
            sel = test_sel;

            // Combinational delay simulation (wait for logic to settle)
            #1;

            // Reference Model calculation based on specification
            if (test_sel == 0)
                expected_y = test_a;
            else
                expected_y = test_b;

            total = total + 1;
            if (y === expected_y) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: a=%d, b=%d, sel=%b | Expected y=%d, Actual y=%d", 
                         test_a, test_b, test_sel, expected_y, y);
            end
        end
    endtask

    initial begin
        // Initialize counters
        passed = 0;
        total = 0;

        // Test Case 1: sel=0, a != b
        check_mux(8'hAA, 8'hBB, 1'b0);

        // Test Case 2: sel=1, a != b
        check_mux(8'hAA, 8'hBB, 1'b1);

        // Test Case 3: sel=0, a == b
        check_mux(8'hFF, 8'hFF, 1'b0);

        // Test Case 4: Corner case - all zeros
        check_mux(8'h00, 8'h00, 1'b0);
        check_mux(8'h00, 8'h00, 1'b1);

        // Test Case 5: Corner case - all ones
        check_mux(8'hFF, 8'hFF, 1'b0);
        check_mux(8'hFF, 8'hFF, 1'b1);

        // Test Case 6: Alternating patterns
        check_mux(8'h55, 8'hAA, 1'b0);
        check_mux(8'h55, 8'hAA, 1'b1);

        // Test Case 7: Single bit changes
        check_mux(8'h01, 8'h00, 1'b0);
        check_mux(8'h01, 8'h00, 1'b1);
        check_mux(8'h80, 8'h00, 1'b0);
        check_mux(8'h80, 8'h00, 1'b1);

        // Final Summary
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
