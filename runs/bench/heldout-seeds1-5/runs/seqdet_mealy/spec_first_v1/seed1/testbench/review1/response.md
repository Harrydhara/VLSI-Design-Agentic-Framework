```verilog
module tb;
    // Inputs
    reg clk;
    reg rst_n;
    reg din;

    // Outputs
    wire detected;

    // Instantiate the Design Under Test (DUT)
    seqdet_mealy dut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .detected(detected)
    );

    integer passed;
    integer total;
    // history[0] is the most recent bit sampled on a clock edge.
    // history[1] is the bit before that, etc.
    reg [2:0] history; 

    // Clock generation
    always #5 clk = ~clk;

    // Task to verify the output against the reference model
    task verify();
        reg expected;
        begin
            // Specification: "detected is 1 exactly when the last three bits sampled 
            // since the reset were 1, 1, 0 (oldest first) and din is currently 1"
            // If history[2] is oldest and history[0] is newest:
            // Sequence: history[2]=1, history[1]=1, history[0]=0.
            expected = (history[2] == 1'b1 && history[1] == 1'b1 && history[0] == 1'b0 && din == 1'b1);
            
            if (detected !== expected) begin
                $display("FAIL: din=%b, hist=%b%b%b, exp=%b, act=%b", 
                         din, history[2], history[1], history[0], expected, detected);
                total = total + 1;
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
        end
    endtask

    // Task to apply a bit and verify the Mealy output both before and after the clock edge
    task apply_bit(input b);
    begin
        din = b;
        // Check Mealy output immediately when din changes (Mealy property)
        verify();
        
        @(posedge clk);
        // Update history with the bit sampled on the rising edge.
        // The new bit becomes history[0], old history[0] becomes [1], etc.
        history = {history[1:0], din};
        
        // Check output again after state transition (Mealy can change based on new state + current din)
        verify();
    end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        din = 0;
        history = 3'b000;
        passed = 0;
        total = 0;

        // Reset sequence
        #15 rst_n = 1;

        // Test Case 1: Basic pattern 1, 1, 0, 1
        apply_bit(1); // hist becomes 001
        apply_bit(1); // hist becomes 011
        apply_bit(0); // hist becomes 110
        apply_bit(1); // hist is 110, din is 1 -> detected should be 1. After edge, hist=101

        // Test Case 2: Overlapping patterns (1, 1, 0, 1, 1, 0, 1)
        // Current history is 101. To get another 1101, we need to feed 1, 0, 1.
        apply_bit(1); // hist becomes 011
        apply_bit(0); // hist becomes 110
        apply_bit(1); // hist is 110, din is 1 -> detected should be 1. After edge, hist=101

        // Test Case 3: Reset during pattern
        apply_bit(1);
        apply_bit(1);
        #2 rst_n = 0; // Asynchronous reset
        #2 rst_n = 1;
        apply_bit(0);
        apply_bit(1);

        // Test Case 4: Random bits to ensure no false positives
        apply_bit(0);
        apply_bit(0);
        apply_bit(1);
        apply_bit(1);
        apply_bit(1);
        apply_bit(1);
        apply_bit(0);
        apply_bit(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    // Monitor for asynchronous reset impact on output and history
    always @(negedge rst_n) begin
        if (detected !== 1'b0) begin
            $display("FAIL: Async reset failed to clear detected. din=%b, det=%b", din, detected);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        history = 3'b000;
    end

endmodule
```