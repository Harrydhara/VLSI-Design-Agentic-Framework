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

    // Reference model state machine
    reg [1:0] model_state;
    reg model_detected;

    always #5 clk = ~clk;

    task check;
        begin
            total = total + 1;
            if (detected === model_detected) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d din=%b state=%b expected=%b actual=%b", 
                         $time, din, uut.state, model_detected, detected);
            end
        end
    endtask

    // The Mealy output depends on the current input and the previous state.
    // In our testbench, we must update the model's "expected" value 
    // whenever 'din' changes (combinational) OR when 'clk' rises (sequential).
    always @(*) begin
        model_detected = (model_state == 2'b11 && din == 1'b1);
    end

    // The model state updates on the clock edge, just like the RTL.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            model_state <= 2'b00;
        end else begin
            case (model_state)
                2'b00: if (din) model_state <= 2'b01; else model_state <= 2'b00;
                2'b01: if (din) model_state <= 2'b10; else model_state <= 2'b00;
                2'b10: if (din) model_state <= 2'b10; else model_state <= 2'b11;
                2'b11: if (din) model_state <= 2'b01; else model_state <= 2'b00;
                default: model_state <= 2'b00;
            endcase
        end
    end

    task reset;
        begin
            rst_n = 0;
            din = 0;
            model_state = 2'b00;
            model_detected = 0;
            #1;
            rst_n = 1;
            // Check after reset
            #1;
            if (detected !== 0 || uut.state !== 2'b00) begin
                $display("FAIL: Reset failed");
                total = total + 1; // Manual increment for reset failure
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
        end
    endtask

    task drive(input b);
        begin
            @(negedge clk);
            din = b;
            // Since it's Mealy, we check immediately after din changes
            #1;
            if (detected !== model_detected) begin
                $display("FAIL: time=%0d din=%b expected=%b actual=%b", $time, din, model_detected, detected);
                total = total + 1;
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
            // Then wait for the clock edge to transition state
            @(posedge clk);
            #1; // Check after state transition
            if (detected !== model_detected) begin
                 $display("FAIL: time=%0d din=%b expected=%b actual=%b", $time, din, model_detected, detected);
                 total = total + 1;
            end else begin
                passed = passed + 1;
                total = total + 1;
            end
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        din = 0;
        passed = 0;
        total = 0;

        reset;

        // Test Case 1: Simple pattern 1, 1, 0, 1
        drive(1); // S0 -> S1
        drive(1); // S1 -> S2
        drive(0); // S2 -> S3
        drive(1); // S3 -> S1 (detected should be 1)

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        reset;
        drive(1); // S0->S1
        drive(1); // S1->S2
        drive(0); // S2->S3
        drive(1); // S3->S1 (detected=1)
        drive(1); // S1->S2
        drive(0); // S2->S3
        drive(1); // S3->S1 (detected=1)

        // Test Case 3: No pattern
        reset;
        drive(0);
        drive(0);
        drive(1);
        drive(1);
        drive(1);
        drive(1);
        drive(0);
        drive(0);

        // Test Case 4: Reset mid-sequence
        reset;
        drive(1);
        drive(1);
        #2 rst_n = 0; #2 rst_n = 1; // Async reset
        if (uut.state !== 2'b00) $display("FAIL: Async reset failed");
        else begin passed = passed + 1; total = total + 1; end

        // Test Case 5: Pattern with extra 1s in middle (1, 1, 1, 0, 1)
        reset;
        drive(1);
        drive(1);
        drive(1); // S2 -> S2
        drive(0); // S2 -> S3
        drive(1); // S3 -> S1 (detected=1)

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
