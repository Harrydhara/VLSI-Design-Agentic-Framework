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

    integer passed;
    integer total;

    counter4 uut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .count(count)
    );

    reg [3:0] model;

    always #5 clk = ~clk;

    task check;
        begin
            total = total + 1;
            if (count === model) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d expected=%0d actual=%0d rst=%b en=%b", $time, model, count, rst, en);
            end
        end
    endtask

    // Reference model logic
    always @(posedge clk) begin
        if (rst) begin
            model <= 4'b0000;
        end else if (en) begin
            model <= model + 1'b1;
        end else begin
            model <= model;
        end
    end

    initial begin
        // Initialize
        clk = 0;
        rst = 0;
        en = 0;
        passed = 0;
        total = 0;
        model = 4'b0000; // Initial state for model

        // Apply asynchronous reset (though design is synchronous, we test the sync behavior)
        @(negedge clk);
        rst = 1;
        @(posedge clk); #1;
        check; // Check after first reset edge
        
        rst = 0;
        @(negedge clk); #1; // Wait for stability

        // Test Case 1: Enable is 0, count should stay 0
        en = 0;
        @(posedge clk); #1; check;

        // Test Case 2: Enable is 1, count increments
        en = 1;
        repeat (5) begin
            @(posedge clk); #1; check;
        end

        // Test Case 3: Disable, count should hold
        en = 0;
        @(posedge clk); #1; check;

        // Test Case 4: Enable again and wrap around
        en = 1;
        repeat (12) begin // 5 + 12 = 17. Since we were at 5, it should go 6...15, 0...6
            @(posedge clk); #1; check;
        end

        // Test Case 5: Reset priority over enable
        en = 1;
        @(posedge clk); #1; check; // Incrementing
        @(negedge clk);
        rst = 1;
        @(posedge clk); #1; check; // Should be 0 despite en=1

        // Test Case 6: Reset with enable high
        rst = 0;
        en = 1;
        @(posedge clk); #1; check; // Should increment from 0 to 1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```