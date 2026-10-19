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
    wire signed [3:0] a_s = {a[3], a};
    wire signed [3:0] b_s = {b[3], b};

    always @(*) begin
        // Default values to prevent latches
        y_reg       = 4'b0;
        carry_reg   = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // ADD
                {carry_reg, y_reg} = a + b;
                // Overflow: same sign inputs result in different sign output
                overflow_reg = (a[3] == b[3]) && (y_reg[3] != a[3]);
            end
            3'b001: begin // SUB
                // Specification says carry is 1 when a >= b (no borrow)
                // In standard ALU terms, "carry" for subtraction often means "not borrow".
                // We follow the prompt: carry = 1 if a >= b.
                if (a >= b) begin
                    y_reg = a - b;
                    carry_reg = 1'b1;
                end else begin
                    y_reg = a - b;
                    carry_reg = 1'b0;
                end
                // Overflow: different sign inputs result in different sign output (relative to 'a')
                // Wait, the prompt says: (a[3] != b[3]) && (y[3] != a[3]). Let's follow exactly.
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
            3'b111: begin // SLT
                y_reg = (a_s < b_s) ? 4'd1 : 4'd0;
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

    assign y        = y_reg;
    assign carry    = carry_reg;
    assign overflow = overflow_reg;
    assign zero     = (y_reg == 4'b0);
    assign negative = y_reg[3];

endmodule
