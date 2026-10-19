module tb;
    reg clk;
    reg rst;
    reg din;
    wire detected;

    integer i;
    integer passed;
    integer total;

    seqdet_moore uut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    always #5 clk = ~clk;

    task check_bit(input expected_detected);
        begin
            @(posedge clk);
            // The output is Moore, so it reflects the state reached AFTER the edge.
            // However, the spec says: "detected is 1 during the clock cycle right after 
            // the rising edge at which the last four bits sampled... were 1,0,1,1".
            // In a synchronous design, if we sample din on posedge clk, the state updates
            // on that same posedge. The output 'detected' will be valid for the duration
            // of the cycle following that edge.
            #1; // Small delay to allow signal to settle after clock edge in simulation
            if (detected !== expected_detected) begin
                $display("FAIL: din=%b, rst=%b, expected detected=%b, actual detected=%b", 
                         din, rst, expected_detected, detected);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
            total = total + 1;
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst = 0;
        din = 0;
        passed = 0;
        total = 0;

        // Reset sequence
        @(posedge clk);
        rst = 1;
        din = 1; // din is ignored during reset edge
        #1;
        if (detected !== 0) begin
            $display("FAIL: rst=1, expected detected=0, actual detected=%b", detected);
            passed = passed - 1;
        end else begin
            passed = passed + 1;
        end
        total = total + 1;

        rst = 0;
        @(posedge clk); // State should be S0 now
        #1;
        if (detected !== 0) begin
            $display("FAIL: post-reset, expected detected=0, actual detected=%b", detected);
            passed = passed - 1;
        end else begin
            passed = passed + 1;
        end
        total = total + 1;

        // Test Pattern 1: 1, 0, 1, 1 (Standard)
        din = 1; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=1, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;
        din = 0; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=0, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;
        din = 1; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=1, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;
        din = 1; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=1, exp=1 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;

        // Test Pattern 2: Overlap 1, 0, 1, 1, 0, 1, 1
        // Current state is S4 (detected=1). Input sequence from here: 0, 1, 1
        din = 0; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=0, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;
        din = 1; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=1, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;
        din = 1; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=1, exp=1 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;

        // Test Pattern 3: Reset mid-sequence
        // Sequence: 1, 0, 1 (State S3)
        din = 1; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=1, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;
        din = 0; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=0, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;
        din = 1; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=1, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;
        // Reset
        rst = 1; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: rst=1, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;
        rst = 0; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: post-rst, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;

        // Test Pattern 4: All ones
        din = 1; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=1, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;
        din = 1; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=1, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;

        // Test Pattern 5: All zeros
        din = 0; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=0, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;
        din = 0; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=0, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;

        // Test Pattern 6: 1, 0, 1, 1 again
        din = 1; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=1, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;
        din = 0; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=0, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;
        din = 1; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=1, exp=0 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;
        din = 1; @(posedge clk); #1; if (detected != 0) begin $display("FAIL: din=1, exp=1 act=%b", detected); passed=passed-1; end else passed=passed+1; total=total+1;

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
