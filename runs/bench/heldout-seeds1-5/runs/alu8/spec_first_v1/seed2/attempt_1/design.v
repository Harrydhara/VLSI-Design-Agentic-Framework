module alu8(
    input  [7:0] a,
    input  [7:0] b,
    input  [2:0] op,
    output [7:0] y,
    output       zero,
    output       carry,
    output       overflow,
    output       negative
);

    reg [7:0] y_reg;
    reg       carry_reg;
    reg       overflow_reg;

    // Internal wires for arithmetic operations
    wire [8:0] sum_res;
    wire [8:0] sub_res; // a - b as 9-bit signed/unsigned logic
    
    assign sum_res = a + b;
    // For subtraction, we use the property that a - b is equivalent to a + (~b) + 1
    // However, for carry (no borrow), it's easier to look at a >= b.
    // In unsigned math: a - b results in no borrow if a >= b.

    always @(*) begin
        // Default values
        y_reg = 8'b0;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // AND
                y_reg = a & b;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            3'b001: begin // OR
                y_reg = a | b;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            3'b010: begin // XOR
                y_reg = a ^ b;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            3'b011: begin // ADD
                y_reg = sum_res[7:0];
                carry_reg = sum_res[8];
                // Overflow: same sign inputs, different sign result
                if (a[7] == b[7]) begin
                    if (sum_res[7] != a[7])
                        overflow_reg = 1'b1;
                    else
                        overflow_reg = 1'b0;
                end else begin
                    overflow_reg = 1'b0;
                end
            end
            3'b100: begin // SUB
                y_reg = a - b;
                // Carry: 1 if a >= b (unsigned)
                carry_reg = (a >= b) ? 1'b1 : 1'b0;
                // Overflow: different sign inputs, result sign differs from 'a'
                // Note: subtraction is a + (-b). In signed terms, overflow occurs if 
                // signs of a and b are different AND the sign of (a-b) is not a[7].
                if (a[7] != b[7]) begin
                    if (y_reg[7] != a[7])
                        overflow_reg = 1'b1;
                    else
                        overflow_reg = 1'b0;
                end else begin
                    overflow_reg = 1'b0;
                end
            end
            3'b101: begin // SRA (Arithmetic Shift Right)
                y_reg = {a[7], a[7:1]};
                carry_reg = a[0];
                overflow_reg = 1'b0;
            end
            3'b110: begin // ROL (Rotate Left)
                y_reg = {a[6:0], a[7]};
                carry_reg = a[7];
                overflow_reg = 1'b0;
            end
            3'b111: begin // SLT (Set Less Than - Signed)
                // Compare signed values
                if ($signed(a) < $signed(b))
                    y_reg = 8'h01;
                else
                    y_reg = 8'h00;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            default: begin
                y_reg = 8'b0;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
        endcase
    end

    assign y = y_reg;
    assign zero = (y_reg == 8'b0);
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign negative = y_reg[7];

endmodule
