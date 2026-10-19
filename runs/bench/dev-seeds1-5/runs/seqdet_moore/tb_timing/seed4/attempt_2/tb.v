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
    reg [2:0] ref_state;
    reg ref_det;

    // Reference Model logic
    // The model must update on the same clock edges as the design.
    always @(posedge clk) begin
        if (rst) begin
            ref_state <= 3'd0;
            ref_det   <= 1'b0;
        end else begin
            case (ref_state)
                3'd0: if (din) ref_state <= 3'd1; else ref_state <= 3'd0;
                3'd1: if (!din) ref_state <= 3'd2; else ref_state <= 3'd1;
                3'd2: if (din) ref_state <= 3'd3; else ref_state <= 3'd0;
                3'd3: if (din) ref_state <= 3'd4; else ref_state <= 3'd2;
                3'd4: if (din) ref_state <= 3'd1; else ref_state <= 3'd2;
                default: ref_state <= 3'd0;
            endcase
            // Moore output is based on the state we just entered.
            // We use a temporary variable or logic to determine what the next ref_det will be.
        end
    end

    // To correctly model Moore output, we need to know the state AFTER the edge.
    // Since 'detected' is combinational from 'state', we calculate it based on the new state.
    always @(posedge clk) begin
        if (rst) begin
            ref_det <= 1'b0;
        end else begin
            // We look at what ref_state will be after this edge to determine ref_det
            // However, in Verilog non-blocking assignments, we can just use the logic:
            // The state is updated, and then detected is evaluated. 
            // To match 'detected' (which is combinational from 'state'), 
            // our model should reflect the output of the new state.
        end
    end

    // Let's rewrite the reference model to be extremely clear:
    reg [2:0] next_ref_state;
    always @(*) begin
        case (ref_state)
            3'd0: if (din) next_ref_state = 3'd1; else next_ref_state = 3'd0;
            3'd1: if (!din) next_ref_state = 3'd2; else next_ref_state = 3'd1;
            3'd2: if (din) next_ref_state = 3'd3; else next_ref_state = 3'd0;
            3'd3: if (din) next_ref_state = 3'd4; else next_ref_state = 3'd2;
            3'd4: if (din) next_ref_state = 3'd1; else next_ref_state = 3'd2;
            default: next_ref_state = 3'd0;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            ref_state <= 3'd0;
            ref_det   <= 1'b0;
        end else begin
            ref_state <= next_ref_state;
            ref_det   <= (next_ref_state == 3'd4);
        end
    end

    task check;
        begin
            total = total + 1;
            if (detected === ref_det) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d din=%b expected=%b actual=%b", $time, din, ref_det, detected);
            end
        end
    endtask

    task drive_bit(input b);
        begin
            @(negedge clk);
            din = b;
            @(posedge clk);
            #1 check;
        end
    endtask

    initial begin
        // Clock generation
        clk = 0;
        forever #5 clk = ~clk;
    end

    initial begin
        // Initialize
        rst = 1;
        din = 0;
        passed = 0;
        total = 0;
        ref_state = 3'd0;
        ref_det = 1'b0;

        // Synchronous Reset: apply at a rising edge
        @(posedge clk);
        rst = 1;
        @(posedge clk);
        #1; // Check reset state
        total = total + 1;
        if (detected === 1'b0) passed = passed + 1;
        else $display("FAIL: Reset failed");
        
        rst = 0;

        // Test Pattern: 1, 0, 1, 1 (Detected!)
        drive_bit(1);
        drive_bit(0);
        drive_bit(1);
        drive_bit(1); // Should detect here

        // Test Overlap: 1, 0, 1, 1, 0, 1, 1 (Detected at 4th and 7th)
        // Current state is S4. Next bits are 0, 1, 1.
        drive_bit(0); // State becomes S2
        drive_bit(1); // State becomes S3
        drive_bit(1); // State becomes S4 (Detected!)

        // Test Reset mid-sequence: 1, 0, (rst), 1, 1
        drive_bit(1); // State becomes S1
        drive_bit(0); // State becomes S2
        @(negedge clk); rst = 1;
        @(posedge clk); #1;
        total = total + 1;
        if (detected === 1'b0) passed = passed + 1;
        else $display("FAIL: Reset mid-sequence failed");
        rst = 0;

        drive_bit(1);
        drive_bit(1); // Should not detect

        // Test sequence with no matches
        drive_bit(0);
        drive_bit(0);
        drive_bit(0);
        drive_bit(1);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
