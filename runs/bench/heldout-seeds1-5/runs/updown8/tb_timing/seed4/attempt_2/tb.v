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
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        
        @(negedge clk);
        rst_n = 1;
        model = 8'h00;

        // Test Case 1: Enable=0, Count stays 0
        @(negedge clk);
        en = 0; up = 1;
        @(posedge clk); #1 check;

        // Test Case 2: Up counting
        @(negedge clk);
        en = 1; up = 1;
        @(posedge clk); #1 model = model + 1'b1; check;

        // Test Case 3: Wrap around (0 to 255)
        model = 8'hFF;
        @(negedge clk);
        en = 1; up = 1;
        @(posedge clk); #1 model = 8'h00; check;

        // Test Case 4: Down counting
        model = 8'h01;
        @(negedge clk);
        en = 1; up = 0;
        @(posedge clk); #1 model = 8'h00; check;

        // Test Case 5: Wrap around (0 to 255) down
        model = 8'h00;
        @(negedge clk);
        en = 1; up = 0;
        @(posedge clk); #1 model = 8'hFF; check;

        // Test Case 6: Enable=0, Count stays same
        model = 8'hFF;
        @(negedge clk);
        en = 0; up = 1;
        @(posedge clk); #1 model = 8'hFF; check;

        // Test Case 7: Async reset during operation
        @(negedge clk);
        en = 1; up = 1;
        @(posedge clk); #1 model = model + 1'b1; check;
        
        #3 rst_n = 0; 
        #1;
        if (count !== 8'h00) begin
             $display("FAIL: time=%0d expected=0 actual=%h (async reset failed)", $time, count);
             total = total + 1;
        end else begin
             passed = passed + 1;
             total = total + 1;
        end
        model = 8'h00;

        @(negedge clk);
        rst_n = 1;
        #1; // Wait for reset to clear

        // Final sequence of random-ish steps
        repeat (10) begin
            @(negedge clk);
            en = $random % 2;
            up = $random % 2;
            @(posedge clk); #1;
            if (en) begin
                if (up) model = model + 1'b1;
                else    model = model - 1'b1;
            end
            check;
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
