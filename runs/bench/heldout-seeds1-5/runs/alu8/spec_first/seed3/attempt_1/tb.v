module tb;
    // Inputs
    reg [7:0] a;
    reg [7:0] b;
    reg [2:0] op;

    // Outputs
    wire [7:0] y;
    wire zero;
    wire carry;
    wire overflow;
    wire negative;

    // Instantiate the Unit Under Test (UUT)
    alu8 uut (
        .a(a),
        .b(b),
        .op(op),
        .y(y),
        .zero(zero),
        .carry(carry),
        .overflow(overflow),
        .negative(negative)
    );

    integer i, j, k;
    integer passed;
    integer total;
    
    reg [7:0] exp_y;
    reg       exp_carry;
    reg       exp_overflow;
    reg       exp_zero;
    reg       exp_negative;

    initial begin
        passed = 0;
        total = 0;

        for (i = 0; i < 8; i = i + 1) begin
            op = i[2:0];
            for (j = 0; j < 256; j = j + 1) begin
                a = j[7:0];
                for (k = 0; k < 256; k = k + 1) begin
                    b = k[7:0];

                    // Reference Model
                    exp_y = 8'b0;
                    exp_carry = 1'b0;
                    exp_overflow = 1'b0;

                    case (op)
                        3'b000: begin // AND
                            exp_y = a & b;
                        end
                        3'b001: begin // OR
                            exp_y = a | b;
                        end
                        3'b010: begin // XOR
                            exp_y = a ^ b;
                        end
                        3'b011: begin // ADD
                            {exp_carry, exp_y} = a + b;
                        end
                        3'b100: begin // SUB
                            // carry: 1 when a >= b (unsigned), else 0
                            // y: a - b (low 8 bits)
                            exp_y = a - b;
                            if (a >= b) exp_carry = 1'b1;
                            else        exp_carry = 1'b0;
                            
                            // overflow: 1 when signs of a and b are different AND y sign differs from a
                            // Note: spec says "a and b have different sign bits" for SUB.
                            if (a[7] != b[7] && exp_y[7] != a[7])
                                exp_overflow = 1'b1;
                        end
                        3'b101: begin // SRA
                            // Arithmetic right shift by 1
                            exp_y = {a[7], a[7:1]};
                            exp_carry = a[0];
                        end
                        3'b110: begin // ROL
                            // Rotate left by 1
                            exp_y = {a[6:0], a[7]};
                            exp_carry = a[7];
                        end
                        3'b111: begin // SLT
                            // Signed comparison
                            if ($signed(a) < $signed(b))
                                exp_y = 8'd1;
                            else
                                exp_y = 8'd0;
                        end
                    endcase

                    // Special Overflow for ADD (not covered in case above)
                    if (op == 3'b011) begin
                        if (a[7] == b[7] && exp_y[7] != a[7])
                            exp_overflow = 1'b1;
                        else
                            exp_overflow = 1'b0;
                    end

                    // Special Overflow for other ops is already 0 by initialization
                    if (op != 3'b011 && op != 3'b100) begin
                        exp_overflow = 1'b0;
                    end

                    exp_zero = (exp_y == 8'b0);
                    exp_negative = exp_y[7];

                    // Wait for combinational logic to settle
                    #1;

                    total = total + 1;
                    if (y !== exp_y || zero !== exp_zero || carry !== exp_carry || 
                        overflow !== exp_overflow || negative !== exp_negative) begin
                        $display("FAIL: op=%b a=%d b=%d | exp: y=%d z=%b c=%b v=%b n=%b | act: y=%d z=%b c=%b v=%b n=%b",
                                 op, a, b, exp_y, exp_zero, exp_carry, exp_overflow, exp_negative,
                                 y, zero, carry, overflow, negative);
                    end else begin
                        passed = passed + 1;
                    end
                end
            end
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
