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

    // Reference Model
    reg [3:0] model_count;
    always @(posedge clk) begin
        if (rst) begin
            model_count <= 4'b0000;
        end else if (en) begin
            model_count <= model_count + 1'b1;
        end else begin
            model_count <= model_count;
        end
    end

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    task check;
        begin
            total = total + 1;
            if (count === model_count) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d rst=%b en=%b expected=%d actual=%d", $time, rst, en, model_count, count);
            end
        end
    endtask

    task reset_dut;
        begin
            @(negedge clk);
            rst = 1;
            en = 0;
            @(posedge clk); #1;
            check;
            rst = 0;
        end
    endtask

    task apply_step(input rst_in, input en_in);
        begin
            @(negedge clk);
            rst = rst_in;
            en = en_in;
            @(posedge clk); #1;
            check;
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst = 0;
        en = 0;
        passed = 0;
        total = 0;
        model_count = 0;

        // 1. Reset the counter
        reset_dut();

        // 2. Test Enable functionality (counting up)
        apply_step(0, 1); // count should be 1
        apply_step(0, 1); // count should be 2
        apply_step(0, 1); // count should be 3
        apply_step(0, 1); // count should be 4

        // 3. Test Disable functionality (hold value)
        apply_step(0, 0); // count should stay 4
        apply_step(0, 0); // count should stay 4

        // 4. Test Wrap around
        // Current count is 4. Let's get to 15.
        // We need 11 more increments.
        repeat (11) begin
            apply_step(0, 1);
        end
        // After 11 steps: 4 + 11 = 15.
        // Next step should wrap to 0.
        apply_step(0, 1); // count should be 0

        // 5. Test Synchronous Reset priority over Enable
        apply_step(0, 1); // count becomes 1
        apply_step(1, 1); // rst=1 and en=1, rst has priority -> count becomes 0
        apply_step(0, 1); // count becomes 1

        // 6. Test Reset from middle of sequence
        apply_step(0, 1); // count 2
        apply_step(0, 1); // count 3
        apply_step(1, 0); // rst=1, en=0 -> count becomes 0
        apply_step(0, 0); // count stays 0

        // Final check of all tests
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```