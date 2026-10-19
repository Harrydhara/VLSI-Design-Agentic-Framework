module tb;
    // Inputs
    reg clk;
    reg rst;
    reg en;

    // Outputs
    wire [3:0] count;

    // DUT instantiation
    counter4 dut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .count(count)
    );

    // Reference Model Variables
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
        ref_count = 4'd0; // Initial value doesn't matter, but we track it
        passed = 0;
        total = 0;

        // Wait for a few cycles to stabilize
        repeat (2) @(posedge clk);

        // Test Case 1: Synchronous Reset
        rst = 1; en = 1; // rst has priority over en
        @(posedge clk);
        ref_count = 4'd0;
        check_output(ref_count);

        // Test Case 2: Enable/Disable functionality
        rst = 0; en = 1;
        @(posedge clk);
        ref_count = ref_count + 1;
        check_output(ref_count);

        en = 0;
        @(posedge clk);
        // count should stay same
        check_output(ref_count);

        en = 1;
        @(posedge clk);
        ref_count = ref_count + 1;
        check_output(ref_count);

        // Test Case 3: Wrap around (0 -> 15 -> 0)
        // Current ref_count is likely 2. Let's force it to 15.
        // We do this by cycling en=1 until we hit 15.
        while (ref_count != 4'd15) begin
            en = 1;
            @(posedge clk);
            ref_count = ref_count + 1;
            check_output(ref_count);
        end

        // Next cycle should wrap to 0
        @(posedge clk);
        ref_count = 4'd0;
        check_output(ref_count);

        // Test Case 4: Reset while counting
        en = 1;
        @(posedge clk); // count becomes 1
        ref_count = ref_count + 1;
        check_output(ref_count);

        rst = 1;
        @(posedge clk);
        ref_count = 4'd0;
        check_output(ref_count);

        // Test Case 5: Reset priority over enable
        rst = 1; en = 1;
        @(posedge clk);
        ref_count = 4'd0;
        check_output(ref_count);

        // Test Case 6: Random sequence and corner cases
        rst = 0;
        repeat (20) begin
            en = $random % 2;
            @(posedge clk);
            if (rst == 1) begin
                ref_count = 4'd0;
            end else if (en == 1) begin
                ref_count = ref_count + 1;
            end
            // Note: rst is 0 here, so we only check en logic
            check_output(ref_count);
        end

        // Final Reset Check
        rst = 1;
        @(posedge clk);
        ref_count = 4'd0;
        check_output(ref_count);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
