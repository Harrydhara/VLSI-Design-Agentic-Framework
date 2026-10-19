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

        // Wait for reset to take effect
        @(posedge clk);
        rst = 1;
        @(posedge clk);
        rst = 0;
        #1; // Small delay to ensure stable reading after edge
        check_val(4'd0);

        // Test Enable functionality (counting up)
        en = 1;
        repeat (5) begin
            @(posedge clk);
            #1;
            // We expect count to increment. Since we started at 0, 
            // after 5 increments it should be 5.
            // However, checking relative to previous state is safer.
        end
        // Let's do a more structured sequence
        
        // Reset during counting
        @(posedge clk);
        rst = 1;
        @(posedge clk);
        #1;
        check_val(4'd0);
        rst = 0;

        // Test Enable/Disable
        en = 1;
        @(posedge clk); // count becomes 1
        #1; check_val(4'd1);
        @(posedge clk); // count becomes 2
        #1; check_val(4'd2);

        en = 0;
        @(posedge clk); // count stays 2
        #1; check_val(4'd2);
        @(posedge clk); // count stays 2
        #1; check_val(4'd2);

        // Test Wrap around
        en = 1;
        // Current is 2. To get to 15, we need 13 more increments.
        // Let's just drive it to the end.
        repeat (13) @(posedge clk); // count becomes 15
        #1; check_val(4'd15);

        @(posedge clk); // wrap around: 15 -> 0
        #1; check_val(4'd0);

        // Test Reset priority over Enable
        en = 1;
        @(posedge clk); // count becomes 1
        #1; check_val(4'd1);
        rst = 1;
        @(posedge clk); // rst has priority, should be 0 even if en=1
        #1; check_val(4'd0);
        rst = 0;

        // Final sequence: full cycle
        en = 1;
        repeat (16) @(posedge clk); // Should go 0->1...->15->0
        #1; check_val(4'd0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```