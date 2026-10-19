module tb;
    // Inputs
    reg [3:0] a;
    reg [3:0] b;
    reg [2:0] op;

    // Outputs
    wire [3:0] y;
    wire zero;
    wire carry;
    wire overflow;
    wire negative;

    // Instantiate the Unit Under Test (UUT)
    alu4 uut (
        .a(a),
        .b(b),
        .op(op),
        .y(y),
        .zero(zero),
        .carry(carry),
        .overflow(overflow),
        .negative(negative)
    );

    // Verification variables
    integer i, j;
    reg [4:0] expected_sum;
    reg [3:0] expected_y;
    reg expected_carry;
    reg expected_overflow;
    reg expected_zero;
    reg expected_negative;
    
    integer passed;
    integer total;

    task check_result;
        begin
            expected_y = uut.y; // Just to use the name in error reporting if needed, but we calculate locally
            // We actually calculate expectations based on inputs and op
            // The task is called after inputs are applied. 
            // Since it's combinational, we must wait a tiny bit or just check immediately.
            #1; 
            
            expected_zero = (expected_y == 4'b0000);
            expected_negative = expected_y[3];

            if (y !== expected_y || zero !== expected_zero || carry !== expected_carry || 
                overflow !== expected_overflow || negative !== expected_negative) begin
                $display("FAIL: op=%b a=%d b=%d | Expected: y=%d z=%b c=%b v=%b n=%b | Actual: y=%d z=%b c=%b v=%b n=%b",
                    op, a, b, expected_y, expected_zero, expected_carry, expected_overflow, expected_negative,
                    y, zero, carry, overflow, negative);
                total = total + 1; // This is actually handled by the logic below
            end else begin
                passed = passed + 1;
            end
            total = total + 1;
        end
    endtask

    // Re-defining task to be cleaner for the loop
    task verify(input [3:0] ta, input [3:0] tb_val, input [2:0] top, 
                input [3:0] ty, input tcarry, input tov, input tzero, input tneg);
        begin
            if (y !== ty || zero !== tzero || carry !== tcarry || overflow !== tov || negative !== tneg) begin
                $display("FAIL: op=%b a=%d b=%d | Expected: y=%h z=%b c=%b v=%b n=%b | Actual: y=%h z=%b c=%b v=%b n=%b",
                    top, ta, tb_val, ty, tzero, tcarry, tov, tneg, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
            total = total + 1;
        end
    endtask

    initial begin
        // Initialize
        a = 0; b = 0; op = 0;
        passed = 0;
        total = 0;

        // Test all combinations of a, b, and op
        for (i = 0; i < 8; i = i + 1) begin // op
            op = i;
            for (j = 0; j < 16; j = j + 1) begin // a
                a = j;
                for (integer k = 0; k < 16; k = k + 1) begin // b
                    b = k;

                    // Reference Model
                    case (op)
                        3'b000: begin // ADD
                            expected_sum = a + b;
                            expected_y = expected_sum[3:0];
                            expected_carry = expected_sum[4];
                            expected_overflow = (a[3] == b[3]) && (expected_y[3] != a[3]);
                        end
                        3'b001: begin // SUB
                            // Spec: carry is 1 when a >= b (unsigned)
                            // y is low 4 bits of a - b. In Verilog, subtraction handles this.
                            expected_y = a - b;
                            expected_carry = (a >= b);
                            expected_overflow = (a[3] != b[3]) && (expected_y[3] != a[3]);
                        end
                        3'b010: begin // AND
                            expected_y = a & b;
                            expected_carry = 0;
                            expected_overflow = 0;
                        end
                        3'b011: begin // OR
                            expected_y = a | b;
                            expected_carry = 0;
                            expected_overflow = 0;
                        end
                        3'b100: begin // XOR
                            expected_y = a ^ b;
                            expected_carry = 0;
                            expected_overflow = 0;
                        end
                        3'b101: begin // SHL
                            expected_y = {a[2:0], 1'b0};
                            expected_carry = a[3];
                            expected_overflow = 0;
                        end
                        3'b110: begin // SHR
                            expected_y = {1'b0, a[3:1]};
                            expected_carry = a[0];
                            expected_overflow = 0;
                        end
                        3'b111: begin // SLT (Signed)
                            // Convert to signed for comparison
                            if ($signed(a) < $signed(b)) expected_y = 4'd1;
                            else expected_y = 4'd0;
                            expected_carry = 0;
                            expected_overflow = 0;
                        end
                    endcase

                    expected_zero = (expected_y == 4'b0);
                    expected_negative = expected_y[3];

                    // Apply inputs and check
                    #1; // Wait for combinational logic
                    verify(a, b, op, expected_y, expected_carry, expected_overflow, expected_zero, expected_negative);
                end
            end
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
