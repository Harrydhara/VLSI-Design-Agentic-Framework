module tb;
    reg clk;
    reg rst_n;
    reg din;
    wire detected;

    seqdet_mealy dut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .detected(detected)
    );

    integer passed;
    integer total;
    reg [2:0] history; // Stores the last 3 bits sampled on clock edges

    always #5 clk = ~clk;

    // Reference model for Mealy output
    functionally_check();

    initial begin
        clk = 0;
        rst_n = 0;
        din = 0;
        history = 3'b000;
        passed = 0;
        total = 0;

        // Initial Reset
        #15 rst_n = 1;

        // Test Case: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // Bits: 1 (h:001), 1 (h:011), 0 (h:110), 1 (h:101, det=1), 1 (h:011), 0 (h:110), 1 (h:101, det=1)
        // Wait, the history logic is: if din=1 and last three were 1,1,0.
        // Let's trace carefully:
        // Edge 1: din=1 -> hist becomes 001
        // Edge 2: din=1 -> hist becomes 011
        // Edge 3: din=0 -> hist becomes 110
        // Edge 4: din=1 -> history is 110, din is 1 -> DETECTED!
        
        apply_bit(1); // h:001
        apply_bit(1); // h:011
        apply_bit(0); // h:110
        apply_bit(1); // h:101, det=1
        apply_bit(1); // h:011
        apply_bit(0); // h:110
        apply_bit(1); // h:101, det=1

        // Test Case: Reset mid-sequence
        apply_bit(1);
        apply_bit(1);
        #2 rst_n = 0; // Async reset
        #2 rst_n = 1;
        apply_bit(0);
        apply_bit(1);

        // Test Case: No pattern
        apply_bit(0);
        apply_bit(0);
        apply_bit(1);
        apply_bit(1);
        apply_bit(1);
        apply_bit(0);
        apply_bit(0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

    task apply_bit(input b);
    begin
        din = b;
        // Check Mealy output immediately on din change
        verify();
        @(posedge clk);
        history = {history[1:0], din};
        // Check after clock edge (state might have changed)
        verify();
    end
    endtask

    task verify();
    begin
        reg expected;
        expected = (history[2] == 1'b1 && history[1] == 1'b1 && history[0] == 1'b0 && din == 1'b1);
        if (detected !== expected) begin
            $display("FAIL: din=%b, hist=%b%b%b, exp=%b, act=%b", din, history[2], history[1], history[0], expected, detected);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
    end
    endtask

    // Monitor async reset
    always @(negedge rst_n) begin
        history = 3'b000;
        if (detected !== 1'b0) begin
            $display("FAIL: Async reset failed to clear detected. din=%b, det=%b", din, detected);
            total = total + 1;
        end else begin
            passed = passed + 1;
            total = total + 1;
        end
    end

endmodule
