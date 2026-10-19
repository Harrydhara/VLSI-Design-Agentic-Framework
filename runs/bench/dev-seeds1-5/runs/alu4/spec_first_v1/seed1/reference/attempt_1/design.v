module alu4(
    input  [3:0] a,
    input  [3:0] b,
    input  [2:0] op,
    output [3:0] y,
    output       zero,
    output       carry,
    output       overflow,
    output       negative
);

    reg [3:0] y_reg;
    reg       carry_reg;
    reg       overflow_reg;

    // Intermediate signals for calculation
    wire [4:0] sum_add = a + b;
    wire [4:0] sub_val = a - b; // Note: subtraction in 2's complement logic
    // For SUB, carry is defined as (a >= b) unsigned.
    // In 5-bit math, a - b is equivalent to a + (~b + 1).
    // The prompt says "carry is 1 exactly when a >= b".
    
    always @(*) begin
        // Default values to prevent latches
        y_reg = 4'b0000;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // ADD
                y_reg = sum_add[3:0];
                carry_reg = sum_add[4];
                // Overflow for signed addition: (a[3] == b[3]) && (y[3] != a[3])
                overflow_reg = (a[3] == b[3]) && (y_reg[3] != a[3]);
            end
            3'b001: begin // SUB
                // For subtraction, we treat it as a - b. 
                // y is low 4 bits of a - b.
                // carry is 1 if a >= b (unsigned).
                y_reg = a[3:0] - b[3:0];
                carry_reg = (a >= b);
                // Overflow for signed subtraction: (a[3] != b[3]) && (y[3] != a[3])
                overflow_reg = (a[3] != b[3]) && (y_reg[3] != a[3]);
            end
            3'b010: begin // AND
                y_reg = a & b;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            3'b011: begin // OR
                y_reg = a | b;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            3'b100: begin // XOR
                y_reg = a ^ b;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            3'b101: begin // SHL
                y_reg = {a[2:0], 1'b0};
                carry_reg = a[3];
                overflow_reg = 1'b0;
            end
            3'b110: begin // SHR
                y_reg = {1'b0, a[3:1]};
                carry_reg = a[0];
                overflow_reg = 1'b0;
            end
            3'b111: begin // SLT (Signed Less Than)
                // To compare signed numbers: if a < b then 1 else 0.
                // We can use the property that a < b is true if (a - b) results in negative,
                // but we must handle the overflow case for subtraction.
                // A safer way for SLT:
                if ($signed(a) < $signed(b))
                    y_reg = 4'b0001;
                else
                    y_reg = 4'b0000;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            default: begin
                y_reg = 4'b0000;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
        endcase
    end

    assign y = y_reg;
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign zero = (y == 4'b0000);
    assign negative = y[3];

endmodule
