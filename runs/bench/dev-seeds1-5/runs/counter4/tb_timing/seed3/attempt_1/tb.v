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

    task apply_step(input rst_val, input en_val);
        begin
            @(negedge clk);
            rst = rst_val;
            en = en_val;
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
        model_count = 4'b0000; // Initial state for model logic

        // 1. Reset the counter
        reset_dut();

        // 2. Test Enable functionality (counting up)
        apply_step(0, 1); // count: 1
        apply_step(0, 1); // count: 2
        apply_step(0, 1); // count: 3
        apply_step(0, 1); // count: 4
        apply_step(0, 1); // count: 5
        apply_step(0, 1); // count: 6
        apply_step(0, 1); // count: 7
        apply_step(0, 1); // count: 8
        apply_step(0, 1); // count: 9
        apply_step(0, 1); // count: 10
        apply_step(0, 1); // count: 11
        apply_step(0, 1); // count: 12
        apply_step(0, 1); // count: 13
        apply_step(0, 1); // count: 14
        apply_step(0, 1); // count: 15
        apply_step(0, 1); // count: 0 (wrap)

        // 3. Test Disable functionality (hold value)
        apply_step(0, 0); // count: 0
        apply_step(0, 0); // count: 0
        apply_step(0, 1); // count: 1
        apply_step(0, 0); // count: 1

        // 4. Test Reset priority over Enable
        apply_step(1, 1); // rst=1, en=1 -> count should be 0 (reset takes priority)
        apply_step(0, 1); // count: 1
        apply_step(0, 1); // count: 2

        // 5. Test Reset while counting
        apply_step(1, 0); // rst=1, en=0 -> count should be 0
        apply_step(0, 1); // count: 1

        // Final check of results
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
