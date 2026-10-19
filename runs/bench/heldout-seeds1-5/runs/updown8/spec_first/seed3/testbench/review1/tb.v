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

    // Clock Generation
    always #5 clk = ~clk;

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
        #2; // Wait for async effect
        if (count !== 8'd0) begin
            $display("FAIL: Async reset failed. Expected: 0, Actual: %d", count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        expected_count = 8'd0;

        // --- Test Case 2: Release Reset and Enable/Disable ---
        #10 rst_n = 1; 
        @(posedge clk); // Wait for a clock edge to ensure stability
        #1; 
        
        en = 0;
        // Check that count stays 0 when en=0
        if (count !== expected_count) begin
            $display("FAIL: rst_n=%b, en=%b, up=%b | Expected: %d, Actual: %d", rst_n, en, up, expected_count, count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        // --- Test Case 3: Up Counting ---
        en = 1;
        up = 1;
        repeat (5) begin
            @(posedge clk);
            #1; // Wait for DUT to update
            expected_count = expected_count + 1'b1;
            if (count !== expected_count) begin
                $display("FAIL: rst_n=%b, en=%b, up=%b | Expected: %d, Actual: %d", rst_n, en, up, expected_count, count);
                total = total + 1;
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
        end

        // --- Test Case 4: Down Counting ---
        up = 0;
        repeat (3) begin
            @(posedge clk);
            #1;
            expected_count = expected_count - 1'b1;
            if (count !== expected_count) begin
                $display("FAIL: rst_n=%b, en=%b, up=%b | Expected: %d, Actual: %d", rst_n, en, up, expected_count, count);
                total = total + 1;
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
        end

        // --- Test Case 5: Wrap Around Up ---
        en = 1;
        up = 1;
        expected_count = 8'd255; // Force model to wrap-around state
        // We need the DUT to actually be at 255. Let's drive it there.
        // To avoid complex logic, we just reset and count up.
        rst_n = 0; #10 rst_n = 1; @(posedge clk); #1; expected_count = 0;
        en = 1; up = 1;
        repeat (255) begin
            @(posedge clk); #1 expected_count = expected_count + 1'b1;
        end
        // Now count is 255. Next edge should be 0.
        @(posedge clk);
        #1;
        expected_count = 8'd0;
        if (count !== expected_count) begin
            $display("FAIL: rst_n=%b, en=%b, up=%b | Expected: %d, Actual: %d", rst_n, en, up, expected_count, count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        // --- Test Case 6: Wrap Around Down ---
        en = 1;
        up = 0;
        // Reset to 0, then count down once to get 255
        rst_n = 0; #10 rst_n = 1; @(posedge clk); #1 expected_count = 0;
        en = 1; up = 0;
        @(posedge clk);
        #1;
        expected_count = 8'd255;
        if (count !== expected_count) begin
            $display("FAIL: rst_n=%b, en=%b, up=%b | Expected: %d, Actual: %d", rst_n, en, up, expected_count, count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        // --- Test Case 7: Enable Disable during counting ---
        en = 0;
        @(posedge clk);
        #1; // expected_count remains 255
        if (count !== expected_count) begin
            $display("FAIL: rst_n=%b, en=%b, up=%b | Expected: %d, Actual: %d", rst_n, en, up, expected_count, count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        en = 1;
        up = 1;
        @(posedge clk);
        #1;
        expected_count = expected_count + 1'b1; // Should be 0 (255+1)
        if (count !== expected_count) begin
            $display("FAIL: rst_n=%b, en=%b, up=%b | Expected: %d, Actual: %d", rst_n, en, up, expected_count, count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        // --- Test Case 8: Asynchronous Reset during operation ---
        #5 rst_n = 0;
        #2; 
        if (count !== 8'd0) begin
            $display("FAIL: Async reset failed during operation. Expected: 0, Actual: %d", count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        expected_count = 8'd0;

        // Finalize
        #20;
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
