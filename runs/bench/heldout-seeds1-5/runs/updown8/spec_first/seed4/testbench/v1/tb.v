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

    // Task to check the output
    task check_output;
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
        #3; // Assert reset asynchronously (not on clock edge)
        check_output(8'd0);
        ref_count = 8'd0;
        
        #10;
        rst_n = 1;
        check_output(8'd0);

        // --- Test Case 2: Enable (en=0) should hold value ---
        en = 0;
        up = 1;
        #10; // One clock edge
        check_output(ref_count);

        // --- Test Case 3: Up Counting ---
        en = 1;
        up = 1;
        repeat (5) begin
            @(posedge clk);
            #1; // Wait for propagation
            ref_count = ref_count + 1'b1;
            check_output(ref_count);
        end

        // --- Test Case 4: Wrap Around Up ---
        // Force ref_count to 255
        ref_count = 8'd255;
        @(posedge clk);
        #1;
        ref_count = 8'd0;
        check_output(ref_count);

        // --- Test Case 5: Down Counting ---
        en = 1;
        up = 0;
        // Set ref to 2
        @(posedge clk); #1; ref_count = 8'd2;
        check_output(ref_count);

        @(posedge clk); #1;
        ref_count = 8'd1;
        check_output(ref_count);

        @(posedge clk); #1;
        ref_count = 8'd0;
        check_output(ref_count);

        // --- Test Case 6: Wrap Around Down ---
        @(posedge clk); #1;
        ref_count = 8'd255;
        check_output(ref_count); // Note: ref_count was already 255, next edge makes it 255? No.
        // Let's be precise:
        // Current state is count=0 (from previous step). 
        // We want to test 0 -> 255 transition.
        @(posedge clk); #1; // This clock edge triggers 0 -> 255 because en=1, up=0
        ref_count = 8'd255;
        check_output(ref_count);

        // --- Test Case 7: Reset during operation ---
        en = 1;
        up = 1;
        @(posedge clk); #1; ref_count = ref_count + 1;
        check_output(ref_count);
        
        #2; // Mid-cycle reset
        rst_n = 0;
        check_output(8'd0);
        ref_count = 8'd0;

        #10;
        rst_n = 1;
        check_output(8'd0);

        // --- Test Case 8: Enable toggle ---
        en = 1; up = 1;
        @(posedge clk); #1; ref_count = ref_count + 1; check_output(ref_count);
        en = 0;
        @(posedge clk); #1; check_output(ref_count); // Should stay same
        en = 1;
        @(posedge clk); #1; ref_count = ref_count + 1; check_output(ref_count);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
