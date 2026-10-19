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

    // Internal signals for arithmetic
    wire [8:0] sum;
    wire [8:0] diff;
    wire [7:0] sra_val;
    wire [7:0] rol_val;
    wire [7:0] slt_val;

    assign sum = a + b;
    assign diff = a - b;
    
    // SRA (Arithmetic Shift Right): bit 7 is replicated into the new MSB
    assign sra_val = {a[7], a[7:1]};
    
    // ROL (Rotate Left): bit 7 moves to bit 0
    assign rol_val = {a[6:0], a[7]};
    
    // SLT (Set Less Than): signed comparison
    // We use the property that if we treat them as signed, 
    // we can compare them directly.
    assign slt_val = ($signed(a) < $signed(b)) ? 8'h01 : 8'h00;

    always @(*) begin
        // Default values to prevent latches
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
                if (a[7] == b[7] && y_reg[7] != a[7])
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
            end
            3'b100: begin // SUB
                y_reg = diff[7:0];
                // Carry for SUB: 1 if a >= b (unsigned), else 0
                carry_reg = (a >= b) ? 1'b1 : 1'b0;
                // Overflow: different sign inputs, result sign differs from 'a'
                if (a[7] != b[7] && y_reg[7] != a[7])
                    overflow_reg = 1'b1;
                else
                    overflow_reg = 1'b0;
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
            default: begin
                y_reg = 8'h00;
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

    integer i;
    integer passed, total;

    alu8 dut (
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
        input exp_z;
        input exp_c;
        input exp_v;
        input exp_n;
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_v || negative !== exp_n) begin
                $display("FAIL: a=%d b=%d op=%b | Exp: y=%h z=%b c=%b v=%b n=%b | Got: y=%h z=%b c=%b v=%b n=%b", 
                         a, b, op, exp_y, exp_z, exp_c, exp_v, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // Test AND
        op = 3'b000; a = 8'hAA; b = 8'h55; check_result(8'h00, 1, 0, 0, 0);
        op = 3'b000; a = 8'hFF; b = 8'h0F; check_result(8'h0F, 0, 0, 0, 0);

        // Test OR
        op = 3'b001; a = 8'hAA; b = 8'h55; check_result(8'hFF, 0, 0, 0, 0);
        op = 3'b001; a = 8'h00; b = 8'h00; check_result(8'h00, 1, 0, 0, 0);

        // Test XOR
        op = 3'b010; a = 8'hFF; b = 8'hFF; check_result(8'h00, 1, 0, 0, 0);
        op = 3'b010; a = 8'hAA; b = 8'h55; check_result(8'hFF, 0, 0, 0, 0);

        // Test ADD
        op = 3'b011; a = 8'd10; b = 8'd20; check_result(8'd30, 0, 0, 0, 0);
        op = 3'b011; a = 8'hFF; b = 8'h01; check_result(8'h00, 1, 1, 0, 0); // Carry out
        op = 3'b011; a = 8'h7F; b = 8'h01; check_result(8'h80, 0, 0, 1, 1); // Signed Overflow (pos+pos=neg)
        op = 3'b011; a = 8'h80; b = 8'h80; check_result(8'h00, 1, 1, 1, 0); // Signed Overflow (neg+neg=pos)

        // Test SUB
        op = 3'b100; a = 8'd20; b = 8'd10; check_result(8'd10, 0, 1, 0, 0); // Carry (a>=b)
        op = 3'b100; a = 8'd10; b = 8'd20; check_result(8'hF6, 0, 0, 0, 1); // Carry (a<b), result neg
        op = 3'b100; a = 8'h7F; b = 8'h80; check_result(8'hFF, 0, 1, 1, 0); // Signed Overflow (pos-neg=neg)
        op = 3'b100; a = 8'h80; b = 8'h7F; check_result(8'h01, 0, 1, 1, 0); // Signed Overflow (neg-pos=pos)

        // Test SRA
        op = 3'b101; a = 8'b1000_0011; b = 8'h00; check_result(8'b1100_0001, 0, 1, 0, 1); // Carry is bit 0
        op = 3'b101; a = 8'b0100_0011; b = 8'h00; check_result(8'b0010_0001, 0, 1, 0, 0);

        // Test ROL
        op = 3'b110; a = 8'b1000_0001; b = 8'h00; check_result(8'b0000_0011, 0, 1, 0, 0); // Carry is bit 7
        op = 3'b110; a = 8'b0100_0001; b = 8'h00; check_result(8'b1000_0010, 0, 0, 0, 1);

        // Test SLT
        op = 3'b111; a = 8'd5;  b = 8'd10; check_result(8'h01, 0, 0, 0, 0); // 5 < 10
        op = 3'b111; a = 8'd10; b = 8'd5;  check_result(8'h00, 1, 0, 0, 0); // 10 < 5 is false
        op = 3'b111; a = -8'd1; b = 8'd1;  check_result(8'h01, 0, 0, 0, 0); // -1 < 1
        op = 3'b111; a = 8'h7F; b = 8'h80; check_result(8'h00, 1, 0, 0, 0); // 127 < -128 is false

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
```