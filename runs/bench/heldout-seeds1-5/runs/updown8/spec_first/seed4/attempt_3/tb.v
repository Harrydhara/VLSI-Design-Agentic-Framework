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
        #7; 
        rst_n = 0;
        // Check immediate effect of asynchronous reset
        if (count !== 8'd0) begin
            $display("FAIL: rst_n=0 | Expected: 0, Actual: %d", count);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end
        ref_count = 8'd0;

        #10;
        rst_n = 1;
        // Wait for a clock edge to ensure we are in a stable state
        @(posedge clk);
        #1; // Check after clock edge propagation
        if (count !== ref_count) begin
            $display("FAIL: rst_n=1 | Expected: %d, Actual: %d", ref_count, count);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end

        // --- Test Case 2: Enable (en=0) should hold value ---
        en = 0;
        up = 1;
        @(posedge clk);
        #1;
        if (count !== ref_count) begin
            $display("FAIL: en=0 | Expected: %d, Actual: %d", ref_count, count);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end

        // --- Test Case 3: Up Counting ---
        en = 1;
        up = 1;
        repeat (5) begin
            @(posedge clk);
            ref_count = ref_count + 1'b1;
            #1; // Wait for DUT to update
            if (count !== ref_count) begin
                $display("FAIL: en=1, up=1 | Expected: %d, Actual: %d", ref_count, count);
                passed = passed - 1; total = total + 1;
            end else begin
                passed = passed + 1; total = total + 1;
            end
        end

        // --- Test Case 4: Wrap Around Up ---
        // Force ref_count to 255 by manual assignment (simulating state)
        // Since we can't force the DUT easily without a reset, we count up.
        while (ref_count != 8'd255) begin
            @(posedge clk);
            ref_count = ref_count + 1'b1;
            #1;
            if (count !== ref_count) begin
                $display("FAIL: Up Count | Expected: %d, Actual: %d", ref_count, count);
                passed = passed - 1; total = total + 1;
            end else begin
                passed = passed + 1; total = total + 1;
            end
        end
        // Next edge should wrap to 0
        @(posedge clk);
        ref_count = 8'd0;
        #1;
        if (count !== ref_count) begin
            $display("FAIL: Wrap Up | Expected: %d, Actual: %d", ref_count, count);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end

        // --- Test Case 5: Down Counting ---
        en = 1;
        up = 0;
        repeat (5) begin
            @(posedge clk);
            ref_count = ref_count - 1'b1;
            #1;
            if (count !== ref_count) begin
                $display("FAIL: en=1, up=0 | Expected: %d, Actual: %d", ref_count, count);
                passed = passed - 1; total = total + 1;
            end else begin
                passed = passed + 1; total = total + 1;
            end
        end

        // --- Test Case 6: Wrap Around Down ---
        while (ref_count != 8'd0) begin
            @(posedge clk);
            ref_count = ref_count - 1'b1;
            #1;
            if (count !== ref_count) begin
                $display("FAIL: Down Count | Expected: %d, Actual: %d", ref_count, count);
                passed = passed - 1; total = total + 1;
            end else begin
                passed = passed + 1; total = total + 1;
            end
        end
        // Next edge should wrap to 255
        @(posedge clk);
        ref_count = 8'd255;
        #1;
        if (count !== ref_count) begin
            $display("FAIL: Wrap Down | Expected: %d, Actual: %d", ref_count, count);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end

        // --- Test Case 7: Reset during operation ---
        en = 1; up = 1;
        @(posedge clk); #1; ref_count = ref_count + 1; // Move away from 255
        #1; if (count !== ref_count) begin $display("FAIL: Sync"); passed=passed-1; total=total+1; end else begin passed=passed+1; total=total+1; end

        #2; 
        rst_n = 0;
        if (count !== 8'd0) begin
            $display("FAIL: Async Reset | Expected: 0, Actual: %d", count);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end
        ref_count = 8'd0;

        #10;
        rst_n = 1;
        @(posedge clk); #1;
        if (count !== ref_count) begin
            $display("FAIL: Post-Reset | Expected: %d, Actual: %d", ref_count, count);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
