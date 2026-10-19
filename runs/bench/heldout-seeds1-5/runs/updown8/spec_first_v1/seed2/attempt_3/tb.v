module tb;
    // Inputs
    reg clk;
    reg rst_n;
    reg en;
    reg up;

    // Outputs
    wire [7:0] count;

    // Instantiate the Design Under Test (DUT)
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

    // Task to check the output
    task check_output;
        begin
            total = total + 1;
            if (count !== expected_count) begin
                $display("FAIL: rst_n=%b, en=%b, up=%b | Expected: %d, Actual: %d", 
                         rst_n, en, up, expected_count, count);
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
        #3 rst_n = 0;
        #2; // Wait a bit, not on clock edge
        if (count !== 8'd0) begin
            $display("FAIL: Async reset failed. Expected: 0, Actual: %d", count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        
        #5 rst_n = 1; // Release reset
        // After reset release, we must ensure the reference model is synchronized.
        // Since rst_n was 0, count is definitely 0.
        expected_count = 8'd0;

        // --- Test Case 2: Enable/Disable and Up/Down functionality ---
        
        // Wait for a clock edge to stabilize after reset release
        @(posedge clk); #1;
        check_output(); // Check that count is still 0 (en=0)

        // Test Disable (en=0)
        en = 0; up = 1;
        @(posedge clk); #1;
        check_output();

        // Test Incrementing (up=1, en=1)
        en = 1; up = 1;
        repeat (5) begin
            expected_count = expected_count + 1'b1;
            @(posedge clk); #1;
            check_output();
        end

        // Test Decrementing (up=0, en=1)
        up = 0;
        repeat (3) begin
            expected_count = expected_count - 1'b1;
            @(posedge clk); #1;
            check_output();
        end

        // Test Wrap Around Up (255 -> 0)
        en = 1; up = 1;
        expected_count = 8'd255;
        @(posedge clk); #1;
        expected_count = 8'd0;
        check_output();

        // Test Wrap Around Down (0 -> 255)
        en = 1; up = 0;
        @(posedge clk); #1;
        expected_count = 8'd255;
        check_output();

        // --- Test Case 3: Asynchronous Reset during operation ---
        en = 1; up = 1;
        @(posedge clk); #1; // Move to some value
        #2 rst_n = 0;       // Assert reset mid-cycle
        if (count !== 8'd0) begin
            $display("FAIL: Async reset during operation failed. Expected: 0, Actual: %d", count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        #10 rst_n = 1;
        expected_count = 8'd0; // Sync ref model after reset

        // --- Test Case 4: Edge case - Reset while en=0 ---
        en = 0;
        @(posedge clk); #1;
        check_output(); // count should be 0
        
        #2 rst_n = 0;
        if (count !== 8'd0) begin
            $display("FAIL: Async reset while en=0 failed. Expected: 0, Actual: %d", count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
