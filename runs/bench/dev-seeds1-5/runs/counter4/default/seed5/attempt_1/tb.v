module tb;

    reg clk;
    reg rst;
    reg en;
    wire [3:0] count;

    integer i;
    integer passed;
    integer total;

    counter4 uut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .count(count)
    );

    always #5 clk = ~clk;

    task check_val(input [3:0] expected);
        begin
            total = total + 1;
            if (count !== expected) begin
                $display("FAIL: rst=%b, en=%b, count=%d, expected=%d, actual=%d", rst, en, count, expected, count);
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
        passed = 0;
        total = 0;

        // Wait for a bit
        #15;

        // Test Reset (Synchronous)
        rst = 1;
        en = 1; // en is high, but rst has priority
        #10;
        check_val(4'd0);

        // Test Enable and Counting
        rst = 0;
        en = 1;
        #10; check_val(4'd1);
        #10; check_val(4'd2);
        #10; check_val(4'd3);

        // Test Disable (Hold value)
        en = 0;
        #10; check_val(4'd3);
        #10; check_val(4'd3);

        // Test Wrap around
        en = 1;
        // Current is 3. Need to get to 15.
        // 3 -> 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15 (12 more cycles)
        repeat (12) @(posedge clk);
        #1; // Small delay to allow non-blocking assignment to settle for check
        check_val(4'd15);

        // Wrap from 15 to 0
        #10;
        check_val(4'd0);

        // Test Reset mid-count
        en = 1;
        #10; // count is 1
        rst = 1;
        #10; // count should be 0
        check_val(4'd0);

        // Test priority: rst=1, en=1
        rst = 1;
        en = 1;
        #10;
        check_val(4'd0);

        // Final check of all states
        rst = 0;
        en = 1;
        repeat (16) @(posedge clk);
        #1;
        // After 16 increments from 0, it should be back to 0
        check_val(4'd0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
