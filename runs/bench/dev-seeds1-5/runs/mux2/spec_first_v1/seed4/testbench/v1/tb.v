module tb;
    // Inputs
    reg [7:0] a;
    reg [7:0] b;
    reg sel;

    // Outputs
    wire [7:0] y;

    // Instantiate the Unit Under Test (UUT)
    mux2 uut (
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

        // Test Case 1: sel = 0, a != b
        a = 8'hAA; b = 8'h55; sel = 1'b0;
        check_mux();

        // Test Case 2: sel = 1, a != b
        a = 8'hAA; b = 8'h55; sel = 1'b1;
        check_mux();

        // Test Case 3: sel = 0, a == b
        a = 8'hFF; b = 8'hFF; sel = 1'b0;
        check_mux();

        // Test Case 4: Corner case - All zeros
        a = 8'h00; b = 8'h00; sel = 1'b0;
        check_mux();
        a = 8'h00; b = 8'h00; sel = 1'b1;
        check_mux();

        // Test Case 5: Corner case - All ones
        a = 8'hFF; b = 8'hFF; sel = 1'b0;
        check_mux();
        a = 8'hFF; b = 8'hFF; sel = 1'b1;
        check_mux();

        // Test Case 6: Alternating bits
        a = 8'hAA; b = 8'h55; sel = 1'b0;
        check_mux();
        a = 8'hAA; b = 8'h55; sel = 1'b1;
        check_mux();

        // Test Case 7: Single bit changes
        a = 8'h01; b = 8'h00; sel = 1'b0;
        check_mux();
        a = 8'h01; b = 8'h00; sel = 1'b1;
        check_mux();

        a = 8'h80; b = 8'h00; sel = 1'b0;
        check_mux();
        a = 8'h80; b = 8'h00; sel = 1'b1;
        check_mux();

        // Test Case 8: Random values
        a = 8'd42;  b = 8'd123; sel = 1'b0;
        check_mux();
        a = 8'd42;  b = 8'd123; sel = 1'b1;
        check_mux();

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
