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

    initial begin
        // Initialize
        clk = 0;
        rst_n = 1;
        en = 0;
        up = 1;
        passed = 0;
        total = 0;
        model = 8'h00;

        // Asynchronous Reset Test
        #7 rst_n = 0;
        #2; // Wait for async effect
        if (count !== 8'h00) begin
            $display("FAIL: time=%0d expected=0 actual=%h (async reset failed)", $time, count);
            total = total + 1; // Manual increment because model isn't updated yet
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        // Release Reset
        @(negedge clk);
        rst_n = 1;
        @(posedge clk); #1;
        check; // Check after reset release (model is 0)

        // Test: Enable=0, Count stays same
        @(negedge clk);
        en = 0; up = 1;
        @(posedge clk); #1; check;

        // Test: Up counting
        @(negedge clk);
        en = 1; up = 1;
        @(posedge clk); #1; check; // model should be 1
        @(posedge clk); #1; check; // model should be 2

        // Test: Down counting
        @(negedge clk);
        en = 1; up = 0;
        @(posedge clk); #1; check; // model should be 1
        @(posedge clk); #1; check; // model should be 0

        // Test: Wrap around (Up)
        @(negedge clk);
        en = 1; up = 1;
        model = 8'hFF; // Force model to FF for next cycle
        @(posedge clk); #1; check; // count should be 0, but we need to sync model correctly
        // Let's redo the wrap around logic carefully in a loop
        
        // Resetting model and starting sequence for wrap tests
        @(negedge clk);
        en = 1; up = 1;
        model = 8'hFF; // We are at 0, next is 1. Let's set model to FF so it expects 0.
        // Wait, the logic above: current count is 0. If en=1, up=1, next is 1.
        // Let's just use a loop for predictability.

        // Resetting state for clean wrap test
        @(negedge clk);
        rst_n = 0;
        @(negedge clk);
        rst_n = 1;
        en = 1; up = 1;
        model = 8'h00;
        @(posedge clk); #1; check; // count=1, model=1

        // Fast forward to 255
        repeat (254) begin
            @(negedge clk);
            model = model + 1;
            @(posedge clk); #1; check;
        end

        // Test Wrap Up: 255 -> 0
        @(negedge clk);
        en = 1; up = 1;
        model = 8'hFF; // model is currently 255, next edge makes it 0
        @(posedge clk); #1; check;

        // Test Wrap Down: 0 -> 255
        @(negedge clk);
        en = 1; up = 0;
        model = 8'h00; // model is currently 0, next edge makes it 255
        @(posedge clk); #1; check;

        // Test Enable Disable mid-count
        @(negedge clk);
        en = 0; up = 1;
        model = 8'hFF; // model is currently 255, next edge stays 255
        @(posedge clk); #1; check;

        // Test Async Reset during operation
        @(negedge clk);
        en = 1; up = 1;
        model = 8'h00; // model will be updated on posedge, but we trigger async mid-cycle
        @(posedge clk); #1; check; // count is now 1
        
        #3 rst_n = 0;
        #2;
        if (count !== 8'h00) begin
            $display("FAIL: time=%0d expected=0 actual=%h (async reset failed)", $time, count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    // Reference model logic
    always @(posedge clk) begin
        if (rst_n) begin
            if (en) begin
                if (up) model <= model + 1'b1;
                else     model <= model - 1'b1;
            end
        end else begin
            model <= 8'h00;
        end
    end

endmodule
```