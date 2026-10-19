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

    // Internal wires for calculations
    wire [8:0] sum;
    wire [8:0] diff;
    wire [7:0] sra_val;
    wire [7:0] rol_val;
    wire [7:0] slt_val;

    assign sum = a + b;
    // For subtraction, we use the standard 9-bit result to determine carry/borrow.
    // The requirement says: Carry is 1 when a >= b (unsigned), else 0.
    assign diff = a - b;
    
    // SRA: Arithmetic shift right by 1. Bit 7 is sign bit.
    assign sra_val = {a[7], a[7:1]};
    
    // ROL: Rotate left by 1.
    assign rol_val = {a[6:0], a[7]};
    
    // SLT: Set less than (signed).
    assign slt_val = ($signed(a) < $signed(b)) ? 8'h01 : 8'h00;

    always @(*) begin
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
                y_reg = diff[7:0];
                // Carry: 1 if a >= b unsigned, else 0.
                carry_reg = (a >= b);
                // Overflow: different sign inputs, result sign differs from 'a'
                overflow_reg = (a[7] != b[7]) && (diff[7] != a[7]);
            end
            3'b101: begin // SRA
                y_reg = sra_val;
                carry_reg = a[0];
            end
            3'b110: begin // ROL
                y_reg = rol_val;
                carry_reg = a[7];
            end
            3'b111: begin // SLT
                y_reg = slt_val;
            end
            default: ;
        endcase
    end

    assign y = y_reg;
    assign zero = (y == 8'h00);
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign negative = y[7];

endmodule
