module tb;
    reg clk;
    reg rst_n;
    reg din;
    wire detected;

    seqdet_mealy uut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .detected(detected)
    );

    integer passed = 0;
    integer total = 0;
    reg model_detected;
    reg [1:0] state_model;

    // Reference Model logic
    // The model must track the same state machine as the RTL to predict 'detected'
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_model <= 2'b00;
        end else begin
            case (state_model)
                2'b00: if (din) state_model <= 2'b01; else state_model <= 2'b00;
                2'b01: if (din) state_model <= 2'b10; else state_model <= 2'b00;
                2'b10: if (din) state_model <= 2'b10; else state_model <= 2'b11;
                2'b11: if (din) state_model <= 2'b01; else state_model <= 2'b00;
                default: state_model <= 2'b00;
            endcase
        end
    end

    // Mealy output model depends on the PREVIOUS state and current din
    // Because 'detected' is a Mealy output, it reacts to 'din' immediately.
    // In our testbench, we need to calculate what the output SHOULD be based on 
    // the state BEFORE the clock edge (the state currently held in the registers).
    // However, since the RTL uses 'state' which is updated at posedge clk, 
    // the Mealy output 'detected' depends on the state that was stable before the edge.
    
    // To correctly model a Mealy machine in a testbench:
    // The output is high if (current_state == S3 && din == 1).
    // In the RTL, 'state' is updated at posedge clk. So during the time between 
    // negedge and posedge, 'state' is the state from the previous cycle.
    
    reg [1:0] prev_state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) prev_state <= 2'b00;
        else prev_state <= state_model; // This is actually the state that will be active after posedge
    end

    // Since we are checking @(posedge clk); #1, the 'state' in RTL has already updated.
    // But for a Mealy machine, if din changes mid-cycle, detected changes immediately.
    // The specification says: "detected is 1 exactly when the last three bits sampled... were 1,1,0 and din is currently 1".
    // This means 'state' must be S3 (having seen 1,1,0) AND current din is 1.
    
    function reg get_model_detected(input reg [1:0] s, input reg d);
        begin
            get_model_detected = (s == 2'b11 && d == 1'b1);
        end
    endfunction

    task check;
        begin
            total = total + 1;
            // We need to know what the state was BEFORE the clock edge to determine Mealy output?
            // No, the specification says: "detected is 1 exactly when the last three bits sampled... were 1,1,0 and din is currently 1".
            // If we just saw 1,1,0, the state machine transitions to S3 at the posedge.
            // So at the moment 'din' becomes 1, if the state was already S3, detected goes high.
            
            // Let's use a more robust way: The RTL 'state' is updated at posedge clk.
            // If we are checking #1 after posedge clk, 'state' is the NEW state.
            // But for Mealy, if din=1 and state was S3, detected is 1.
            // Wait, if state was S3 and din becomes 1, the state transitions to S1 at the next edge.
            // The pattern 1-1-0-1:
            // T0: din=1 -> state becomes S1
            // T1: din=1 -> state becomes S2
            // T2: din=0 -> state becomes S3
            // T3: din=1 -> detected is 1, AND state becomes S1.
            
            // So at the moment of checking (after posedge clk), 'state' in RTL is the NEW state.
            // If we are in the middle of the pattern 1-1-0-1, and din=1:
            // Before edge: state=S3, din=1 => detected=1
            // After edge:  state=S1, din=1 => detected=0? No.
            // The Mealy output is a function of (current_state_from_prev_cycle, current_din).
            // Let's re-read: "detected is 1 exactly when the last three bits sampled... were 1,1,0 and din is currently 1".
            // This means if we just sampled '0' which moved us to S3, and now 'din' is 1, detected is 1.
            
            // Correct logic for Mealy check:
            // The RTL 'detected' output is `(state == S3 && din == 1)`.
            // At the time of checking (after posedge clk), 'state' has already transitioned to the NEXT state.
            // This means if we just completed the pattern, 'state' is now S1.
            // Therefore, the RTL `detected` will be 0 at the check point!
            // BUT, the Mealy output should have been 1 during the period when din was 1 and state was S3.
            // This implies we must check the Mealy output *before* or *at* the clock edge, 
            // OR the RTL design needs to be careful.
            // Actually, in a standard Mealy implementation:
            // `assign detected = (state == S3 && din);`
            // If state is S3 and din becomes 1, 'detected' goes high immediately.
            // At the next posedge clk, 'state' transitions to S1.
            // So 'detected' will go low at the same time 'state' transitions.
            // To catch the '1', we must check it when state is S3 and din is 1.
        end
    endtask

    // Redefining testbench approach:
    // We will track the expected Mealy output by looking at the state BEFORE the clock edge.
    reg expected_detected;
    reg [1:0] state_before_clk;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state_before_clk <= 2'b00;
        else state_before_clk <= state_model; // This is the state that was active during the cycle
    end

    // Because Mealy output depends on din, we must check it whenever din changes OR clk rises.
    // However, for simplicity in this testbench, we will check at the moment of transition.

    task check_mealy;
        begin
            total = total + 1;
            expected_detected = (state_before_clk == 2'b11 && din == 1'b1);
            if (detected !== expected_detected) begin
                $display("FAIL: time=%0d din=%b state_before=%b expected=%b actual=%b", 
                         $time, din, state_before_clk, expected_detected, detected);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    // Since it's Mealy, we check whenever din changes.
    always @(din) begin
        if (rst_n) begin
            #0; // wait for non-blocking to settle
            // We can't easily check here because of the race between 'state' and 'din'.
            // Let's use a simpler approach: 
            // The sequence is 1, 1, 0, 1.
            // We will manually drive din and check at every change.
        end
    end

    initial begin
        clk = 0;
        always #5 clk = ~clk;

        rst_n = 0;
        din = 0;
        #12 rst_n = 1; // Release reset

        // Test Case 1: Basic sequence 1, 1, 0, 1
        // We need to check 'detected' when din changes or at clock edges.
        // To be safe, we will use a task that drives din and checks immediately.
        
        drive_and_check(1); // S0 -> S1
        drive_and_check(1); // S1 -> S2
        drive_and_check(0); // S2 -> S3
        drive_and_check(1); // S3 + din=1 -> DETECTED! (S3 -> S1)
        
        // Test Case 2: Overlapping 1, 1, 0, 1, 1, 0, 1
        drive_and_check(1); // S1 -> S2
        drive_and_check(0); // S2 -> S3
        drive_and_check(1); // S3 + din=1 -> DETECTED! (S3 -> S1)
        drive_and_check(1); // S1 -> S2
        drive_and_check(0); // S2 -> S3
        drive_and_check(1); // S3 + din=1 -> DETECTED! (S3 -> S1)

        // Test Case 3: Reset during sequence
        drive_and_check(1); // S1
        drive_and_check(1); // S2
        #2 rst_n = 0;
        #2 rst_n = 1;
        drive_and_check(1); // Should be S1 again, not S2

        // Test Case 4: No pattern
        drive_and_check(0);
        drive_and_check(0);
        drive_and_check(1);
        drive_and_check(1);
        drive_and_check(1);
        drive_and_check(0);
        drive_and_check(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    task drive_and_check(input b);
        begin
            @(negedge clk);
            din = b;
            // Mealy output can change immediately when din changes.
            // We check it after a tiny delay to allow the combinational logic to settle.
            #0.1; 
            // The expected value is based on the state BEFORE this din was sampled.
            // But wait, 'state' in RTL only updates at posedge clk.
            // So during the time between negedge and posedge, 'state' is still the old state.
            if (detected !== (state_model == 2'b11 && b == 1'b1)) begin
                total = total + 1;
                $display("FAIL: time=%0d din=%b expected=%b actual=%b", $time, b, (state_model == 2'b11 && b == 1'b1), detected);
            end else begin
                passed = passed + 1;
                total = total + 1;
            end

            @(posedge clk);
            #1; // Wait for state to update and settle
            // After posedge, we check that the state updated correctly (optional)
            // but we don't need to check 'detected' here because it might have changed.
        end
    endtask

endmodule
