```verilog
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

    // Helper for signed comparison (SLT)
    wire signed [4:0] a_ext = {{a[3], a}};
    wire signed [4:0] b_ext = {{b[3], b}};

    always @(*) begin
        // Default values to prevent latches
        y_reg = 4'b0000;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // ADD
                {carry_reg, y_reg} = a + b;
                // Overflow: (a[3] == b[3]) && (y[3] != a[3])
                if ((a[3] == b[3]) && (y_reg[3] != a[3]))
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end

            3'b001: begin // SUB
                // carry is 1 exactly when a >= b as unsigned numbers
                carry_reg = (a >= b);
                y_reg = a - b;
                // Overflow: (a[3] != b[3]) && (y[3] != a[3])
                if ((a[3] != b[3]) && (y_reg[3] != a[3]))
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
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

            3'b111: begin // SLT
                // 1 if a < b as signed two's complement numbers, otherwise 0
                if (a_ext < b_ext)
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
    assign zero = (y_reg == 4'b0000);
    assign negative = y_reg[3];

endmodule
```