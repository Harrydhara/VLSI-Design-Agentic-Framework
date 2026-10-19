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

    wire [8:0] sum = a + b;
    wire [8:0] diff = a - b;

    always @(*) begin
        // Default values
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
                y_out = sum[7:0];
                carry_out = sum[8];
                if (a[7] == b[7] && y_out[7] != a[7])
                    overflow_out = 1'b1;
            end
            3'b100: begin // SUB
                y_out = diff[7:0];
                carry_out = (a >= b) ? 1'b1 : 1'b0;
                if (a[7] != b[7] && y_out[7] != a[7])
                    overflow_out = 1'b1;
            end
            3'b101: begin // SRA
                y_out = {a[7], a[7:1]};
                carry_out = a[0];
            end
            3'b110: begin // ROL
                y_out = {a[6:0], a[7]};
                carry_out = a[7];
            end
            3'b111: begin // SLT
                if ($signed(a) < $signed(b))
                    y_out = 8'h01;
                else
                    y_out = 8'h00;
            end
            default: ;
        endcase
    end

    assign y = y_out;
    assign zero = (y_out == 8'b0);
    assign carry = carry_out;
    assign overflow = overflow_out;
    assign negative = y_out[7];

endmodule
