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

    task step(input rst_in, input en_in);
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
        model_count = 4'b0000; // Initial state of model matches reset behavior

        // 1. Test Reset
        reset_dut();

        // 2. Test Enable and Counting
        step(0, 1); // count should be 1
        step(0, 1); // count should be 2
        step(0, 1); // count should be 3
        step(0, 1); // count should be 4
        step(0, 1); // count should be 5
        step(0, 1); // count should be 6
        step(0, 1); // count should be 7
        step(0, 1); // count should be 8
        step(0, 1); // count should be 9
        step(0, 1); // count should be 10
        step(0, 1); // count should be 11
        step(0, 1); // count should be 12
        step(0, 1); // count should be 13
        step(0, 1); // count should be 14
        step(0, 1); // count should be 15
        step(0, 1); // count should wrap to 0

        // 3. Test Disable (en=0)
        step(0, 0); // count stays 0
        step(0, 0); // count stays 0
        step(0, 1); // count becomes 1

        // 4. Test Reset Priority over Enable
        step(1, 1); // rst=1, en=1 -> count should be 0 (reset priority)
        step(0, 1); // rst=0, en=1 -> count should be 1
        
        // 5. Test Reset mid-count
        step(0, 1); // count 2
        step(0, 1); // count 3
        step(1, 0); // rst=1, en=0 -> count should be 0
        step(0, 1); // count 1

        // 6. Test Wrap around again with specific sequence
        step(0, 1); // 2
        step(0, 1); // 3
        step(0, 1); // 4
        step(0, 1); // 5
        step(0, 1); // 6
        step(0, 1); // 7
        step(0, 1); // 8
        step(0, 1); // 9
        step(0, 1); // 10
        step(0, 1); // 11
        step(0, 1); // 12
        step(0, 1); // 13
        step(0, 1); // 14
        step(0, 1); // 15
        step(0, 1); // 0

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```