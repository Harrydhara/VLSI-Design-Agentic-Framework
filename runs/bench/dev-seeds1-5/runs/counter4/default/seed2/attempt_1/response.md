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
        #15;

        // Test Reset
        rst = 1;
        #10; // Rising edge
        check_val(4'd0);
        rst = 0;

        // Test Enable (Counting)
        en = 1;
        #10; check_val(4'd1);
        #10; check_val(4'd2);
        #10; check_val(4'd3);
        #10; check_val(4'd4);

        // Test Disable (Hold value)
        en = 0;
        #10; check_val(4'd4);
        #10; check_val(4'd4);

        // Test Reset priority over Enable
        en = 1;
        #10; // count becomes 5
        check_val(4'd5);
        rst = 1;
        #10; // reset takes priority, count should be 0 even though en=1
        check_val(4'd0);
        rst = 0;

        // Test Wrap around
        en = 1;
        // Current count is 0. Need to get to 15.
        // We are at 0, so we need 15 more cycles.
        repeat (15) @(posedge clk);
        #1; // Wait for non-blocking assignment to settle
        check_val(4'd15);

        #10; // One more cycle to wrap
        check_val(4'd0);

        // Final check of all bits/patterns
        en = 1;
        repeat (15) @(posedge clk);
        #1;
        check_val(4'd15);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```