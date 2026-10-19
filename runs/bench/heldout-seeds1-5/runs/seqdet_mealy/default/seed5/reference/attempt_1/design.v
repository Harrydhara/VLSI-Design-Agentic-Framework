module seqdet_mealy(
    input   clk,
    input   rst_n,
    input   din,
    output  detected
);

    // State encoding for the sequence 1 -> 1 -> 0 (Mealy output on next 1)
    // S0: Idle / Reset
    // S1: Saw '1'
    // S2: Saw '1, 1'
    // S3: Saw '1, 1, 0'
    reg [1:0] state;

    localparam S0 = 2'd0;
    localparam S1 = 2'd1;
    localparam S2 = 2'd2;
    localparam S3 = 2'd3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S0;
        end else begin
            case (state)
                S0: begin
                    if (din) state <= S1;
                    else     state <= S0;
                end
                S1: begin
                    if (din) state <= S2;
                    else     state <= S0;
                end
                S2: begin
                    if (din) state <= S2; // Stay in S2 if 1,1,1... pattern continues? 
                                          // Wait, the sequence is 1,1,0,1.
                                          // If we have 1,1 and get another 1, we are still at "Saw 1,1"
                    else     state <= S3;
                end
                S3: begin
                    if (din) state <= S1; // Pattern 1,1,0,1 completed. Next bit could be start of new pattern.
                                          // If din=1, we have "1", so go to S1.
                    else     state <= S0;
                end
                default: state <= S0;
            endcase
        end
    end

    // Correcting State Machine Logic for Overlap and Transitions
    // Let's re-evaluate the states based on prefix matching:
    // S0: ""
    // S1: "1"
    // S2: "1, 1"
    // S3: "1, 1, 0"
    
    // Re-writing logic to be more robust for overlapping patterns.
    // If state is S2 (saw 1,1) and din=1 -> still saw 1,1 (S2).
    // If state is S3 (saw 1,1,0) and din=1 -> pattern detected! Next state? 
    // The sequence ends in '1'. That '1' can be the start of a new '1,1,0,1'. So go to S1.

    // Let's refine the transition logic inside the always block:
    /*
    S0 --(1)--> S1
    S0 --(0)--> S0
    S1 --(1)--> S2
    S1 --(0)--> S0
    S2 --(1)--> S2 (because 1,1,1 still contains the prefix 1,1)
    S2 --(0)--> S3
    S3 --(1)--> S1 (pattern complete, '1' is start of next)
    S3 --(0)--> S0
    */

    // Mealy output: detected = 1 if state == S3 AND din == 1.
    assign detected = (state == S3 && din == 1'b1);

endmodule
