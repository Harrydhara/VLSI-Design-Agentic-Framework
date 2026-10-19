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
    reg [7:0] ref_count;
    integer passed;
    integer total;

    // Clock generation
    always #5 clk = ~clk;

    // Task to check output
    task check_count;
        input [7:0] expected;
        begin
            total = total + 1;
            if (count !== expected) begin
                $display("FAIL: rst_n=%b, en=%b, up=%b | Expected: %d, Actual: %d", 
                         rst_n, en, up, expected, count);
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
        ref_count = 8'd0;
        passed = 0;
        total = 0;

        // --- Test Case 1: Asynchronous Reset ---
        #7; // Wait a bit
        rst_n = 0;
        #3; // Assert reset mid-cycle
        check_count(8'd0);
        #10;
        rst_n = 1;
        check_count(8'd0);

        // --- Test Case 2: Enable (en=0) should hold value ---
        en = 0;
        up = 1;
        @(posedge clk);
        #1; // Wait for propagation
        check_count(8'd0);
        
        en = 1;
        @(posedge clk);
        #1;
        ref_count = ref_count + 1;
        check_count(ref_count);

        // --- Test Case 3: Up Counting ---
        up = 1;
        repeat (10) begin
            @(posedge clk);
            #1;
            ref_count = ref_count + 1;
            check_count(ref_count);
        end

        // --- Test Case 4: Wrap Around Up (255 -> 0) ---
        ref_count = 8'd255;
        @(posedge clk);
        #1;
        ref_count = 8'd0;
        check_count(ref_count);

        // --- Test Case 5: Down Counting ---
        up = 0;
        repeat (5) begin
            @(posedge clk);
            #1;
            ref_count = ref_count - 1;
            check_count(ref_count);
        end

        // --- Test Case 6: Wrap Around Down (0 -> 255) ---
        ref_count = 8'd0;
        @(posedge clk);
        #1;
        ref_count = 8'd255;
        check_count(ref_count);

        // --- Test Case 7: Enable Toggle ---
        en = 0;
        @(posedge clk);
        #1;
        check_count(ref_count); // Should stay at 255

        en = 1;
        up = 1;
        @(posedge clk);
        #1;
        ref_count = ref_count + 1;
        check_count(ref_count);

        // --- Test Case 8: Asynchronous Reset during operation ---
        #5;
        rst_n = 0;
        #2; // Check immediate effect
        check_count(8'd0);
        ref_count = 8'd0;
        #10;
        rst_n = 1;
        @(posedge clk);
        #1;
        check_count(8'd0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
