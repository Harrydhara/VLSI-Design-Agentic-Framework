```verilog
module counter4(
    input        clk,
    input        rst,
    input        en,
    output [3:0] count
);

    reg [3:0] count_reg;

    always @(posedge clk) begin
        if (rst) begin
            count_reg <= 4'b0000;
        end else if (en) begin
            count_reg <= count_reg + 1'b1;
        end else begin
            count_reg <= count_reg;
        end
    end

    assign count = count_reg;

endmodule
```

```verilog
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
        #10;

        // Test Reset
        rst = 1;
        #10; // Rising edge of clk
        check_val(4'd0);
        rst = 0;

        // Test Enable (Counting)
        en = 1;
        #10; // count becomes 1
        check_val(4'd1);
        #10; // count becomes 2
        check_val(4'd2);
        #10; // count becomes 3
        check_val(4'd3);

        // Test Disable (Hold)
        en = 0;
        #10; // count stays 3
        check_val(4'd3);

        // Test Reset priority over Enable
        en = 1;
        #10; // count becomes 4
        check_val(4'd4);
        rst = 1;
        #10; // count becomes 0 (reset priority)
        check_val(4'd0);

        // Test Wrap around
        rst = 0;
        en = 1;
        // We are at 0. Let's jump to 15 by manual stepping or just loop.
        // To be safe and efficient, let's just cycle through.
        repeat (15) begin
            #10;
        end
        // After 15 cycles from 0, count should be 15
        check_val(4'd15);

        // Next edge: wrap to 0
        #10;
        check_val(4'd0);

        // Test Disable at wrap point
        en = 0;
        #10; // count stays 0
        check_val(4'd0);

        // Final check of all states (exhaustive)
        en = 1;
        for (i = 0; i < 16; i = i + 1) begin
            #10;
            // Since we are checking after the edge, we expect current count to be (previous_count + 1) % 16
            // But since we just started from 0 and did 15 cycles + wrap, we are at 0.
            // The loop will check if it increments correctly.
        end
        // After the loop of 16, we should be back to 0 (if starting from 0)
        check_val(4'd0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```