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

    reg [7:0] y_reg;
    reg       carry_reg;
    reg       overflow_reg;

    // Internal signals for specific operations
    wire [8:0] sum_res;
    wire [7:0] sub_res;
    wire [7:0] sra_res;
    wire [7:0] rol_res;
    wire [7:0] slt_res;

    // ADD/SUB intermediate calculations
    assign sum_res = a + b;
    assign sub_res = a - b;

    // SRA (Arithmetic Shift Right)
    // bit 7 is sign extended, bit 0 is shifted out
    assign sra_res = {a[7], a[7:1]};

    // ROL (Rotate Left)
    // bit 7 moves to bit 0
    assign rol_res = {a[6:0], a[7]};

    // SLT (Set Less Than - Signed)
    // We cast to 9-bit signed to handle the comparison correctly or use sign extension logic
    // A simpler way for 8-bit signed: compare (a[7]^b[7]) and other bits, 
    // but standard way is sign extending to a larger width.
    assign slt_res = (($signed(a) < $signed(b)) ? 8'h01 : 8'h00);

    always @(*) begin
        // Default values
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
                y_reg = sum_res[7:0];
                carry_reg = sum_res[8];
                // Overflow: same sign inputs, different sign output
                overflow_reg = (a[7] == b[7]) && (sum_res[7] != a[7]);
            end
            3'b100: begin // SUB
                y_reg = sub_res;
                // Carry for SUB: 1 if a >= b as unsigned, else 0
                carry_reg = (a >= b);
                // Overflow: different sign inputs, different sign output
                overflow_reg = (a[7] != b[7]) && (sub_res[7] != a[7]);
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
    assign zero = (y_reg == 8'h00);
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign negative = y_reg[7];

endmodule
```