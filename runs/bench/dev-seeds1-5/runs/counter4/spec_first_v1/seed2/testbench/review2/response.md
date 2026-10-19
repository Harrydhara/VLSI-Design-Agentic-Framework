```verilog
`timescale 1ns / 1ps

module tb;
    // Inputs
    reg clk;
    reg rst;
    reg en;

    // Outputs
    wire [3:0] count;

    // DUT instantiation
    counter4 uut (
        .clk(clk),
        .rst(rst),
        .en(en),
        .count(count)
    );

    // Reference Model State
    reg [3:0] ref_count;
    integer passed;
    integer total;

    // Clock generation
    always #5 clk = ~clk;

    // Task to check output
    // The specification says "On each rising edge of clk... count becomes..."
    // This means the value is updated at the edge. To verify this in a testbench, 
    // we must sample the output slightly AFTER the rising edge to avoid race conditions 
    // between the DUT update and the testbench sampling.
    task check_output;
        input [3:0] expected;
        begin
            total = total + 1;
            #1; // Small delay to allow DUT to update after posedge clk
            if (count !== expected) begin
                $display("FAIL: rst=%b, en=%b, Expected count=%d, Actual count=%d", rst, en, expected, count);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst = 0;
        en = 0;
        ref_count = 4'd0; // Initial value doesn't matter, but we track it
        passed = 0;
        total = 0;

        // Wait for a few cycles to stabilize
        repeat (2) @(posedge clk);

        // Test Case 1: Synchronous Reset
        rst = 1; en = 1;
        @(posedge clk);
        ref_count = 4'd0; 
        check_output(ref_count);

        // Test Case 2: Reset priority over Enable
        rst = 1; en = 1;
        @(posedge clk);
        ref_count = 4'd0;
        check_output(ref_count);

        // Test Case 3: Normal counting with Enable
        rst = 0; en = 1;
        @(posedge clk);
        ref_count = ref_count + 1;
        check_output(ref_count);

        @(posedge clk);
        ref_count = ref_count + 1;
        check_output(ref_count);

        // Test Case 4: Disable counting (en=0)
        rst = 0; en = 0;
        @(posedge clk);
        // ref_count stays same
        check_output(ref_count);

        @(posedge clk);
        check_output(ref_count);

        // Test Case 5: Re-enable and count towards wrap-around
        rst = 0; en = 1;
        
        // Resetting state for controlled wrap-around test
        rst = 1; @(posedge clk); ref_count = 4'd0; check_output(ref_count);
        rst = 0; en = 1;
        
        // Count up to 15
        repeat (15) begin
            @(posedge clk);
            ref_count = ref_count + 1;
            check_output(ref_count);
        end

        // Test Case 6: Wrap around from 15 to 0
        @(posedge clk);
        ref_count = 4'd0;
        check_output(ref_count);

        // Test Case 7: Reset while counting
        en = 1;
        @(posedge clk); // count becomes 1
        ref_count = ref_count + 1;
        check_output(ref_count);
        
        rst = 1;
        @(posedge clk); // count becomes 0
        ref_count = 4'd0;
        check_output(ref_count);

        // Test Case 8: Enable is 0, Reset is 1 (Reset priority)
        rst = 1; en = 0;
        @(posedge clk);
        ref_count = 4'd0;
        check_output(ref_count);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```