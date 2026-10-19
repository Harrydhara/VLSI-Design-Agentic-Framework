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

    // Internal signals for arithmetic to handle 5-bit width
    wire [4:0] sum = a + b;
    wire [4:0] diff = a - {1'b0, b};

    always @(*) begin
        // Default values to prevent latches
        y_reg = 4'b0000;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // ADD
                y_reg = sum[3:0];
                carry_reg = sum[4];
                // Overflow for signed addition: same sign inputs, different sign result
                overflow_reg = (a[3] == b[3]) && (y_reg[3] != a[3]);
            end
            3'b001: begin // SUB
                y_reg = diff[3:0];
                // Carry is 1 if no borrow occurred (unsigned a >= b)
                carry_reg = (a >= b);
                // Overflow for signed subtraction: different sign inputs, result sign != a sign
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
                if ($signed(a) < $signed(b))
                    y_reg = 4'h1;
                else
                    y_reg = 4'h0;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            default: begin
                y_reg = 4'b0;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
        endcase
    end

    assign y = y_reg;
    assign zero = (y == 4'b0000);
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign negative = y[3];

endmodule
