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
            total = total + 1; // Manual increment since we aren't in a cycle/check task
        end else begin
            // We don't use the standard check task for async reset to avoid model mismatch logic complexity
            // but we must ensure it counts towards passed if correct.
            // However, let's just follow the pattern:
            total = total + 1;
            passed = passed + 1;
        end

        @(negedge clk);
        rst_n = 1;
        model = 8'h00; // Reset state after rst_n goes high
        @(posedge clk); #1 check;

        // Test: Enable=0, Count stays same
        @(negedge clk); en = 0; up = 1;
        @(posedge clk); #1 check; // model is still 0

        // Test: Up counting
        @(negedge clk); en = 1; up = 1;
        @(posedge clk); #1 check; // model should be 1
        
        @(negedge clk); en = 1; up = 1;
        @(posedge clk); #1 check; // model should be 2

        // Test: Wrap around (Up)
        model = 8'hFF;
        @(negedge clk); en = 1; up = 1;
        // We need to force the model to match a specific state for wrap test
        // Let's just run it manually.
        @(posedge clk); #1; // sync with current count (2)
        
        // Fast forward to 255
        repeat(253) begin
            @(negedge clk); en = 1; up = 1;
            @(posedge clk); #1;
            // We need a way to update model correctly. Let's use the reference model logic.
        end
        // Re-writing test sequence for robustness...
    end

    // Corrected Testbench Logic using the requested skeleton style
    initial begin
        clk = 0;
        rst_n = 1;
        en = 0;
        up = 1;
        passed = 0;
        total = 0;
        model = 8'h00;

        // Reset
        #3 rst_n = 0;
        #2;
        if (count !== 8'h00) begin
            $display("FAIL: time=%0d expected=0 actual=%h", $time, count);
            total = total + 1;
        end else begin
            total = total + 1; passed = passed + 1;
        end
        rst_n = 1;

        // Reference model update logic
        // We'll use a task to drive inputs and the model simultaneously
        // This is safer.
    end

    // Redefining the test sequence inside a single block for clarity
    initial begin
        // Reset everything
        @(negedge clk);
        rst_n = 0;
        en = 0;
        up = 1;
        model = 8'h00;
        #2 rst_n = 1;
        // Wait for first posedge to sync model
        @(posedge clk); #1;
        if (count !== 8'h00) begin $display("FAIL: reset"); total++; end else begin passed++; total++; end

        // Test Enable=0
        @(negedge clk); en = 0; up = 1;
        @(posedge clk); #1;
        if (count !== 8'h00) begin $display("FAIL: en=0"); total++; end else begin passed++; total++; end

        // Test Up counting
        @(negedge clk); en = 1; up = 1; model = 8'h01;
        @(posedge clk); #1; check_val();

        @(negedge clk); en = 1; up = 1; model = 8'h02;
        @(posedge clk); #1; check_val();

        // Test Down counting
        @(negedge clk); en = 1; up = 0; model = 8'h01;
        @(posedge clk); #1; check_val();

        @(negedge clk); en = 1; up = 0; model = 8'h00;
        @(posedge clk); #1; check_val();

        // Test Wrap Around Down (0 -> 255)
        @(negedge clk); en = 1; up = 0; model = 8'hFF;
        @(posedge clk); #1; check_val();

        // Test Wrap Around Up (255 -> 0)
        @(negedge clk); en = 1; up = 1; model = 8'h00;
        @(posedge clk); #1; check_val();

        // Test Enable=0 during counting
        @(negedge clk); en = 1; up = 1; model = 8'h01;
        @(posedge clk); #1; check_val();
        @(negedge clk); en = 0; model = 8'h01;
        @(posedge clk); #1; check_val();

        // Test Async Reset while enabled
        #5 rst_n = 0;
        #2 rst_n = 1;
        if (count !== 8'h00) begin $display("FAIL: async reset"); total++; end else begin passed++; total++; end
        
        // Final wrap test for completeness
        @(negedge clk); en = 1; up = 1; model = 8'hFF;
        @(posedge clk); #1; check_val();
        @(negedge clk); en = 1; up = 1; model = 8'h00;
        @(posedge clk); #1; check_val();

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    task check_val;
        begin
            total = total + 1;
            if (count === model) passed = passed + 1;
            else $display("FAIL: time=%0d expected=%h actual=%h en=%b up=%b", $time, model, count, en, up);
        end
    endtask

endmodule
```

Wait, I see a mistake in my testbench logic (the `model` update and the manual `check_val`). Let me provide a clean, single-block version of the testbench that follows all rules perfectly.

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
        if (count === model) passed = passed + 1;
        else $display("FAIL: time=%0d expected=%h actual=%h en=%b up=%b", $time, model, count, en, up);
      end
    endtask

    // Reference model logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            model <= 8'h00;
        else if (en) begin
            if (up) model <= model + 1'b1;
            else    model <= model - 1'b1;
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

        // Wait for reset to be stable
        #10;

        // Test Asynchronous Reset
        rst_n = 0;
        #3;
        if (count !== 8'h00) begin
            $display("FAIL: time=%0d expected=0 actual=%h (async reset failed)", $time, count);
            total = total + 1;
        end else begin
            // We don't use check task here to avoid model mismatching the async timing
            total = total + 1; passed = passed + 1;
        end
        #2 rst_n = 1;
        @(posedge clk); #1; // Sync up
        check; // Check that we are at 0

        // Test: Enable=0, Count stays same
        @(negedge clk); en = 0; up = 1;
        @(posedge clk); #1 check;

        // Test: Up counting
        @(negedge clk); en = 1; up = 1;
        @(posedge clk); #1 check; // model should be 1
        
        @(negedge clk); en = 1; up = 1;
        @(posedge clk); #1 check; // model should be 2

        // Test: Down counting
        @(negedge clk); en = 1; up = 0;
        @(posedge clk); #1 check; // model should be 1

        // Test: Wrap around (Down)
        @(negedge clk); en = 1; up = 0;
        // Force model to 0 manually by running cycles? No, let's just use the logic.
        // To test wrap-around 0->255, we need count to be 0.
        // Let's drive it there.
        repeat(3) @(negedge clk); en = 1; up = 0; @(posedge clk); #1 check; // model will go 1 -> 0
        
        @(negedge clk); en = 1; up = 0; // now at 0, next should be 255
        @(posedge clk); #1 check;

        // Test: Wrap around (Up)
        @(negedge clk); en = 1; up = 1;
        repeat(255) begin
            @(negedge clk); en = 1; up = 1;
            @(posedge clk); #1 check;
        end
        // After 255 increments from 0, we should be at 255.
        // Then one more increment:
        @(negedge clk); en = 1; up = 1;
        @(posedge clk); #1 check; // model should be 0

        // Test: Enable=0 during counting
        @(negedge clk); en = 1; up = 1;
        @(posedge clk); #1 check; // count is now 1
        @(negedge clk); en = 0; up = 1;
        @(posedge clk); #1 check; // count should stay 1

        // Test: Async Reset while enabled
        @(negedge clk); en = 1; up = 1;
        @(posedge clk); #1 check; // count is now 2
        #7 rst_n = 0;
        #2;
        if (count !== 8'h00) begin
            $display("FAIL: time=%0d expected=0 actual=%h (async reset failed)", $time, count);
            total = total + 1;
        end else begin
            total = total + 1; passed = passed + 1;
        end
        rst_n = 1;

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```