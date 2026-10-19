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

    // Internal wires for arithmetic
    wire [8:0] sum;
    wire [8:0] diff;
    wire [7:0] sra_val;
    wire [7:0] rol_val;
    wire [7:0] slt_val;

    assign sum = a + b;
    assign diff = a - b;
    
    // SRA: Arithmetic shift right by 1. Bit 7 is replicated to bit 7.
    assign sra_val = {a[7], a[7:1]};
    
    // ROL: Rotate left by 1. Bit 7 moves to bit 0.
    assign rol_val = {a[6:0], a[7]};
    
    // SLT: Set Less Than (signed)
    // If a < b, result is 1, else 0.
    // Using signed comparison logic.
    assign slt_val = ($signed(a) < $signed(b)) ? 8'h01 : 8'h00;

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
                y_reg = sum[7:0];
                carry_reg = sum[8];
                // Overflow: same sign inputs, result sign differs
                if (a[7] == b[7] && y_reg[7] != a[7])
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b100: begin // SUB
                y_reg = diff[7:0];
                // Carry for SUB: 1 if a >= b (unsigned), else 0
                carry_reg = (a >= b) ? 1'b1 : 1'b0;
                // Overflow: different sign inputs, result sign differs from a
                if (a[7] != b[7] && y_reg[7] != a[7])
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b101: begin // SRA
                y_reg = sra_val;
                carry_reg = a[0];
                overflow_reg = 1'b0;
            end
            3'b110: begin // ROL
                y_reg = rol_val;
                carry_reg = a[7];
                overflow_reg = 1'b0;
            end
            3'b111: begin // SLT
                y_reg = slt_val;
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
```

```verilog
module tb;
    reg [7:0] a, b;
    reg [2:0] op;
    wire [7:0] y;
    wire zero, carry, overflow, negative;

    integer i, j;
    integer passed, total;

    alu8 uut (
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
        input [7:0] exp_y;
        input exp_z, exp_c, exp_o, exp_n;
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_o || negative !== exp_n) begin
                $display("FAIL: op=%b a=%d b=%d | expected y=%d z=%b c=%b o=%b n=%b, actual y=%d z=%b c=%b o=%b n=%b", 
                         op, a, b, exp_y, exp_z, exp_c, exp_o, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // Test AND
        a = 8'hAA; b = 8'h55; op = 3'b000; #1; check_result(8'h00, 1, 0, 0, 0);
        a = 8'hFF; b = 8'h0F; op = 3'b000; #1; check_result(8'h0F, 0, 0, 0, 0);

        // Test OR
        a = 8'hAA; b = 8'h55; op = 3'b001; #1; check_result(8'hFF, 0, 0, 0, 0);
        a = 8'h00; b = 8'h00; op = 3'b001; #1; check_result(8'h00, 1, 0, 0, 0);

        // Test XOR
        a = 8'hAA; b = 8'h55; op = 3'b010; #1; check_result(8'hFF, 0, 0, 0, 0);
        a = 8'hAA; b = 8'hAA; op = 3'b010; #1; check_result(8'h00, 1, 0, 0, 0);

        // Test ADD
        a = 8'h05; b = 8'h02; op = 3'b011; #1; check_result(8'h07, 0, 0, 0, 0); // Normal
        a = 8'hFF; b = 8'h01; op = 3'b011; #1; check_result(8'h00, 1, 1, 0, 0); // Carry out
        a = 8'h7F; b = 8'h01; op = 3'b011; #1; check_result(8'h80, 0, 0, 1, 1); // Signed Overflow (pos+pos=neg)
        a = 8'h80; b = 8'h80; op = 3'b011; #1; check_result(8'h00, 1, 1, 0, 0); // Carry out, no overflow (neg+neg=pos is wrong? No: 80+80=100. Sign bits same (1), result sign (0). Overflow!)
        // Re-check 80 + 80: a[7]=1, b[7]=1, y[7]=0. Same signs, different result sign -> overflow = 1. Correct.
        a = 8'h80; b = 8'h80; op = 3'b011; #1; check_result(8'h00, 1, 1, 1, 0);

        // Test SUB
        a = 8'h0A; b = 8'h05; op = 3'b100; #1; check_result(8'h05, 0, 1, 0, 0); // a >= b (carry=1)
        a = 8'h05; b = 8'h0A; op = 3'b100; #1; check_result(8'hFB, 0, 0, 0, 1); // a < b (carry=0), result is -5
        a = 8'h7F; b = 8'h80; op = 3'b100; #1; check_result(8'hFF, 0, 0, 1, 1); // Signed Overflow (pos-neg=neg)
        a = 8'h80; b = 8'h7F; op = 3'b100; #1; check_result(8'h01, 0, 1, 1, 0); // Signed Overflow (neg-pos=pos)

        // Test SRA
        a = 8'b1000_0011; b = 8'h00; op = 3'b101; #1; check_result(8'b1100_0001, 0, 1, 0, 1); // Shifted bit 0 (1) to carry
        a = 8'b0100_0011; b = 8'h00; op = 3'b101; #1; check_result(8'b0010_0001, 0, 1, 0, 0); // Shifted bit 0 (1) to carry

        // Test ROL
        a = 8'b1000_0001; b = 8'h00; op = 3'b110; #1; check_result(8'b0000_0011, 0, 1, 0, 0); // bit 7 (1) to carry
        a = 8'b0100_0001; b = 8'h00; op = 3'b110; #1; check_result(8'b1000_0010, 0, 0, 0, 1); // bit 7 (0) to carry

        // Test SLT
        a = 8'd5; b = 8'd10; op = 3'b111; #1; check_result(8'h01, 0, 0, 0, 0); // 5 < 10
        a = 8'd10; b = 8'd5; op = 3'b111; #1; check_result(8'h00, 1, 0, 0, 0); // 10 < 5 is false
        a = -8'd5; b = 8'd5; op = 3'b111; #1; check_result(8'h01, 0, 0, 0, 0); // -5 < 5
        a = 8'd5; b = -8'd5; op = 3'b111; #1; check_result(8'h00, 1, 0, 0, 0); // 5 < -5 is false

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```