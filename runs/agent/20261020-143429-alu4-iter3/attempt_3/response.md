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
    wire is_less_than = (a[3] != b[3]) ? (a[3] == 1'b1) : (a < b);

    always @(*) begin
        // Default values to prevent latches
        y_reg       = 4'b0000;
        carry_reg   = 1'b0;
        overflow_reg = 1'b0;

        case (op)
            3'b000: begin // ADD
                {carry_reg, y_reg} = a + b;
                // overflow: (a[3] == b[3]) && (y[3] != a[3])
                overflow_reg = (a[3] == b[3]) && (y_reg[3] != a[3]);
            end
            3'b001: begin // SUB
                // Specification says carry is 1 when a >= b as unsigned numbers
                carry_reg = (a >= b);
                y_reg = a - b;
                // overflow: (a[3] != b[3]) && (y[3] != a[3])
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
                y_reg = is_less_than ? 4'b0001 : 4'b0000;
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

    assign y        = y_reg;
    assign carry    = carry_reg;
    assign overflow = overflow_reg;
    assign zero     = (y_reg == 4'b0000);
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

    alu4 dut (
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
                $display("FAIL: op=%b a=%b b=%b | Exp: y=%b z=%b c=%b o=%b n=%b | Got: y=%b z=%b c=%b o=%b n=%b", 
                         op, a, b, exp_y, exp_z, exp_c, exp_o, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // ADD tests
        a = 4'd5; b = 4'd3; op = 3'b000; #1; // y=8, z=0, c=0, o=0, n=0
        check_result(4'd8, 0, 0, 0, 0);
        a = 4'd10; b = 4'd7; op = 3'b000; #1; // a=1010, b=0111. y=0001, c=1, o=0 (a[3]!=b[3])
        check_result(4'd1, 0, 1, 0, 0);
        a = 4'b1000; b = 4'b1000; op = 3'b000; #1; // a=-8, b=-8. y=0, c=1, o=(1==1 && 0!=1)=1
        check_result(4'd0, 1, 1, 1, 0);

        // SUB tests
        a = 4'd5; b = 4'd3; op = 3'b001; #1; // y=2, c=1 (5>=3), o=0, n=0
        check_result(4'd2, 0, 1, 0, 0);
        a = 4'd3; b = 4'd5; op = 3'b001; #1; // y=-2 (1110), c=0 (3<5), o=0 (a[3]==b[3])
        check_result(4'b1110, 0, 0, 0, 1);
        a = 4'b1000; b = 4'b0001; op = 3'b001; #1; // a=-8, b=1. y=7 (0111), c=0 (8<1 is false), o=(1!=0 && 0!=1)=1
        check_result(4'd7, 0, 0, 1, 0);

        // AND/OR/XOR tests
        a = 4'b1010; b = 4'b1100; op = 3'b010; #1; // AND: 1000
        check_result(4'b1000, 0, 0, 0, 1);
        a = 4'b1010; b = 4'b1100; op = 3'b011; #1; // OR: 1110
        check_result(4'b1110, 0, 0, 0, 1);
        a = 4'b1010; b = 4'b1100; op = 3'b100; #1; // XOR: 0110
        check_result(4'b0110, 0, 0, 0, 0);

        // SHL/SHR tests
        a = 4'b1011; op = 3'b101; #1; // SHL: y=0110, c=1
        check_result(4'b0110, 0, 1, 0, 0);
        a = 4'b1011; op = 3'b110; #1; // SHR: y=0101, c=1 (a[0]=1)
        check_result(4'b0101, 0, 1, 0, 0);
        a = 4'b0011; op = 3'b110; #1; // SHR: y=0001, c=1 (a[0]=1)
        check_result(4'b0001, 0, 1, 0, 0);

        // SLT tests
        a = 4'd2; b = 4'd3; op = 3'b111; #1; // 2 < 3 -> y=1
        check_result(4'd1, 0, 0, 0, 0);
        a = 4'b1111; b = 4'b0001; op = 3'b111; #1; // -1 < 1 -> y=1
        check_result(4'd1, 0, 0, 0, 0);
        a = 4'b0001; b = 4'b1111; op = 3'b111; #1; // 1 < -1 -> y=0
        check_result(4'd0, 1, 0, 0, 0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```