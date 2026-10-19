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

    reg [3:0] ref_history;
    integer ref_len;
    integer passed;
    integer total;

    always #5 clk = ~clk;

    task apply_bit(input b);
        begin
            din = b;
            @(posedge clk);
            // The synchronous reset happens at the edge. 
            // If rst was high at the rising edge, history is cleared and din ignored.
            if (rst) begin
                ref_history = 4'b0000;
                ref_len = 0;
            end else begin
                ref_history = {ref_history[2:0], b};
                if (ref_len < 4) ref_len = ref_len + 1;
                else ref_len = 4;
            end

            // Moore output is based on the state reached AFTER the edge.
            // We check 'detected' immediately after the edge.
            total = total + 1;
            if (ref_len == 4 && ref_history == 4'b1011) begin
                if (detected !== 1'b1) begin
                    $display("FAIL: din=%b, rst=%b, expected=1, actual=%b", b, rst, detected);
                end else begin
                    passed = passed + 1;
                end
            end else begin
                if (detected !== 1'b0) begin
                    $display("FAIL: din=%b, rst=%b, expected=0, actual=%b", b, rst, detected);
                end else begin
                    passed = passed + 1;
                end
            end
        end
    endtask

    task reset_dut();
        begin
            @(posedge clk);
            rst = 1; din = 0;
            @(posedge clk);
            rst = 0; din = 0;
            ref_history = 4'b0000;
            ref_len = 0;
        end
    endtask

    initial begin
        clk = 0; rst = 0; din = 0;
        passed = 0; total = 0;
        ref_history = 4'b0000; ref_len = 0;

        // Test Case 1: Simple pattern
        reset_dut();
        apply_bit(1); apply_bit(0); apply_bit(1); apply_bit(1); // Should detect

        // Test Case 2: Overlapping patterns (1,0,1,1,0,1,1)
        reset_dut();
        apply_bit(1); apply_bit(0); apply_bit(1); apply_bit(1); // Detects
        apply_bit(0); apply_bit(1); apply_bit(1);             // Detects again

        // Test Case 3: Reset mid-pattern
        reset_dut();
        apply_bit(1); apply_bit(0); apply_bit(1); // History 101
        @(posedge clk); rst = 1; din = 1;         // Reset edge (din ignored)
        @(posedge clk); rst = 0; din = 0;         // After reset, history is empty
        apply_bit(1); apply_bit(0); apply_bit(1); apply_bit(1); // Detects

        // Test Case 4: No pattern
        reset_dut();
        apply_bit(0); apply_bit(1); apply_bit(1); apply_bit(1); apply_bit(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
