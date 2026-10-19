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
    wire [4:0] sum_5bit;

    assign sum_5bit = a + b;

    always @(*) begin
        y_reg = 4'b0;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;
        case (op)
            3'b000: begin // ADD
                y_reg = sum_5bit[3:0];
                carry_reg = sum_5bit[4];
                if ((a[3] == b[3]) && (y_reg[3] != a[3])) 
                    overflow_reg = 1'b1;
            end
            3'b001: begin // SUB
                y_reg = a - b;
                carry_reg = (a >= b);
                if ((a[3] != b[3]) && (y_reg[3] != a[3])) 
                    overflow_reg = 1'b1;
            end
            3'b010: begin // AND
                y_reg = a & b;
            end
            3'b011: begin // OR
                y_reg = a | b;
            end
            3'b100: begin // XOR
                y_reg = a ^ b;
            end
            3'b101: begin // SHL
                y_reg = {a[2:0], 1'b0};
                carry_reg = a[3];
            end
            3'b110: begin // SHR
                y_reg = {1'b0, a[3:1]};
                carry_reg = a[0];
            end
            3'b111: begin // SLT
                if ($signed(a) < $signed(b)) y_reg = 4'h1;
                else y_reg = 4'h0;
            end
            default: ;
        endcase
    end

    assign y = y_reg;
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign zero = (y_reg == 4'b0);
    assign negative = y_reg[3];

endmodule
