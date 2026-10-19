module tb();

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
                $display("FAIL: rst=%b, en=%b, count=%d | Expected: %d, Actual: %d", rst, en, expected, count);
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

        // Test Reset
        rst = 1;
        #10; // Rising edge
        check_val(4'd0);
        rst = 0;

        // Test Enable (Counting)
        en = 1;
        #10; // count: 1
        check_val(4'd1);
        #10; // count: 2
        check_val(4'd2);
        #10; // count: 3
        check_val(4'd3);

        // Test Disable (Hold)
        en = 0;
        #10; // count should stay 3
        check_val(4'd3);

        // Test Enable again
        en = 1;
        #10; // count: 4
        check_val(4'd4);

        // Test Reset priority over Enable
        rst = 1;
        en = 1;
        #10; // count should go to 0 despite en=1
        check_val(4'd0);
        rst = 0;

        // Test Wrap around (0 -> ... -> 15 -> 0)
        en = 1;
        // We are at 0. Let's skip ahead by counting manually or just loop.
        // To be efficient, let's just run a loop to reach 15.
        for (i = 1; i <= 15; i = i + 1) begin
            #10;
            check_val(i[3:0]);
        end
        
        // After 15, next should be 0
        #10;
        check_val(4'd0);

        // Final check on Disable at wrap point
        en = 0;
        #10; // count stays 0
        check_val(4'd0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
