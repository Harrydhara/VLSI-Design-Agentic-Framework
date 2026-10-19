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

    task reset_dut;
        begin
            rst_n = 0;
            en = 0;
            up = 1;
            model = 8'h00;
            #2; // Assert async reset
            if (count !== 8'h00) begin
                $display("FAIL: time=%0d expected=0 actual=%h (async reset failed)", $time, count);
                total = total + 1; // Manual increment for fatal error
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
            #5 rst_n = 1;
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 1;
        en = 0;
        up = 1;
        passed = 0;
        total = 0;

        reset_dut();

        // Test Case 1: Enable low, count stays 0
        @(negedge clk);
        en = 0; up = 1;
        @(posedge clk); #1 check;

        // Test Case 2: Up counting
        @(negedge clk);
        en = 1; up = 1;
        @(posedge clk); #1 model = model + 1; check;
        @(posedge clk); #1 model = model + 1; check;

        // Test Case 3: Down counting
        @(negedge clk);
        en = 1; up = 0;
        @(posedge clk); #1 model = model - 1; check;
        @(posedge clk); #1 model = model - 1; check;

        // Test Case 4: Enable low, hold value
        @(negedge clk);
        en = 0; up = 1;
        @(posedge clk); #1 check; // model stays same

        // Test Case 5: Wrap around Up (255 -> 0)
        @(negedge clk);
        en = 1; up = 1;
        // Force model to 255
        @(negedge clk);
        model = 8'hFF;
        // We need to sync the DUT. Since we can't force DUT, we just cycle until it hits FF or simulate logic.
        // Let's just use a controlled sequence.
        @(posedge clk); #1; // Sync

        // Test Case 6: Wrap around Down (0 -> 255)
        @(negedge clk);
        en = 1; up = 0;
        model = 8'h00;
        // To test wrap, we need to get the DUT to 0. It is already at some value.
        // Let's reset and do a clean sequence for wraps.
        reset_dut();

        // Clean Sequence for Wrap Up
        @(negedge clk);
        en = 1; up = 1;
        repeat (255) begin
            @(posedge clk); #1 model = model + 1; check;
        end
        // Now model is 0, count should be 0. Next cycle:
        @(posedge clk); #1 model = model + 1; check; // Should be 1

        // Clean Sequence for Wrap Down
        reset_dut();
        @(negedge clk);
        en = 1; up = 0;
        repeat (255) begin
            @(posedge clk); #1 model = model - 1; check;
        end
        // Now model is 0, count should be 0. Next cycle:
        @(posedge clk); #1 model = model - 1; check; // Should be 255

        // Test Case 7: Async reset during operation
        @(negedge clk);
        en = 1; up = 1;
        @(posedge clk); #1 model = model + 1; check;
        #3 rst_n = 0;
        #1;
        if (count !== 8'h00) begin
             $display("FAIL: time=%0d expected=0 actual=%h (async reset during op failed)", $time, count);
             total = total + 1;
        end else begin
             passed = passed + 1;
             total = total + 1;
        end
        #5 rst_n = 1;

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
