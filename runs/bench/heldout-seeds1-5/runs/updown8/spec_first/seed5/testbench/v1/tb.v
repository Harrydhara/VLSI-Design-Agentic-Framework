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
    reg [7:0] ref_count;
    integer passed;
    integer total;

    // Clock Generation
    always #5 clk = ~clk;

    // Helper task to check output
    task check_count;
        input [7:0] expected;
        begin
            total = total + 1;
            if (count !== expected) begin
                $display("FAIL: rst_n=%b, en=%b, up=%b | Expected count=%d, Actual count=%d", 
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
        #3; // Trigger reset mid-clock cycle
        check_count(8'd0);
        #5;
        rst_n = 1;
        check_count(8'd0);

        // --- Test Case 2: Enable/Disable and Up Counting ---
        en = 1; up = 1;
        @(posedge clk); // First edge after reset release
        ref_count = ref_count + 1;
        check_count(ref_count);

        @(posedge clk);
        ref_count = ref_count + 1;
        check_count(ref_count);

        en = 0; // Disable counting
        @(posedge clk);
        // ref_count stays same
        check_count(ref_count);

        en = 1; up = 1;
        @(posedge clk);
        ref_count = ref_count + 1;
        check_count(ref_count);

        // --- Test Case 3: Down Counting ---
        up = 0;
        @(posedge clk);
        ref_count = ref_count - 1;
        check_count(ref_count);

        // --- Test Case 4: Wrap Around (Up) ---
        en = 1; up = 1;
        // Force ref_count to 255
        ref_count = 8'd255;
        @(posedge clk);
        ref_count = 8'd0; // Wrap around logic: 255 + 1 = 0
        check_count(ref_count);

        // --- Test Case 5: Wrap Around (Down) ---
        en = 1; up = 0;
        // Force ref_count to 0
        ref_count = 8'd0;
        @(posedge clk);
        ref_count = 8'd255; // Wrap around logic: 0 - 1 = 255
        check_count(ref_count);

        // --- Test Case 6: Asynchronous Reset during operation ---
        en = 1; up = 1;
        @(posedge clk);
        ref_count = ref_count + 1;
        check_count(ref_count);
        
        #2 rst_n = 0; // Assert reset asynchronously
        check_count(8'd0);
        #10 rst_n = 1;
        check_count(8'd0);

        // --- Test Case 7: Multiple cycles of Enable/Disable ---
        en = 1; up = 1;
        repeat (5) begin
            @(posedge clk);
            ref_count = ref_count + 1;
            check_count(ref_count);
        end
        
        en = 0;
        repeat (3) begin
            @(posedge clk);
            // count should not change
            check_count(ref_count);
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
