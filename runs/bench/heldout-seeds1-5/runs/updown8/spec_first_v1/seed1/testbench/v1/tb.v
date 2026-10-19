`timescale 1ns / 1ps
module tb;
    // Inputs
    reg clk;
    reg rst_n;
    reg en;
    reg up;

    // Outputs
    wire [7:0] count;

    // DUT instantiation
    updown8 dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .up(up),
        .count(count)
    );

    // Reference Model Variables
    reg [7:0] expected_count;
    integer passed;
    integer total;

    // Clock generation
    always #5 clk = ~clk;

    // Task to check output
    task check_output;
        input [7:0] actual_val;
        begin
            total = total + 1;
            if (actual_val !== expected_count) begin
                $display("FAIL: rst_n=%b, en=%b, up=%b | Expected: %d, Actual: %d", 
                         rst_n, en, up, expected_count, actual_val);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst_n = 1;
        en = 0;
        up = 1;
        expected_count = 8'd0;
        passed = 0;
        total = 0;

        // --- Test Case 1: Asynchronous Reset ---
        #7; // Wait a bit
        rst_n = 0;
        #3; // Check immediately (asynchronous)
        if (count !== 8'd0) begin
            $display("FAIL: Async reset failed. Expected: 0, Actual: %d", count);
            total = total + 1; // Manual increment because we can't use task easily here for async check logic
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        expected_count = 8'd0;

        // --- Test Case 2: Release Reset and Enable/Disable ---
        #10;
        rst_n = 1; // Release reset
        en = 1;    // Enable counting
        up = 1;    // Up direction
        
        // Count up for several cycles
        repeat (5) begin
            @(posedge clk);
            #1; // Wait for propagation
            expected_count = expected_count + 1'b1;
            check_output(count);
        end

        en = 0;    // Disable counting
        repeat (3) begin
            @(posedge clk);
            #1;
            // expected_count stays same
            check_output(count);
        end

        // --- Test Case 3: Down direction and Wrap around ---
        en = 1;
        up = 0;    // Down direction
        repeat (5) begin
            @(posedge clk);
            #1;
            expected_count = expected_count - 1'b1;
            check_output(count);
        end

        // Test Wrap around (0 -> 255)
        // Current state: we need to get to 0. Let's force it by counting down.
        repeat (10) begin
            @(posedge clk);
            #1;
            expected_count = expected_count - 1'b1;
            check_output(count);
        end

        // Test Wrap around (255 -> 0)
        up = 1;
        repeat (10) begin
            @(posedge clk);
            #1;
            expected_count = expected_count + 1'b1;
            check_output(count);
        end

        // --- Test Case 4: Extreme Wrap around (255 -> 0 and 0 -> 255) ---
        // Force to 255
        expected_count = 8'd255;
        // We need the DUT to be at 255. Let's just set our model to match current state if needed, 
        // but we want to test the transition.
        // To ensure DUT is at 255, let's run a loop until it hits 255 or just assume logic.
        // Better: reset and count up.
        rst_n = 0; #10; rst_n = 1; @(posedge clk); #1;
        expected_count = 8'd0;
        up = 1; en = 1;
        repeat (255) begin
            @(posedge clk);
            #1;
            expected_count = expected_count + 1'b1;
        end
        // Now DUT should be at 255. Check next cycle for wrap to 0.
        @(posedge clk);
        #1;
        expected_count = 8'd0;
        check_output(count);

        // Test Down Wrap (0 -> 255)
        up = 0;
        @(posedge clk);
        #1;
        expected_count = 8'd255;
        check_output(count);

        // --- Test Case 5: Asynchronous Reset during operation ---
        en = 1; up = 1;
        repeat (5) @(posedge clk);
        rst_n = 0;
        #2; // Check mid-cycle
        if (count !== 8'd0) begin
             $display("FAIL: Async reset during operation failed. Expected: 0, Actual: %d", count);
             total = total + 1;
        end else begin
             passed = passed + 1;
             total = total + 1;
        end
        expected_count = 8'd0;
        #10;
        rst_n = 1;

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
