module tb;
    reg clk;
    reg rst;
    reg din;
    wire detected;

    seqdet_moore uut (
        .clk(clk),
        .rst(rst),
        .din(din),
        .detected(detected)
    );

    integer passed, total;
    reg model_detected;
    reg [2:0] model_state;
    localparam S0 = 3'd0, S1 = 3'd1, S2 = 3'd2, S3 = 3'd3, S4 = 3'd4;

    // Reference Model
    // We use a combinational block to determine the NEXT state based on current state and input.
    // Then we use a sequential block to update the state and output on the clock edge.
    reg [2:0] next_state;
    always @(*) begin
        case (model_state)
            S0: next_state = din ? S1 : S0;
            S1: next_state = !din ? S2 : S1;
            S2: next_state = din ? S3 : S0;
            S3: next_state = din ? S4 : S2;
            S4: next_state = din ? S1 : S2;
            default: next_state = S0;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            model_state <= S0;
            model_detected <= 1'b0;
        end else begin
            model_state <= next_state;
            // Moore output is a function of the state reached after the edge
            if (next_state == S4) model_detected <= 1'b1;
            else                  model_detected <= 1'b0;
        end
    end

    task check;
        begin
            total = total + 1;
            if (detected !== model_detected) begin
                $display("FAIL: time=%0d expected=%b actual=%b din=%b rst=%b", $time, model_detected, detected, din, rst);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Initialize
        clk = 0;
        rst = 1;
        din = 0;
        passed = 0;
        total = 0;
        model_state = S0;
        model_detected = 0;

        // Reset sequence
        @(negedge clk);
        rst = 1;
        din = 0;
        @(posedge clk); #1; 
        
        if (detected !== 0) begin
            $display("FAIL: Reset failed. expected=0 actual=%b", detected);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end

        rst = 0;

        // Test Case 1: Simple pattern 1, 0, 1, 1
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S1
        @(negedge clk); din = 0; @(posedge clk); #1 check; // S2
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S3
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S4 (detected=1)

        // Test Case 2: Overlapping pattern 1, 0, 1, 1, 0, 1, 1
        @(negedge clk); din = 0; @(posedge clk); #1 check; // S2
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S3
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S4 (detected=1)

        // Test Case 3: Reset mid-sequence
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S1
        @(negedge clk); rst = 1; @(posedge clk); #1 check; // S0 (reset)
        rst = 0;

        // Test Case 4: No pattern
        @(negedge clk); din = 0; @(posedge clk); #1 check; // S0
        @(negedge clk); din = 0; @(posedge clk); #1 check; // S0
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S1
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S1

        // Test Case 5: Partial pattern then wrong bit (1010)
        @(negedge clk); din = 0; @(posedge clk); #1 check; // S2
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S3
        @(negedge clk); din = 0; @(posedge clk); #1 check; // S2

        // Final pattern to ensure we can recover (1011)
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S3
        @(negedge clk); din = 1; @(posedge clk); #1 check; // S4

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
