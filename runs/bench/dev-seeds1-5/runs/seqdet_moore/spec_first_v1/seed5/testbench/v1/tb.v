module tb;
    reg clk;
    reg rst;
    reg din;
    wire detected;

    seqdet_moore dut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    integer passed;
    integer total;
    
    // Reference Model variables
    reg [3:0] ref_history;
    integer history_len;
    reg expected_det;

    initial begin
        clk = 0;
        rst = 0;
        din = 0;
        passed = 0;
        total = 0;
        ref_history = 4'b0000;
        history_len = 0;
        expected_det = 0;

        // Reset the system
        @(posedge clk);
        rst = 1;
        din = 0;
        @(posedge clk);
        #1; // Wait for sync reset to take effect
        rst = 0;
        history_len = 0;
        ref_history = 4'b0000;
        expected_det = 0;

        // Test sequence: 1, 0, 1, 1 (Detection)
        apply_input(1);
        apply_input(0);
        apply_input(1);
        apply_input(1); // Detected here

        // Test sequence: Overlap 1, 0, 1, 1, 0, 1, 1 (Detection at 4th and 7th)
        // Current state is end of 1011. Next bits are 0, 1, 1
        apply_input(0);
        apply_input(1);
        apply_input(1); // Detected here

        // Test sequence: Reset mid-pattern
        apply_input(1);
        apply_input(0);
        @(posedge clk);
        #1;
        rst = 1;
        din = 1; // This bit should be ignored per spec
        @(posedge clk);
        #1;
        rst = 0;
        history_len = 0;
        ref_history = 4'b0000;
        expected_det = 0;

        // After reset, start pattern again
        apply_input(1);
        apply_input(0);
        apply_input(1);
        apply_input(1); // Detected here

        // Test sequence: No detection (1, 1, 1, 1)
        apply_input(1);
        apply_input(1);
        apply_input(1);
        apply_input(1);

        // Test sequence: Pattern with extra bits at start (0, 1, 0, 1, 1)
        apply_input(0);
        apply_input(1);
        apply_input(0);
        apply_input(1);
        apply_input(1); // Detected here

        #50;
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    task apply_input(input b);
        begin
            din = b;
            @(posedge clk);
            // The bit is sampled on the rising edge. 
            // We update our reference model immediately after the edge.
            if (rst) begin
                history_len = 0;
                ref_history = 4'b0000;
                expected_det = 0;
            end else begin
                history_len = history_len + 1;
                if (history_len > 4) history_len = 4;
                ref_history = {ref_history[2:0], b};
                
                if (history_len == 4 && ref_history == 4'b1011)
                    expected_det = 1;
                else
                    expected_det = 0;
            end

            // Check the output. Since it is Moore, 'detected' should be stable 
            // and reflect the state reached after the edge.
            #1; // Small delay to allow DUT to update its output
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, rst=%b, expected detected=%b, actual detected=%b", b, rst, expected_det, detected);
                total = total + 1;
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
        end
    endtask

    always #5 clk = ~clk;

endmodule
