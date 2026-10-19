module tb;
    reg clk;
    reg rst_n;
    reg din;
    wire detected;

    integer i;
    integer passed;
    integer total;

    seqdet_mealy uut (
        .clk(clk),
        .rst_n(rst_n),
        .din(din),
        .detected(detected)
    );

    always #5 clk = ~clk;

    task check_val(input reg expected_det, input reg current_din);
        begin
            total = total + 1;
            if (detected !== expected_det) begin
                $display("FAIL: din=%b, expected detected=%b, actual detected=%b", current_din, expected_det, detected);
                passed = passed - 1;
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        // Initialize
        clk = 0;
        rst_n = 0;
        din = 0;
        passed = 0;
        total = 0;

        // Reset
        #12 rst_n = 1;
        
        // Test Case 1: Simple pattern 1, 1, 0, 1
        // We must check 'detected' as it changes with 'din' (Mealy)
        // and also after clock edges.
        
        // Sequence: 1, 1, 0, 1
        // Time: clk edge at 15, 25, 35, 45...
        
        // din = 1 (S0 -> S1)
        @(posedge clk); din <= 1; #1; check_val(0, 1);
        // din = 1 (S1 -> S2)
        @(posedge clk); din <= 1; #1; check_val(0, 1);
        // din = 0 (S2 -> S3)
        @(posedge clk); din <= 0; #1; check_val(0, 0);
        // din = 1 (S3 -> S1, Mealy output triggers here!)
        @(posedge clk); din <= 1; #1; check_val(1, 1);

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        // Current state is S1. We need 1, 0, 1 to complete another.
        // Wait, the sequence was 1, 1, 0, 1. The last '1' is the first bit of a potential new pattern.
        // To get 1, 1, 0, 1 again: we need din=1 (already done), then din=0 (no, that would be 1,1,0), 
        // let's just provide the full sequence manually to ensure overlap.
        
        // Reset for clean start
        rst_n = 0; #10 rst_n = 1;
        
        // Input: 1, 1, 0, 1, 1, 0, 1
        @(posedge clk); din <= 1; #1; check_val(0, 1); // S1
        @(posedge clk); din <= 1; #1; check_val(0, 1); // S2
        @(posedge clk); din <= 0; #1; check_val(0, 0); // S3
        @(posedge clk); din <= 1; #1; check_val(1, 1); // S1 (Detected!)
        @(posedge clk); din <= 1; #1; check_val(0, 1); // S2
        @(posedge clk); din <= 0; #1; check_val(0, 0); // S3
        @(posedge clk); din <= 1; #1; check_val(1, 1); // S1 (Detected!)

        // Test Case 3: Asynchronous Reset
        @(posedge clk); din <= 1; #1; // State moves
        #2 rst_n = 0;
        if (uut.state != 2'b00) begin
            $display("FAIL: Async reset failed, state=%b", uut.state);
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end
        #10 rst_n = 1;

        // Test Case 4: Mealy behavior (output changes immediately with din)
        // Get to S3
        @(posedge clk); din <= 1; #1; // S1
        @(posedge clk); din <= 1; #1; // S2
        @(posedge clk); din <= 0; #1; // S3
        // Now in S3, detected is 0 because din=0.
        if (detected !== 0) begin
            $display("FAIL: Mealy output wrong at S3 with din=0");
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end
        // Change din to 1, detected should go high immediately before clock edge.
        din <= 1;
        #0.1; // Small delay to simulate combinational path
        if (detected !== 1) begin
            $display("FAIL: Mealy output did not react immediately to din=1");
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
