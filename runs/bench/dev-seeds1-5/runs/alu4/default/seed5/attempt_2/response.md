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

    always @(*) begin
        // Default values to avoid latches
        y_reg = 4'b0000;
        carry_reg = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // ADD
                {carry_reg, y_reg} = a + b;
                // Overflow for signed addition: (a[3] == b[3]) && (y[3] != a[3])
                if ((a[3] == b[3]) && (y_reg[3] != a[3]))
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b001: begin // SUB
                // Unsigned subtraction logic for carry/borrow requirement
                // Spec says: "carry is 1 exactly when a >= b as unsigned"
                if (a >= b) carry_reg = 1'b1;
                else        carry_reg = 1'b0;
                
                y_reg = a - b;
                // Overflow for signed subtraction: (a[3] != b[3]) && (y[3] != a[3])
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
            3'b111: begin // SLT (Signed Less Than)
                if (($signed(a) < $signed(b)))
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
    assign zero = (y_reg == 4'b0000);
    assign carry = carry_reg;
    assign overflow = overflow_reg;
    assign negative = y_reg[3];

endmodule
```

```verilog
module tb;
    reg [3:0] a, b;
    reg [2:0] op;
    wire [3:0] y;
    wire zero, carry, overflow, negative;

    integer passed, total;

    alu4 uut (
        .a(a),
        .b(b),
        .op(op),
        .y(y),
        .zero(zero),
        .carry(carry),
        .overflow(overflow),
        .negative(negative)
    );

    task check_result;
        input [3:0] exp_y;
        input       exp_z;
        input       exp_c;
        input       exp_o;
        input       exp_n;
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_o || negative !== exp_n) begin
                $display("FAIL: a=%d b=%d op=%b | Expected: y=%d z=%b c=%b o=%b n=%b | Actual: y=%d z=%b c=%b o=%b n=%b", 
                         a, b, op, exp_y, exp_z, exp_c, exp_o, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // ADD (000)
        op = 3'b000;
        a = 4'd5; b = 4'd3; check_result(4'd8, 0, 0, 0, 0);
        a = 4'd10; b = 4'd7; check_result(4'd1, 0, 1, 0, 0); 
        a = 4'd7; b = 4'd6; check_result(4'd13, 0, 0, 1, 0); 
        a = 4'd15; b = 4'd1; check_result(4'd0, 1, 1, 0, 0); // 15+1=16 (1 0000). a[3]=1, b[3]=0. No ovf.
        a = 4'd15; b = 4'd15; check_result(4'd14, 0, 1, 0, 1); // 15+15=30 (1 1110). a[3]=1, b[3]=1. y[3]=1. No ovf.
        a = 4'd7; b = 4'd8; check_result(4'd15, 0, 0, 0, 0); // 7+8=15 (0111 + 1000 = 1111). a[3]=0, b[3]=1. No ovf.

        // SUB (001)
        op = 3'b001;
        a = 4'd10; b = 4'd5; check_result(4'd5, 0, 1, 0, 0);
        a = 4'd5; b = 4'd10; check_result(4'd11, 0, 0, 1, 1); // a=5(0101), b=10(1010). y=5-10=-5(1011). (a[3]!=b[3]) && (y[3]!=a[3]) -> (0!=1)&&(1!=0) = 1.
        a = 4'd5; b = 4'd5; check_result(4'd0, 1, 1, 0, 0);

        // AND (010)
        op = 3'b010;
        a = 4'hF; b = 4'h5; check_result(4'h5, 0, 0, 0, 0);
        a = 4'h0; b = 4'hF; check_result(4'h0, 1, 0, 0, 0);

        // OR (011)
        op = 3'b011;
        a = 4'hA; b = 4'h5; check_result(4'hF, 0, 0, 0, 0);
        a = 4'h0; b = 4'h0; check_result(4'h0, 1, 0, 0, 0);

        // XOR (100)
        op = 3'b100;
        a = 4'hF; b = 4'h5; check_result(4'hA, 0, 0, 0, 0);
        a = 4'hF; b = 4'hF; check_result(4'h0, 1, 0, 0, 0);

        // SHL (101)
        op = 3'b101;
        a = 4'b1011; check_result(4'b0110, 0, 1, 0, 0);
        a = 4'b0111; check_result(4'b1110, 0, 0, 0, 1); // y=1110 is negative

        // SHR (110)
        op = 3'b110;
        a = 4'b1011; check_result(4'b0101, 0, 1, 0, 0);
        a = 4'b1110; check_result(4'b0111, 0, 0, 0, 0);

        // SLT (111)
        op = 3'b111;
        a = 4'd2; b = 4'd3; check_result(4'd1, 0, 0, 0, 0);
        a = 4'd3; b = 4'd2; check_result(4'd0, 1, 0, 0, 0);
        a = 4'b1111; b = 4'b0001; check_result(4'd1, 0, 0, 0, 0); // -1 < 1 is true
        a = 4'b0001; b = 4'b1111; check_result(4'd0, 1, 0, 0, 0); // 1 < -1 is false

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```