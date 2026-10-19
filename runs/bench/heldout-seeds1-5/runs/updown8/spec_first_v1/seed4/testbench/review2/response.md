```verilog
module tb;
    // Inputs
    reg clk;
    reg rst_n;
    reg en;
    reg up;

    // Outputs
    wire [7:0] count;

    // Instantiate the Unit Under Test (UUT)
    updown8 uut (
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
        input [7:0] actual_val;
        begin
            total = total + 1;
            if (actual_val !== expected_count) begin
                $display("FAIL: rst_n=%b, en=%b, up=%b | Expected: %d, Actual: %d", 
                         rst_n, en, up, expected_count, actual_val);
                passed = passed - 1;
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
        #2; // Wait a bit
        if (count !== 8'd0) begin
            $display("FAIL: Async reset failed. Expected: 0, Actual: %d", count);
            passed = passed - 1;
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        expected_count = 8'd0;

        // --- Test Case 2: Reset Release and Enable/Disable ---
        #10 rst_n = 1; // Release reset
        #5 en = 1;     // Enable counting
        #5 en = 0;     // Disable counting
        @(posedge clk);
        #1;           // Wait for propagation
        check_output(count);

        // --- Test Case 3: Up Counting ---
        en = 1;
        up = 1;
        expected_count = 8'd0; // Reset was just released, count should be 0
        
        repeat (5) begin
            @(posedge clk);
            #1; // Wait for propagation
            expected_count = expected_count + 1;
            check_output(count);
        end

        // --- Test Case 4: Wrap Around Up ---
        repeat (256) begin
            @(posedge clk);
            #1;
            expected_count = expected_count + 1;
            check_output(count);
        end

        // --- Test Case 5: Down Counting ---
        en = 1;
        up = 0;
        repeat (3) begin
            @(posedge clk);
            #1;
            expected_count = expected_count - 1;
            check_output(count);
        end

        // --- Test Case 6: Enable Disable during counting ---
        en = 0;
        up = 1;
        @(posedge clk);
        #1;
        expected_count = expected_count; // Should not change
        check_output(count);

        // --- Test Case 7: Asynchronous Reset mid-cycle ---
        en = 1;
        up = 1;
        @(posedge clk);
        #2 rst_n = 0; // Assert reset asynchronously
        
        // The specification says "Whenever rst_n is 0, count becomes 0 immediately"
        // We check the value IMMEDIATELY after setting rst_n to 0.
        if (count !== 8'd0) begin
            $display("FAIL: Async reset mid-cycle failed. Expected: 0, Actual: %d", count);
            passed = passed - 1;
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        expected_count = 8'd0;

        // --- Test Case 8: Reset Release and Up/Down toggle ---
        #10 rst_n = 1;
        en = 1;
        up = 1;
        @(posedge clk); #1;
        expected_count = 8'd1;
        check_output(count);

        up = 0;
        @(posedge clk); #1;
        expected_count = 8'd0;
        check_output(count);

        up = 0;
        @(posedge clk); #1;
        expected_count = 8'd255;
        check_output(count);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```