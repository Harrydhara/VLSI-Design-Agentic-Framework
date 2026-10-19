```verilog
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

            // Combinational logic requires a small delay for propagation in simulation
            #1;

            // Reference Model calculation
            if (sel == 1'b0) begin
                expected_y = test_a;
            end else begin
                expected_y = test_b;
            end

            // Verification
            total = total + 1;
            if (y === expected_y) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: a=%d, b=%d, sel=%b | Expected y=%d, Actual y=%d", 
                         test_a, test_b, sel, expected_y, y);
            end
        end
    endtask

    initial begin
        // Initialize counters
        passed = 0;
        total = 0;

        // Test Case 1: Basic functionality (sel=0)
        check_mux(8'hAA, 8'hBB, 1'b0); // a selected
        check_mux(8'h00, 8'hFF, 1'b0); // a selected (zeros)
        check_mux(8'h55, 8'hCC, 1'b0); // a selected

        // Test Case 2: Basic functionality (sel=1)
        check_mux(8'hAA, 8'hBB, 1'b1); // b selected
        check_mux(8'hFF, 8'h00, 1'b1); // b selected (zeros)
        check_mux(8'h12, 8'h34, 1'b1); // b selected

        // Test Case 3: Corner Cases - All bits same/different
        check_mux(8'hFF, 8'hFF, 1'b0); // a=b, sel=0
        check_mux(8'hFF, 8'hFF, 1'b1); // a=b, sel=1
        check_mux(8'h00, 8'h00, 1'b0); // a=b, sel=0
        check_mux(8'h00, 8'h00, 1'b1); // a=b, sel=1

        // Test Case 4: Transitions (Toggle inputs)
        check_mux(8'h01, 8'h02, 1'b0);
        check_mux(8'h01, 8'h02, 1'b1);
        check_mux(8'hFE, 8'hFD, 1'b0);
        check_mux(8'hFE, 8'hFD, 1'b1);

        // Test Case 5: Exhaustive check for sel=0 and sel=1 with specific patterns
        // (Not exhaustive of all 2^17 combinations to keep simulation time reasonable, 
        // but covers significant bit transitions)
        check_mux(8'h5A, 8'h55, 1'b0);
        check_mux(8'h5A, 8'h55, 1'b1);
        check_mux(8'h0F, 8'hF0, 1'b0);
        check_mux(8'h0F, 8'hF0, 1'b1);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```