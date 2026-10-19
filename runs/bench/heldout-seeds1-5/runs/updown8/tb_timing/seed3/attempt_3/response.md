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

        // 1. Test Asynchronous Reset
        #3 rst_n = 0;
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
        // Wait for next posedge to check state
        @(posedge clk); #1 check; // count should be 0, model is 0

        // 2. Test Enable=0 (Hold value)
        @(negedge clk); en = 0; up = 1;
        @(posedge clk); #1 check; // model stays 0

        // 3. Test Up Counting
        @(negedge clk); en = 1; up = 1;
        model = model + 1'b1; // model: 0 -> 1
        @(posedge clk); #1 check;

        @(negedge clk); en = 1; up = 1;
        model = model + 1'b1; // model: 1 -> 2
        @(posedge clk); #1 check;

        // 4. Test Down Counting
        @(negedge clk); en = 1; up = 0;
        model = model - 1'b1; // model: 2 -> 1
        @(posedge clk); #1 check;

        // 5. Test Wrap Around Up (255 -> 0)
        // First, get to 255
        @(negedge clk); en = 1; up = 1;
        model = 8'hFF; // Set model so next edge makes it 0
        @(posedge clk); #1 check;
        model = 8'h00;

        // 6. Test Wrap Around Down (0 -> 255)
        @(negedge clk); en = 1; up = 0;
        model = 8'h00; // Set model so next edge makes it 255
        @(posedge clk); #1 check;
        model = 8'hFF;

        // 7. Test Enable=0 during wrap (Hold FF)
        @(negedge clk); en = 0; up = 1;
        // model stays at FF
        @(posedge clk); #1 check;

        // 8. Test Reset mid-cycle
        @(negedge clk); en = 1; up = 1;
        model = model + 1'b1; // model: FF -> 00 (wrap)
        @(posedge clk); #1 check;
        model = 8'h00;

        #3 rst_n = 0;
        #2;
        if (count !== 8'h00) begin
            $display("FAIL: time=%0d expected=0 actual=%h (async reset failed)", $time, count);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        #5 rst_n = 1;
        @(negedge clk); en = 1; up = 1;
        model = 8'h00; // Reset model to match design state after async reset
        @(posedge clk); #1 check; // count: 0 -> 1, model: 0 -> 1
        model = 8'h01;

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```