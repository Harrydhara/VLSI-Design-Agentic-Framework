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
    reg [1:0] model_state;

    // Reference Model logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            model_state <= 2'b00;
        end else begin
            case (model_state)
                2'b00: if (din == 1'b1) model_state <= 2'b01; else model_state <= 2'b00;
                2'b01: if (din == 1'b1) model_state <= 2'b10; else model_state <= 2'b00;
                2'b10: if (din == 1'b0) model_state <= 2'b11; else model_state <= 2'b10;
                2'b11: if (din == 1'b1) model_state <= 2'b01; else model_state <= 2'b00;
                default: model_state <= 2'b00;
            endcase
        end
    end

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    task check_output;
        input expected;
        begin
            total = total + 1;
            if (detected !== expected) begin
                $display("FAIL: time=%0d din=%b model_state=%b expected=%b actual=%b", 
                         $time, din, model_state, expected, detected);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        // Initialize
        rst_n = 0;
        din = 0;
        #15 rst_n = 1;

        // Test Sequence: 1, 1, 0, 1 (Pattern 1)
        // Step 1: din=1. State was S0. After posedge, state becomes S1.
        @(negedge clk); din = 1; #1; // Check Mealy output before edge
        check_output(0); 
        @(posedge clk); #1;           // Wait for state update
        check_output(0);

        // Step 2: din=1. State was S1. After posedge, state becomes S2.
        @(negedge clk); din = 1; #1;
        check_output(0);
        @(posedge clk); #1;
        check_output(0);

        // Step 3: din=0. State was S2. After posedge, state becomes S3.
        @(negedge clk); din = 0; #1;
        check_output(0);
        @(posedge clk); #1;
        check_output(0);

        // Step 4: din=1. State was S3. Mealy output should be 1! After posedge, state becomes S1.
        @(negedge clk); din = 1; #1;
        check_output(1); // Mealy check (state is S3)
        @(posedge clk); #1;
        check_output(0); // State updated to S1

        // Test Overlap: 1, 1, 0, 1 -> we are at S1. Need 1, 0, 1 to complete again.
        // We already have the '1' from Step 4 (it was din=1).
        // Current state is S1. Next bit should be 1 to go to S2.
        @(negedge clk); din = 1; #1;
        check_output(0);
        @(posedge clk); #1;
        check_output(0); // State becomes S2

        // Now din=0 -> state becomes S3
        @(negedge clk); din = 0; #1;
        check_output(0);
        @(posedge clk); #1;
        check_output(0); // State becomes S3

        // Now din=1 -> Mealy output 1!
        @(negedge clk); din = 1; #1;
        check_output(1);
        @(posedge clk); #1;
        check_output(0);

        // Test Reset
        #10 rst_n = 0;
        #5 rst_n = 1;
        @(negedge clk); din = 1; #1;
        if (detected !== 0) $display("FAIL: Reset failed to clear output");
        else begin passed = passed + 1; total = total + 1; end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
