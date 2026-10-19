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

    // Reference Model State
    reg [3:0] ref_count;
    integer passed;
    integer total;

    // Clock generation
    always #5 clk = ~clk;

    // Task to check the output
    task check_output;
        input [3:0] expected;
        begin
            total = total + 1;
            if (count !== expected) begin
                $display("FAIL: rst=%b, en=%b, clk_edge=rising. Expected count=%d, Actual count=%d", rst, en, expected, count);
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
        ref_count = 4'd0; 
        passed = 0;
        total = 0;

        // Wait for a few cycles to stabilize. 
        // We use a reset at the very beginning to ensure 'count' is not 'x'.
        rst = 1;
        repeat (2) @(posedge clk);
        #1; // Allow time for synchronous reset to propagate
        ref_count = 4'd0;

        // --- Test Case 1: Synchronous Reset ---
        rst = 1; en = 1; 
        @(posedge clk);
        #1; // Wait for delta cycle/propagation
        ref_count = 4'd0;
        check_output(ref_count);

        // --- Test Case 2: Enable and Counting ---
        rst = 0; en = 1;
        repeat (5) begin
            @(posedge clk);
            #1;
            ref_count = ref_count + 1'b1;
            check_output(ref_count);
        end

        // --- Test Case 3: Disable (Hold value) ---
        en = 0;
        @(posedge clk);
        #1;
        // ref_count stays same
        check_output(ref_count);

        // --- Test Case 4: Re-enable and Wrap Around ---
        en = 1;
        while (ref_count != 4'd15) begin
            @(posedge clk);
            #1;
            ref_count = ref_count + 1'b1;
            check_output(ref_count);
        end
        // Next cycle should be 0
        @(posedge clk);
        #1;
        ref_count = 4'd0;
        check_output(ref_count);

        // --- Test Case 5: Reset while counting ---
        en = 1;
        @(posedge clk); // count becomes 1
        #1;
        ref_count = ref_count + 1'b1;
        check_output(ref_count);

        rst = 1; // Trigger reset
        @(posedge clk);
        #1;
        ref_count = 4'd0;
        check_output(ref_count);

        // --- Test Case 6: Reset priority over Enable ---
        rst = 1; en = 1;
        @(posedge clk);
        #1;
        ref_count = 4'd0;
        check_output(ref_count);

        // --- Test Case 7: Multiple cycles of reset ---
        rst = 1;
        repeat (3) begin
            @(posedge clk);
            #1;
            ref_count = 4'd0;
            check_output(ref_count);
        end

        // Final cleanup
        rst = 0; en = 0;
        repeat (2) @(posedge clk);
        #1;

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
