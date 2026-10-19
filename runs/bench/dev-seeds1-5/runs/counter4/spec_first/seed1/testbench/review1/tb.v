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
        ref_count = 4'd0; 
        passed = 0;
        total = 0;

        // Wait for a few cycles to stabilize
        repeat (2) @(posedge clk);

        // Test Case 1: Synchronous Reset
        rst = 1; en = 1; 
        @(posedge clk);
        #1; // Allow non-blocking assignments to propagate
        ref_count = 4'd0;
        check_output(ref_count);

        // Test Case 2: Enable/Disable functionality
        rst = 0; en = 1;
        @(posedge clk);
        #1;
        ref_count = ref_count + 1;
        check_output(ref_count);

        en = 0;
        @(posedge clk);
        #1;
        // count should stay same
        check_output(ref_count);

        en = 1;
        @(posedge clk);
        #1;
        ref_count = ref_count + 1;
        check_output(ref_count);

        // Test Case 3: Wrap around (0 to 15)
        while (ref_count < 4'd15) begin
            en = 1;
            @(posedge clk);
            #1;
            ref_count = ref_count + 1;
            check_output(ref_count);
        end

        // Test Wrap around: 15 -> 0
        en = 1;
        @(posedge clk);
        #1;
        ref_count = 4'd0;
        check_output(ref_count);

        // Test Case 4: Reset during counting
        en = 1;
        @(posedge clk);
        #1;
        ref_count = ref_count + 1;
        check_output(ref_count);

        rst = 1; en = 1;
        @(posedge clk);
        #1;
        ref_count = 4'd0;
        check_output(ref_count);

        // Test Case 5: Reset priority over Enable
        rst = 1; en = 0;
        @(posedge clk);
        #1;
        ref_count = 4'd0;
        check_output(ref_count);

        rst = 0; en = 1;
        @(posedge clk);
        #1;
        ref_count = ref_count + 1;
        check_output(ref_count);

        // Test Case 6: Random sequence of operations
        repeat (20) begin
            en = $random % 2;
            rst = $random % 2;
            @(posedge clk);
            #1;
            if (rst) begin
                ref_count = 4'd0;
            end else if (en) begin
                ref_count = ref_count + 1;
            end
            check_output(ref_count);
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
