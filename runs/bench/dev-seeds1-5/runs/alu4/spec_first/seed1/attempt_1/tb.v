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

    // Reference Model and Verification Logic
    integer i, j;
    integer total_checks;
    integer passed_checks;
    
    reg [3:0] ref_y;
    reg ref_zero;
    reg ref_carry;
    reg ref_overflow;
    reg ref_negative;

    task check_result;
        input [3:0] cur_a;
        input [3:0] cur_b;
        input [2:0] cur_op;
        begin
            total_checks = total_checks + 1;
            if (y !== ref_y || zero !== ref_zero || carry !== ref_carry || 
                overflow !== ref_overflow || negative !== ref_negative) begin
                $display("FAIL: op=%b a=%d b=%d | Expected: y=%d z=%b c=%b v=%b n=%b | Actual: y=%d z=%b c=%b v=%b n=%b",
                    cur_op, cur_a, cur_b, ref_y, ref_zero, ref_carry, ref_overflow, ref_negative,
                    y, zero, carry, overflow, negative);
                passed_checks = passed_checks; // No increment
            end else begin
                passed_checks = passed_checks + 1;
            end
        end
    endtask

    initial begin
        total_checks = 0;
        passed_checks = 0;

        // Iterate through all possible input combinations
        for (i = 0; i < 8; i = i + 1) begin // op
            for (j = 0; j < 16; j = j + 1) begin // a
                for (integer k = 0; k < 16; k = k + 1) begin // b
                    a = j;
                    b = k;
                    op = i;

                    // Reference Model Calculation
                    case (op)
                        3'b000: begin // ADD
                            {ref_carry, ref_y} = a + b;
                            ref_overflow = (a[3] == b[3]) && (ref_y[3] != a[3]);
                        end
                        3'b001: begin // SUB
                            // Specification says carry is 1 when a >= b (unsigned)
                            // y = a - b (low 4 bits)
                            ref_y = a - b;
                            ref_carry = (a >= b);
                            // overflow: (a[3] != b[3]) && (y[3] != a[3])
                            ref_overflow = (a[3] != b[3]) && (ref_y[3] != a[3]);
                        end
                        3'b010: begin // AND
                            ref_y = a & b;
                            ref_carry = 0;
                            ref_overflow = 0;
                        end
                        3'b011: begin // OR
                            ref_y = a | b;
                            ref_carry = 0;
                            ref_overflow = 0;
                        end
                        3'b100: begin // XOR
                            ref_y = a ^ b;
                            ref_carry = 0;
                            ref_overflow = 0;
                        end
                        3'b101: begin // SHL
                            ref_y = {a[2:0], 1'b0};
                            ref_carry = a[3];
                            ref_overflow = 0;
                        end
                        3'b110: begin // SHR
                            ref_y = {1'b0, a[3:1]};
                            ref_carry = a[0];
                            ref_overflow = 0;
                        end
                        3'b111: begin // SLT (Signed)
                            // Convert to signed 4-bit
                            if ($signed(a) < $signed(b)) ref_y = 4'd1;
                            else ref_y = 4'd0;
                            ref_carry = 0;
                            ref_overflow = 0;
                        end
                        default: begin
                            ref_y = 0; ref_carry = 0; ref_overflow = 0;
                        end
                    endcase

                    // Common flags
                    ref_zero = (ref_y == 4'b0000);
                    ref_negative = ref_y[3];

                    #1; // Wait for combinational logic
                    check_result(a, b, op);
                end
            end
        end

        $display("RESULT: %0d/%0d passed", passed_checks, total_checks);
        $finish;
    end

endmodule
