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

    task check_mux;
        reg [7:0] expected_y;
        begin
            total = total + 1;
            // Reference model logic based on specification
            if (sel == 1'b0) begin
                expected_y = a;
            end else begin
                expected_y = b;
            end

            #1; // Small delay to allow combinational logic to settle
            if (y !== expected_y) begin
                $display("FAIL: a=%d, b=%d, sel=%b | Expected y=%d, Actual y=%d", 
                         a, b, sel, expected_y, y);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        // Initialize counters
        passed = 0;
        total = 0;

        // Test Case 1: sel=0, a=0, b=any
        a = 8'h00; b = 8'hFF; sel = 1'b0;
        check_mux();

        // Test Case 2: sel=0, a=max, b=any
        a = 8'hFF; b = 8'h00; sel = 1'b0;
        check_mux();

        // Test Case 3: sel=1, b=0, a=any
        a = 8'hAA; b = 8'h00; sel = 1'b1;
        check_mux();

        // Test Case 4: sel=1, b=max, a=any
        a = 8'h55; b = 8'hFF; sel = 1'b1;
        check_mux();

        // Test Case 5: Transitioning inputs (sel changes)
        a = 8'h12; b = 8'h34; sel = 1'b0;
        check_mux();
        sel = 1'b1;
        check_mux();

        // Test Case 6: All bits toggling (Pattern test)
        a = 8'hAA; b = 8'h55; sel = 1'b0;
        check_mux();
        sel = 1'b1;
        check_mux();

        // Test Case 7: Corner case - all zeros
        a = 8'h00; b = 8'h00; sel = 1'b0;
        check_mux();
        sel = 1'b1;
        check_mux();

        // Test Case 8: Corner case - all ones
        a = 8'hFF; b = 8'hFF; sel = 1'b0;
        check_mux();
        sel = 1'b1;
        check_mux();

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
