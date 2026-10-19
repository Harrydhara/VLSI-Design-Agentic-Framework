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

    // Internal wires for intermediate calculations
    wire [8:0] sum_add;
    wire [8:0] diff_sub; // a - b = a + (~b) + 1
    wire [7:0] sub_res;
    wire [7:0] sra_res;
    wire [7:0] rol_res;
    wire [7:0] slt_res;

    assign sum_add = a + b;
    assign diff_sub = a - b; // Using 9-bit to capture borrow/carry logic easily
    // However, the spec for SUB carry is specific: 1 if a >= b (unsigned), else 0.
    // The spec for SUB overflow is signed overflow.

    assign sub_res = a - b;
    assign sra_res = {a[7], a[7:1]};
    assign rol_res = {a[6:0], a[7]};
    assign slt_res = ($signed(a) < $signed(b)) ? 8'h01 : 8'h00;

    always @(*) begin
        // Default values to prevent latches
        y_reg = 8'h00;
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
                if (a[7] == b[7] && y_reg[7] != a[7])
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b100: begin // SUB
                y_reg = sub_res;
                // Carry: 1 if a >= b (unsigned), else 0
                carry_reg = (a >= b) ? 1'b1 : 1'b0;
                // Overflow: different sign inputs, result sign differs from 'a'
                if (a[7] != b[7] && y_reg[7] != a[7])
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b101: begin // SRA
                y_reg = sra_res;
                carry_reg = a[0];
                overflow_reg = 1'b0;
            end
            3'b110: begin // ROL
                y_reg = rol_res;
                carry_reg = a[7];
                overflow_reg = 1'b0;
            end
            3'b111: begin // SLT
                y_reg = slt_res;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
            default: begin
                y_reg = 8'h00;
                carry_reg = 1'b0;
                overflow_reg = 1'b0;
            end
        endcase
    end

    assign y = y_reg;
    assign zero = (y == 8'h00);
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign negative = y[7];

endmodule
