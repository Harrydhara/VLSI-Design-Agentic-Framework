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
        begin
            total = total + 1;
            if (count !== expected) begin
                $display("FAIL: rst_n=%b, en=%b, up=%b, count=%d, expected=%d, actual=%d", 
                         rst_n, en, up, count, expected, count);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
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

        // Test Asynchronous Reset (Initial state)
        #12; 
        if (count !== 8'h00) begin
            $display("FAIL: Async reset failed at start. count=%d", count);
            passed = passed - 1;
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        // Release Reset
        #5 rst_n = 1;
        @(posedge clk); // Wait for clock edge to ensure we are synchronized

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

        // Test Wrap Around Down (0 to 255)
        up = 0;
        en = 1;
        @(posedge clk); // count -> 255
        check_val(8'hFF);

        // Test Wrap Around Up (255 to 0)
        up = 1;
        @(posedge clk); // count -> 0
        check_val(8'h00);

        // Test multiple steps up
        up = 1;
        repeat(3) @(posedge clk); // 1, 2, 3
        check_val(8'h03);

        // Test Asynchronous Reset mid-cycle
        #3 rst_n = 0;
        if (count !== 8'h00) begin
            $display("FAIL: Async reset failed during operation. count=%d", count);
            passed = passed - 1;
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        #10 rst_n = 1;
        @(posedge clk); // Wait for clock edge to stabilize after reset release
        en = 1;
        up = 1;
        @(posedge clk); // count -> 1
        check_val(8'h01);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
