```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the pattern 1, 1, 0, 1
    // S0: Initial / Nothing found
    // S1: Found '1'
    // S2: Found '1, 1'
    // S3: Found '1, 1, 0'
    reg [1:0] state;

    localparam S0 = 2'b00;
    localparam S1 = 2'b01;
    localparam S2 = 2'b10;
    localparam S3 = 2'b11;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end else begin
            case (state)
                S0: begin
                    if (din == 1'b1) state <= S1;
                    else             state <= S0;
                end
                S1: begin
                    if (din == 1'b1) state <= S2;
                    else             state <= S0;
                end
                S2: begin
                    if (din == 1'b0) state <= S3;
                    else             state <= S2;
                end
                S3: begin
                    if (din == 1'b1) state <= S1;
                    else             state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Mealy output logic: detected is 1 if in S3 and din is 1.
    assign detected = (state == S3 && din == 1'b1);

endmodule
```

```verilog
module tb;
    reg clk;
    reg rst_n;
    reg din;
    wire detected;

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
        @(posedge clk); din <= 1; #1; check_val(0, 1); // S0 -> S1
        @(posedge clk); din <= 1; #1; check_val(0, 1); // S1 -> S2
        @(posedge clk); din <= 0; #1; check_val(0, 0); // S2 -> S3
        @(posedge clk); din <= 1; #1; check_val(1, 1); // S3 -> S1 (Detected!)

        // Test Case 2: Overlapping pattern 1, 1, 0, 1, 1, 0, 1
        rst_n = 0; #5 rst_n = 1; // Reset mid-cycle
        @(posedge clk); din <= 1; #1; check_val(0, 1); // S1
        @(posedge clk); din <= 1; #1; check_val(0, 1); // S2
        @(posedge clk); din <= 0; #1; check_val(0, 0); // S3
        @(posedge clk); din <= 1; #1; check_val(1, 1); // S1 (Detected!)
        @(posedge clk); din <= 1; #1; check_val(0, 1); // S2
        @(posedge clk); din <= 0; #1; check_val(0, 0); // S3
        @(posedge clk); din <= 1; #1; check_val(1, 1); // S1 (Detected!)

        // Test Case 3: Asynchronous Reset
        @(posedge clk); din <= 1; #1; // Move to some state
        #2 rst_n = 0;
        // Check internal state immediately after async reset
        if (uut.state !== 2'b00) begin
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
        
        // Current state is S3, din=0. detected should be 0.
        if (detected !== 0) begin
            $display("FAIL: Mealy output wrong at S3 with din=0");
            passed = passed - 1; total = total + 1;
        end else begin
            passed = passed + 1; total = total + 1;
        end

        // Change din to 1, detected should go high immediately before clock edge.
        din = 1; // Use blocking for immediate change in TB
        #0.1;    // Small delay to simulate combinational path
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
```