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

    // Internal signals for arithmetic operations
    wire [8:0] sum_res;
    wire [8:0] sub_res; // a - b as 9-bit signed/unsigned logic
    
    assign sum_res = a + b;
    // For subtraction, we use the property that a - b is equivalent to a + (~b) + 1
    // To get carry (no borrow), we check if a >= b.
    // In 9-bit math: a - b can be calculated as a + (256 - b). 
    // However, the requirement for SUB carry is "1 when a >= b unsigned".
    
    assign y = y_reg;
    assign zero = (y == 8'b0);
    assign negative = y[7];
    assign carry = carry_reg;
    assign overflow = overflow_reg;

    always @(*) begin
        // Default values to prevent latches
        y_reg = 8'b0;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // AND
                y_reg = a & b;
            end
            3'b001: begin // OR
                y_reg = a | b;
            end
            3'b010: begin // XOR
                y_reg = a ^ b;
            end
            3'b011: begin // ADD
                y_reg = sum_res[7:0];
                carry_reg = sum_res[8];
                // Overflow: same sign inputs, different sign result
                overflow_reg = (a[7] == b[7]) && (sum_res[7] != a[7]);
            end
            3'b100: begin // SUB
                y_reg = a - b;
                // Carry: 1 if a >= b unsigned, else 0
                carry_reg = (a >= b);
                // Overflow: different sign inputs, result sign differs from 'a'
                overflow_reg = (a[7] != b[7]) && (y_reg[7] != a[7]);
            end
            3'b101: begin // SRA
                y_reg = {a[7], a[7:1]};
                carry_reg = a[0];
            end
            3'b110: begin // ROL
                y_reg = {a[6:0], a[7]};
                carry_reg = a[7];
            end
            3'b111: begin // SLT (Signed)
                // Compare signed values. 
                // If a < b, y = 1, else 0.
                if ($signed(a) < $signed(b))
                    y_reg = 8'd1;
                else
                    y_reg = 8'd0;
            end
            default: begin
                y_reg = 8'b0;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
        endcase
    end

endmodule
