`timescale 1ns/1ps
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

    // Reference Model State
    // history[0] is bit n-1, history[1] is bit n-2, history[2] is bit n-3
    reg [2:0] history; 
    integer passed;
    integer total;

    // Clock generation
    always #5 clk = ~clk;

    // Function to calculate expected Mealy output based on history and current din
    function detected_ref;
        input [2:0] hist;
        input d;
        begin
            // Pattern is 1, 1, 0 followed by current 1.
            // Sequence order (oldest first): hist[2], hist[1], hist[0], d
            if (hist[2] == 1'b1 && hist[1] == 1'b1 && hist[0] == 1'b0 && d == 1'b1)
                detected_ref = 1'b1;
            else
                detected_ref = 1'b0;
        end
    endfunction

    // Task to verify the current output against expected value
    task check_output;
        input expected;
        begin
            if (detected !== expected) begin
                $display("FAIL: din=%b, rst_n=%b, history=%b, expected detected=%b, actual detected=%b", 
                         din, rst_n, history, expected, detected);
            end else begin
                passed = passed + 1;
            end
            total = total + 1;
        end
    endtask

    // Task to apply a bit synchronously and check Mealy behavior
    task apply_bit;
        input b;
        begin
            din = b;
            // Check Mealy output immediately after din change (combinational)
            check_output(detected_ref(history, din));
            
            @(posedge clk);
            // After clock edge, update history for the next cycle
            // The bit 'b' that was sampled at this rising edge becomes history[0]
            history = {history[1:0], b}; 
            // Wait a tiny amount to ensure we aren't checking during transition
            #0.1; 
            // Check output again after state update (Mealy depends on new history and current din)
            check_output(detected_ref(history, din));
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

        // Asynchronous Reset Test
        #12 rst_n = 1;
        
        // Test Case 1: Overlapping patterns (1, 1, 0, 1, 1, 0, 1)
        // Expected detections at bit 4 and bit 7.
        apply_bit(1); // hist becomes 001
        apply_bit(1); // hist becomes 011
        apply_bit(0); // hist becomes 110
        apply_bit(1); // hist becomes 101, detected should be 1 (4th bit)
        apply_bit(1); // hist becomes 011 (wait, history logic: {hist[1:0], b})
                      // Let's trace carefully:
                      // start: 000
                      // apply 1: din=1, check det(000,1)=0. edge. hist=001. check det(001,1)=0.
                      // apply 1: din=1, check det(001,1)=0. edge. hist=011. check det(011,1)=0.
                      // apply 0: din=0, check det(011,0)=0. edge. hist=110. check det(110,0)=0.
                      // apply 1: din=1, check det(110,1)=1. edge. hist=101. check det(101,1)=0. (Correct!)
        apply_bit(1); // hist becomes 011
        apply_bit(0); // hist becomes 110
        apply_bit(1); // hist becomes 101, detected should be 1 (7th bit)

        // Test Case 2: Reset mid-sequence
        apply_bit(1);
        apply_bit(1);
        #3 rst_n = 0;
        // Check immediate reset effect on output
        if (detected !== 1'b0) begin
            $display("FAIL: din=%b, rst_n=%b, history=%b, expected detected=0, actual detected=%b", 
                     din, rst_n, history, detected);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
        history = 3'b000; // Reset ref model
        #5 rst_n = 1;

        // Test Case 3: Mealy behavior (change din without clock)
        apply_bit(1);
        apply_bit(1);
        apply_bit(0);
        // History is now 110. If we set din=1, detected should go high immediately.
        din = 1;
        #1; // Wait for combinational propagation
        check_output(detected_ref(history, din));
        
        // Change din back to 0, detected must go low immediately.
        din = 0;
        #1;
        check_output(detected_ref(history, din));

        // Sync with clock to finish the bit and update history
        @(posedge clk);
        #0.1;
        history = {history[1:0], din};
        check_output(detected_ref(history, din));

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
