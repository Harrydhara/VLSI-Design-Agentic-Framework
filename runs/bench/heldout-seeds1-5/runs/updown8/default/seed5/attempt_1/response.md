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
        #12; // Wait for some time while rst_n is low
        if (count !== 8'h00) begin
            $display("FAIL: Async reset failed. expected=0, actual=%d", count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        // Release Reset
        #5 rst_n = 1;
        @(posedge clk);
        check_val(8'h00); // Should stay 0 because en=0

        // Test Enable
        en = 1;
        up = 1;
        @(posedge clk);
        check_val(8'h01);
        @(posedge clk);
        check_val(8'h02);

        // Test Disable
        en = 0;
        @(posedge clk);
        check_val(8'h02); // Should hold value

        // Test Down counting
        en = 1;
        up = 0;
        @(posedge clk);
        check_val(8'h01);
        @(posedge clk);
        check_val(8'h00);

        // Test Wrap Around (Down)
        @(posedge clk);
        check_val(8'hFF);

        // Test Wrap Around (Up)
        up = 1;
        @(posedge clk);
        check_val(8'h00);

        // Test sequence to reach max
        en = 1;
        up = 1;
        repeat (254) @(posedge clk);
        check_val(8'hFF);

        // Wrap around Up again
        @(posedge clk);
        check_val(8'h00);

        // Test Asynchronous Reset during operation
        #3 rst_n = 0;
        if (count !== 8'h00) begin
            $display("FAIL: Async reset failed mid-count. expected=0, actual=%d", count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        #10 rst_n = 1;
        @(posedge clk);
        check_val(8'h00);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```