`timescale 1ns / 1ps
module tb;
    // Inputs
    reg clk;
    reg rst;
    reg en;

    // Outputs
    wire [3:0] count;

    // DUT instantiation
    counter4 uut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .count(count)
    );

    // Reference Model Variables
    reg [3:0] expected_count;
    integer passed;
    integer total;

    // Clock generation
    always #5 clk = ~clk;

    // Task to check the output
    task check_output;
        input [3:0] actual_val;
        begin
            total = total + 1;
            if (actual_val !== expected_count) begin
                $display("FAIL: rst=%b, en=%b, expected=%d, actual=%d", rst, en, expected_count, actual_val);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst = 0;
        en = 0;
        expected_count = 4'd0; // Initial state doesn't matter, but we track it
        passed = 0;
        total = 0;

        // Wait for a few cycles to stabilize
        repeat (2) @(posedge clk);

        // --- Test Case 1: Synchronous Reset ---
        rst = 1; en = 1; // rst has priority over en
        @(posedge clk);
        expected_count = 4'd0;
        #1; // Small delay to allow signal propagation for check
        check_output(count);

        // --- Test Case 2: Enable and Counting ---
        rst = 0; en = 1;
        @(posedge clk);
        expected_count = 4'd1;
        #1;
        check_output(count);

        @(posedge clk);
        expected_count = 4'd2;
        #1;
        check_output(count);

        // --- Test Case 3: Disable (Hold value) ---
        en = 0;
        @(posedge clk);
        expected_count = 4'd2; // Should stay at 2
        #1;
        check_output(count);

        @(posedge clk);
        expected_count = 4'd2; // Should stay at 2
        #1;
        check_output(count);

        // --- Test Case 4: Enable again and count to wrap ---
        en = 1;
        // We are at 2. Let's go to 15 then wrap.
        repeat (13) @(posedge clk); 
        // After 13 more increments: 2 + 13 = 15
        expected_count = 4'd15;
        #1;
        check_output(count);

        @(posedge clk); // Wrap around
        expected_count = 4'd0;
        #1;
        check_output(count);

        // --- Test Case 5: Reset while counting ---
        en = 1;
        @(posedge clk); // count becomes 1
        expected_count = 4'd1;
        #1;
        check_output(count);

        rst = 1; // Trigger reset
        @(posedge clk);
        expected_count = 4'd0;
        #1;
        check_output(count);

        // --- Test Case 6: Reset priority over Enable ---
        rst = 1; en = 1;
        @(posedge clk);
        expected_count = 4'd0;
        #1;
        check_output(count);

        // --- Test Case 7: Stress test / Sequence ---
        rst = 0; en = 1;
        repeat (16) begin
            @(posedge clk);
            expected_count = expected_count + 1;
            #1;
            check_output(count);
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
