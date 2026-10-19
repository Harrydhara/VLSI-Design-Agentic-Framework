module tb;
    reg clk;
    reg rst_n;
    reg en;
    reg up;
    wire [7:0] count;

    integer passed;
    integer total;

    updown8 uut (
        .clk(clk),
        .rst_n(rst_n),
        .en(en),
        .up(up),
        .count(count)
    );

    always #5 clk = ~clk;

    task check_val(input [7:0] expected);
        total = total + 1;
        if (count !== expected) begin
            $display("FAIL: rst_n=%b, en=%b, up=%b, expected=%d, actual=%d", rst_n, en, up, expected, count);
            passed = passed + 0;
        end else begin
            passed = passed + 1;
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        en = 0;
        up = 1;
        passed = 0;
        total = 0;

        // Test Asynchronous Reset
        #12; // Wait for some time
        if (count !== 8'h00) begin
            $display("FAIL: Async reset failed. Expected 0, got %d", count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        // Release Reset
        #5 rst_n = 1;
        @(posedge clk); // Wait for clock edge

        // Test Enable=0 (Hold value)
        en = 0;
        up = 1;
        @(posedge clk);
        check_val(8'h00);

        // Test Up Counting
        en = 1;
        up = 1;
        @(posedge clk); // count -> 1
        check_val(8'h01);
        @(posedge clk); // count -> 2
        check_val(8'h02);

        // Test Down Counting
        up = 0;
        @(posedge clk); // count -> 1
        check_val(8'h01);
        @(posedge clk); // count -> 0
        check_val(8'h00);

        // Test Wrap Around (Down)
        up = 0;
        en = 1;
        @(posedge clk); // count -> 255
        check_val(8'hFF);

        // Test Wrap Around (Up)
        up = 1;
        @(posedge clk); // count -> 0
        check_val(8'h00);
        
        // Move to a known state for overflow test
        // We need to get to 255. Let's just loop or set it if we could, 
        // but we must use the RTL logic.
        // Let's count up to 255 manually via simulation speed (not ideal but works)
        // Or better: check that after 255 increments from 0, it is 255.
        en = 1;
        up = 1;
        repeat (255) @(posedge clk);
        check_val(8'hFF);
        @(posedge clk); // Wrap to 0
        check_val(8'h00);

        // Test Asynchronous Reset during operation
        #3 rst_n = 0;
        if (count !== 8'h00) begin
            $display("FAIL: Async reset failed mid-count. Expected 0, got %d", count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        #10 rst_n = 1;
        @(posedge clk);
        en = 0;
        check_val(8'h00);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
