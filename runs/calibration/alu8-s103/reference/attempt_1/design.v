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

    // Internal wires for arithmetic to handle carry/overflow easily
    wire [8:0] sum_add = a + b;
    wire [8:0] diff_sub = a - b; // This is actually 2's complement subtraction logic
    // For SUB, we need a-b. In Verilog, a-b for 8 bits is fine, but let's be explicit.
    // To get carry/borrow correctly for unsigned:
    // Carry out of ADD is sum_add[8].
    // Carry (no borrow) for SUB: if a >= b, carry = 1.

    always @(*) begin
        // Default values to prevent latches
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
                y_reg = sum_add[7:0];
                carry_reg = sum_add[8];
                // Overflow: same sign inputs, different sign result
                if (a[7] == b[7]) begin
                    if (sum_add[7] != a[7])
                        overflow_reg = 1'b1;
                    else
                        overflow_reg = 1'b0;
                end else begin
                    overflow_reg = 1'b0;
                end
            end
            3'b100: begin // SUB
                y_reg = a - b;
                // Carry: 1 if a >= b (unsigned), else 0
                carry_reg = (a >= b) ? 1'b1 : 1'b0;
                // Overflow: different sign inputs, result sign differs from 'a'
                if (a[7] != b[7]) begin
                    if (y_reg[7] != a[7])
                        overflow_reg = 1'b1;
                    else
                        overflow_reg = 1'b0;
                end else begin
                    overflow_reg = 1'b0;
                end
            end
            3'b101: begin // SRA (Arithmetic shift right)
                y_reg = {a[7], a[7:1]};
                carry_reg = a[0];
                overflow_reg = 1'b0;
            end
            3'b110: begin // ROL (Rotate left)
                y_reg = {a[6:0], a[7]};
                carry_reg = a[7];
                overflow_reg = 1'b0;
            end
            3'b111: begin // SLT (Set Less Than signed)
                // Compare as signed. If a < b, y = 1, else 0.
                if ($signed(a) < $signed(b))
                    y_reg = 8'd1;
                else
                    y_reg = 8'd0;
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
    assign zero = (y == 8'b0);
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign negative = y[7];

endmodule
