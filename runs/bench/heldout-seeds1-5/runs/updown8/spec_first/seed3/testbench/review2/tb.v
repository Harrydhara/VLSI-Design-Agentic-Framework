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

    // Task to advance one clock cycle and update reference model
    task tick;
        begin
            @(posedge clk);
            #1; // Wait for DUT propagation
            if (rst_n === 0) begin
                expected_count = 8'd0;
            end else if (en === 1) begin
                if (up === 1) expected_count = expected_count + 1'b1;
                else          expected_count = expected_count - 1'b1;
            end
            // If en is 0, expected_count remains the same
            check_output();
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
        @(posedge clk); #1; // Sync to clock
        en = 0;
        check_output(); // Should be 0

        // --- Test Case 3: Up Counting ---
        en = 1;
        up = 1;
        repeat (5) tick;

        // --- Test Case 4: Down Counting ---
        up = 0;
        repeat (3) tick;

        // --- Test Case 5: Wrap Around Up (255 -> 0) ---
        // First, get to a known state by resetting
        rst_n = 0; #10 rst_n = 1; @(posedge clk); #1; expected_count = 0;
        en = 1; up = 1;
        repeat (255) tick; // Now expected is 255
        tick;               // This should trigger wrap to 0

        // --- Test Case 6: Wrap Around Down (0 -> 255) ---
        up = 0;
        tick;               // This should trigger wrap to 255

        // --- Test Case 7: Enable Disable during counting ---
        en = 0;
        tick;               // Count stays at 255
        en = 1; up = 1;
        tick;               // Count goes to 0 (from 255)

        // --- Test Case 8: Asynchronous Reset during operation ---
        #5 rst_n = 0;
        #2; // Check immediate effect
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
