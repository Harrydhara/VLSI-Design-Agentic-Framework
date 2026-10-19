```verilog
module updown8(
    input        clk,
    input        rst_n,
    input        en,
    input        up,
    output reg [7:0] count
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 8'h00;
        end else if (en) begin
            if (up) begin
                count <= count + 1'b1;
            end else begin
                count <= count - 1'b1;
            end
        end
    end

endmodule
```

```verilog
module tb;
    reg clk;
    reg rst_n;
    reg en;
    reg up;
    wire [7:0] count;

    integer passed, total;
    reg [7:0] model;

    updown8 dut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .up(up),
        .count(count)
    );

    always #5 clk = ~clk;

    task check;
        begin
            total = total + 1;
            if (count === model) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d expected=%h actual=%h en=%b up=%b", $time, model, count, en, up);
            end
        end
    endtask

    // The reference model must be updated on the same edges as the design.
    // For an asynchronous reset, we check it in the testbench logic manually or 
    // ensure the model follows the exact specification rules.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            model <= 8'h00;
        end else begin
            if (en) begin
                if (up) model <= model + 1'b1;
                else     model <= model - 1'b1;
            end else begin
                model <= model;
            end
        end
    end

    initial begin
        // Initialize
        clk = 0;
        rst_n = 1;
        en = 0;
        up = 1;
        passed = 0;
        total = 0;
        model = 8'h00;

        // Wait for clock to start
        @(negedge clk);

        // Test Asynchronous Reset
        rst_n = 0;
        #2; // Check async effect
        if (count !== 8'h00) begin
            $display("FAIL: time=%0d expected=00 actual=%h (async reset failed)", $time, count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        // Release Reset
        @(negedge clk);
        rst_n = 1;
        @(posedge clk); #1; check; // model is 0, count should be 0

        // Test: Enable=0, Count stays same
        @(negedge clk);
        en = 0; up = 1;
        @(posedge clk); #1; check;

        // Test: Up counting
        @(negedge clk);
        en = 1; up = 1;
        @(posedge clk); #1; check; // model=1, count=1
        @(posedge clk); #1; check; // model=2, count=2

        // Test: Down counting
        @(negedge clk);
        en = 1; up = 0;
        @(posedge clk); #1; check; // model=1, count=1
        @(posedge clk); #1; check; // model=0, count=0

        // Test: Wrap around (Up)
        @(negedge clk);
        en = 1; up = 1;
        // We are at 0. To test wrap, we need to get to 255.
        repeat (255) begin
            @(negedge clk);
            @(posedge clk); #1; check;
        end
        // Now count is 255. Next posedge with en=1, up=1 should be 0.
        @(posedge clk); #1; check;

        // Test: Wrap around (Down)
        @(negedge clk);
        en = 1; up = 0;
        // We are at 0. Next posedge with en=1, up=0 should be 255.
        @(posedge clk); #1; check;

        // Test: Enable Disable mid-count
        @(negedge clk);
        en = 0; up = 1;
        @(posedge clk); #1; check; // count stays at 255 (or whatever it was)

        // Test: Async Reset during operation
        @(negedge clk);
        en = 1; up = 1;
        @(posedge clk); #1; check; // incremented
        #3 rst_n = 0;
        #2;
        if (count !== 8'h00) begin
            $display("FAIL: time=%0d expected=00 actual=%h (async reset failed)", $time, count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        // Final cleanup for model sync before finishing
        @(negedge clk);
        rst_n = 1;
        @(posedge clk); #1; check;

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```