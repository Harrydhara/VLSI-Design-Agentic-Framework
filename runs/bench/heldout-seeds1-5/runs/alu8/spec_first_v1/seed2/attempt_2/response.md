```verilog
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

    // Intermediate arithmetic results
    wire [8:0] sum_val = a + b;
    wire [7:0] sub_val = a - b;

    always @(*) begin
        // Default values to prevent latches and ensure all branches are covered
        y_out = 8'b0;
        carry_out = 1'b0;
        overflow_out = 1'b0;

        case (op)
            3'b000: begin // AND
                y_out = a & b;
                carry_out = 1'b0;
                overflow_out = 1'b0;
            end
            3'b001: begin // OR
                y_out = a | b;
                carry_out = 1'b0;
                overflow_out = 1'b0;
            end
            3'b010: begin // XOR
                y_out = a ^ b;
                carry_out = 1'b0;
                overflow_out = 1'b0;
            end
            3'b011: begin // ADD
                y_out = sum_val[7:0];
                carry_out = sum_val[8];
                // Overflow: same sign inputs, result sign differs from a
                if (a[7] == b[7]) begin
                    if (sum_val[7] != a[7])
                        overflow_out = 1'b1;
                    else
                        overflow_out = 1'b0;
                end else begin
                    overflow_out = 1'b0;
                end
            end
            3'b100: begin // SUB
                y_out = sub_val;
                // Carry: 1 exactly when a >= b as unsigned numbers (no borrow)
                carry_out = (a >= b) ? 1'b1 : 1'b0;
                // Overflow: different sign inputs, result sign differs from a
                if (a[7] != b[7]) begin
                    if (sub_val[7] != a[7])
                        overflow_out = 1'b1;
                    else
                        overflow_out = 1'b0;
                end else begin
                    overflow_out = 1'b0;
                end
            end
            3'b101: begin // SRA (Arithmetic Shift Right)
                y_out = {a[7], a[7:1]};
                carry_out = a[0];
                overflow_out = 1'b0;
            end
            3'b110: begin // ROL (Rotate Left)
                y_out = {a[6:0], a[7]};
                carry_out = a[7];
                overflow_out = 1'b0;
            end
            3'b111: begin // SLT (Set Less Than - Signed)
                if ($signed(a) < $signed(b))
                    y_out = 8'h01;
                else
                    y_out = 8'h00;
                carry_out = 1'b0;
                overflow_out = 1'b0;
            end
            default: begin
                y_out = 8'b0;
                carry_out = 1'b0;
                overflow_out = 1'b0;
            end
        endcase
    end

    assign y = y_out;
    assign zero = (y_out == 8'b0);
    assign carry = carry_out;
    assign overflow = overflow_out;
    assign negative = y_out[7];

endmodule
```