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

    integer passed, total;
    reg model_detected;
    reg [1:0] model_state;

    // Reference Model
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            model_state <= 2'b00;
            model_detected <= 1'b0;
        end else begin
            // The model must calculate the output based on current state AND din (Mealy)
            // But for the testbench, we need to know what the state WILL be after this edge.
            // However, Mealy output is combinational. Let's simulate it carefully.
            case (model_state)
                2'b00: if (din == 1'b1) model_state <= 2'b01; else model_state <= 2'b00;
                2'b01: if (din == 1'b1) model_state <= 2'b10; else model_state <= 2'b00;
                2'b10: if (din == 1'b0) model_state <= 2'b11; else model_state <= 2'b10;
                2'b11: if (din == 1'b1) model_state <= 2'b01; else model_state <= 2'b00;
                default: model_state <= 2'b00;
            endcase
        end
    end

    // Because Mealy output is combinational, the 'model_detected' depends on current state and din.
    // We update it in a way that matches the RTL logic.
    always @(*) begin
        if (model_state == 2'b11 && din == 1'b1)
            model_detected = 1'b1;
        else
            model_detected = 1'b0;
    end

    // Since the model state updates on posedge, and Mealy output is combinational:
    // At any time t, detected = (state_at_t == S_110 && din_at_t == 1)
    // The testbench needs to track 'state' correctly.

    task check;
        begin
            total = total + 1;
            if (detected === model_detected) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d din=%b state_model=%b expected=%b actual=%b", 
                         $time, din, model_state, model_detected, detected);
            end
        end
    endtask

    // We need a way to track the "current" state of the model for comparison.
    // Since 'detected' is combinational, we check it whenever 'din' or 'state' changes.
    // But in a clocked testbench, we check after the clock edge.

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task reset_dut;
        begin
            rst_n = 0;
            din = 0;
            #2;
            rst_n = 1;
            // Reset model state too
            @(negedge clk);
            model_state = 2'b00;
            #1;
        end
    endtask

    task drive(input b);
        begin
            @(negedge clk);
            din = b;
            // Mealy output can change immediately when din changes.
            // However, the specification says "detected is 1 exactly when...".
            // In a Mealy machine, we check the combinational output.
            #1; 
            check;
        end
    endtask

    initial begin
        passed = 0;
        total = 0;
        reset_dut();

        // Test Case 1: Simple sequence 1, 1, 0, 1
        drive(1); // S0 -> S1
        drive(1); // S1 -> S2
        drive(0); // S2 -> S3
        drive(1); // S3 + din=1 -> detected=1, state becomes S1

        // Test Case 2: Overlapping sequence 1, 1, 0, 1, 1, 0, 1
        // We are currently at S1 (from the last drive).
        drive(1); // S1 -> S2
        drive(0); // S2 -> S3
        drive(1); // S3 + din=1 -> detected=1, state becomes S1
        
        // Test Case 3: No pattern
        reset_dut();
        drive(0);
        drive(1);
        drive(0);
        drive(0);
        drive(1);
        drive(1);

        // Test Case 4: Reset mid-sequence
        reset_dut();
        drive(1);
        drive(1);
        #2 rst_n = 0; #2 rst_n = 1; // Async reset
        // After reset, state should be S0. din is still 1 from previous drive? 
        // No, we must re-apply din after reset to check.
        drive(1); // Should start from S0 -> S1
        drive(0);
        drive(1);

        // Test Case 5: Multiple 1s in S2
        reset_dut();
        drive(1);
        drive(1);
        drive(1); // S2 stays S2
        drive(0); // S2 -> S3
        drive(1); // S3 + din=1 -> detected=1

        // Test Case 6: Sequence 1, 1, 0, 0
        reset_dut();
        drive(1);
        drive(1);
        drive(0);
        drive(0); // S3 -> S0
        drive(1); // S0 -> S1

        #10;
        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
