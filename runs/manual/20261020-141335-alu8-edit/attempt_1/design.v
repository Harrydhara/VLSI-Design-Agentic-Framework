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

    // Intermediate signals for arithmetic
    wire [8:0] sum = a + b;
    wire [8:0] diff = a - {1'b0, b}; // Ensure subtraction is treated as 9-bit to capture borrow/carry logic correctly
    
    // Signed comparison for SLT
    wire signed [8:0] sa = {a[7], a};
    wire signed [8:0] sb = {b[7], b};

    always @(*) begin
        // Default values
        y_reg = 8'h00;
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
                y_reg = sum[7:0];
                carry_reg = sum[8];
                // Overflow: same sign inputs, different sign result
                overflow_reg = (a[7] == b[7]) && (sum[7] != a[7]);
            end
            3'b100: begin // SUB
                y_reg = a - b;
                // Carry for SUB: 1 if a >= b unsigned, else 0
                carry_reg = (a >= b);
                // Overflow: different sign inputs, result sign differs from 'a'
                overflow_reg = (a[7] != b[7]) && ((a - b) >> 7 != a[7]); // Simplified check for signed overflow in subtraction
                // Re-calculating overflow more robustly:
                // If a is pos, b is neg -> result must be pos. If result is neg, overflow.
                // If a is neg, b is pos -> result must be neg. If result is pos, overflow.
                if ((a[7] == 0 && b[7] == 1) && (y_reg[7] == 1)) overflow_reg = 1'b1;
                else if ((a[7] == 1 && b[7] == 0) && (y_reg[7] == 0)) overflow_reg = 1'b1;
                else overflow_reg = 1'b0;
            end
            3'b101: begin // SRA
                y_reg = {a[7], a[7:1]};
                carry_reg = a[0];
            end
            3'b110: begin // ROL
                y_reg = {a[6:0], a[7]};
                carry_reg = a[7];
            end
            3'b111: begin // SLT
                y_reg = (sa < sb) ? 8'h01 : 8'h00;
            end
            default: begin
                y_reg = 8'h00;
            end
        endcase
    end

    assign y = y_reg;
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign zero = (y == 8'h00);
    assign negative = y[7];

endmodule
