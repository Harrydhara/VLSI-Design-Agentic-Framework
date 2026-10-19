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
    wire [8:0] diff = a - b;
    
    // Signed comparison (SLT)
    // To compare signed 8-bit, we extend to 9 bits to handle sign bit correctly
    wire [8:0] sa = {a[7], a};
    wire [8:0] sb = {b[7], b};

    always @(*) begin
        // Default values
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
                y_reg = sum[7:0];
                carry_reg = sum[8];
                // Overflow: same sign inputs, different sign result
                if (a[7] == b[7] && y_reg[7] != a[7])
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b100: begin // SUB
                y_reg = diff[7:0];
                // Carry (no borrow): a >= b unsigned
                carry_reg = (a >= b);
                // Overflow: different sign inputs, result sign differs from 'a'
                if (a[7] != b[7] && y_reg[7] != a[7])
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b101: begin // SRA (Arithmetic Shift Right)
                y_reg = {a[7], a[7:1]};
                carry_reg = a[0];
            end
            3'b110: begin // ROL (Rotate Left)
                y_reg = {a[6:0], a[7]};
                carry_reg = a[7];
            end
            3'b111: begin // SLT (Set Less Than signed)
                y_reg = (sa < sb) ? 8'd1 : 8'd0;
            end
            default: begin
                y_reg = 8'b0;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
        endcase
    end

    assign y = y_reg;
    assign zero = (y == 8'b0);
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign negative = y[7];

endmodule
