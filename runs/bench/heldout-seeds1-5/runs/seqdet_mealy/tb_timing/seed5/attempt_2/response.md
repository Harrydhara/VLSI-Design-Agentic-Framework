```verilog
module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    reg [1:0] state;
    parameter S0 = 2'b00; // Reset/Idle
    parameter S1 = 2'b01; // Saw 1
    parameter S2 = 2'b10; // Saw 1, 1
    parameter S3 = 2'b11; // Saw 1, 1, 0

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end else begin
            case (state)
                S0: state <= din ? S1 : S0;
                S1: state <= din ? S2 : S0;
                S2: state <= din ? S2 : S3;
                S3: state <= din ? S1 : S0;
                default: state <= S0;
            endcase
        end
    end

    assign detected = (state == S3 && din == 1'b1);

endmodule
```

```verilog
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
    reg model_detected;

    always #5 clk = ~clk;

    // Reference Model
    // The state updates on posedge. Mealy output depends on the state BEFORE the edge.
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            model_state <= 2'b00;
        end else begin
            case (model_state)
                2'b00: model_state <= din ? 2'b01 : 2'b00;
                2'b01: model_state <= din ? 2'b10 : 2'b00;
                2'b10: model_state <= din ? 2'b10 : 2'b11;
                2'b11: model_state <= din ? 2'b01 : 2'b00;
                default: model_state <= 2'b00;
            endcase
        end
    end

    always @(*) begin
        model_detected = (model_state == 2'b11 && din == 1'b1);
    end

    task check;
        begin
            total = total + 1;
            if (detected !== model_detected) begin
                $display("FAIL: time=%0d din=%b state=%b expected=%b actual=%b", $time, din, model_state, model_detected, detected);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    task drive(input b);
        begin
            @(negedge clk);
            din = b;
            #1; // Wait for combinational logic to settle
            check();
            @(posedge clk);
            #1; // Wait for state update
        end
    endtask

    initial begin
        clk = 0;
        rst_n = 0;
        din = 0;

        // Reset check
        #2 rst_n = 1;
        #1;
        if (detected !== 0) $display("FAIL: reset failed");
        else passed = passed + 1; // Manual increment for init check
        total = total + 1;

        // Pattern: 1, 1, 0, 1 (Detected at 4th bit)
        drive(1);
        drive(1);
        drive(0);
        drive(1); // Should detect

        // Overlap test: 1, 1, 0, 1, 1, 0, 1
        // Current state after last drive is S1. Next bits: 1, 0, 1
        drive(1);
        drive(0);
        drive(1); // Should detect

        // Another overlap check: 1, 1, 0, 1, 1, 0, 1 (Total sequence)
        // Reset and do full sequence
        #10 rst_n = 0; #5 rst_n = 1;
        drive(1); drive(1); drive(0); drive(1); // Detect 1
        drive(1); drive(0); drive(1);           // Detect 2

        // Corner case: continuous 1s
        #10 rst_n = 0; #5 rst_n = 1;
        drive(1); drive(1); drive(1); drive(1); // No detection

        // Corner case: reset mid-sequence
        drive(1); drive(1);
        #2 rst_n = 0;
        #2 rst_n = 1;
        drive(0); drive(1); // Should not detect because sequence was broken

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```