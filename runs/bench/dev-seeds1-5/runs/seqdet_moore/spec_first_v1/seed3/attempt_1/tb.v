module tb;
    reg clk;
    reg rst;
    reg din;
    wire detected;

    // Instantiate the Design Under Test (DUT)
    seqdet_moore dut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    // Reference Model State Variables
    reg [3:0] ref_history;
    integer ref_len;
    integer passed;
    integer total;

    // Clock generation
    always #5 clk = ~clk;

    // Task to apply a bit and check the output immediately after the rising edge.
    // The specification states: 
    // "detected is 1 during the clock cycle right after the rising edge at which 
    // the last four bits sampled since the reset were 1, 0, 1, 1"
    // This means we check 'detected' in the time interval between the current 
    // rising edge and the next.
    task apply_bit(input b);
        begin
            din = b;
            @(posedge clk);
            // The synchronous reset logic: "on a rising edge with rst = 1... 
            // the detector forgets every bit sampled so far... The bit on din at that edge is ignored."
            if (rst) begin
                ref_history = 4'b0000;
                ref_len = 0;
            end else begin
                // Shift in the new bit. We use a temporary variable to ensure 
                // we are calculating based on the state transition.
                ref_history = {ref_history[2:0], b};
                if (ref_len < 4) 
                    ref_len = ref_len + 1;
                else 
                    ref_len = 4;
            end

            // Moore output depends only on the state. After the edge, the DUT is in a new state.
            // We check if that state corresponds to having seen 1,0,1,1 as the last 4 bits.
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
        // Initialize
        clk = 0;
        rst = 0;
        din = 0;
        passed = 0;
        total = 0;
        ref_history = 4'b0000;
        ref_len = 0;

        // Test Case 1: Basic pattern 1, 0, 1, 1
        reset_dut();
        apply_bit(1); // hist 1, len 1
        apply_bit(0); // hist 10, len 2
        apply_bit(1); // hist 101, len 3
        apply_bit(1); // hist 1011, len 4 -> detected=1

        // Test Case 2: Overlapping patterns 1, 0, 1, 1, 0, 1, 1
        reset_dut();
        apply_bit(1); apply_bit(0); apply_bit(1); apply_bit(1); // detected=1
        apply_bit(0); // hist 0110, len 4 -> detected=0
        apply_bit(1); // hist 1101, len 4 -> detected=0
        apply_bit(1); // hist 1011, len 4 -> detected=1

        // Test Case 3: Reset mid-pattern
        reset_dut();
        apply_bit(1); apply_bit(0); apply_bit(1); 
        @(posedge clk); rst = 1; din = 1; // Synchronous reset at edge, din ignored
        @(posedge clk); rst = 0; din = 0; // State is now cleared
        apply_bit(1); apply_bit(0); apply_bit(1); apply_bit(1); // detected=1

        // Test Case 4: No pattern/Random bits
        reset_dut();
        apply_bit(0); apply_bit(1); apply_bit(1); apply_bit(1); apply_bit(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
