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

    reg [7:0] y_out;
    reg       carry_out;
    reg       overflow_out;

    always @(*) begin
        // Default values to prevent latches and ensure all branches are covered
        y_out = 8'b0;
        carry_out = 1'b0;
        overflow_out = 1'b0;

        case (op)
            3'b000: begin // AND
                y_out = a & b;
            end
            3'b001: begin // OR
                y_out = a | b;
            end
            3'b010: begin // XOR
                y_out = a ^ b;
            end
            3'b011: begin // ADD
                // Use 9-bit math to capture carry out of bit 7
                {carry_out, y_out} = a + b;
                // Overflow: same sign inputs, result sign differs from input sign
                if (a[7] == b[7] && y_out[7] != a[7])
                    overflow_out = 1'b1;
                else
                    overflow_out = 1'b0;
            end
            3'b100: begin // SUB
                y_out = a - b;
                // Carry: 1 if a >= b (unsigned), else 0
                if (a >= b)
                    carry_out = 1'b1;
                else
                    carry_out = 1'b0;
                // Overflow: different sign inputs, result sign differs from 'a'
                if (a[7] != b[7] && y_out[7] != a[7])
                    overflow_out = 1'b1;
                else
                    overflow_out = 1'b0;
            end
            3'b101: begin // SRA (Arithmetic Shift Right)
                y_out = {a[7], a[7:1]};
                carry_out = a[0];
            end
            3'b110: begin // ROL (Rotate Left)
                y_out = {a[6:0], a[7]};
                carry_out = a[7];
            end
            3'b111: begin // SLT (Set Less Than - signed)
                if ($signed(a) < $signed(b))
                    y_out = 8'h01;
                else
                    y_out = 8'h00;
            end
            default: begin
                y_out = 8'b0;
                carry_out = 1'b0;
                overflow_out = 1'b0;
            end
        endcase
    end

    assign y = y_out;
    assign zero = (y_out == 8'h00);
    assign carry = carry_out;
    assign overflow = overflow_out;
    assign negative = y_out[7];

endmodule
