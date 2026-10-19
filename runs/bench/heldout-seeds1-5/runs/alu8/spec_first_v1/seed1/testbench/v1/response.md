```verilog
module tb;
    // Inputs
    reg [7:0] a;
    reg [7:0] b;
    reg [2:0] op;

    // Outputs
    wire [7:0] y;
    wire zero;
    wire carry;
    wire overflow;
    wire negative;

    // Instantiate the Unit Under Test (UUT)
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

    // Reference Model and Verification Logic
    integer i, j;
    integer passed;
    integer total;

    task check_alu;
        input [7:0] ta;
        input [7:0] tb_val;
        input [2:0] top;
        reg [7:0] expected_y;
        reg expected_zero;
        reg expected_carry;
        reg expected_overflow;
        reg expected_negative;
        reg [8:0] sum_ext;
        reg [8:0] sub_ext;
        reg [7:0] a_signed, b_signed, y_signed;

    begin
        // Calculate Expected Values based on Specification
        expected_carry = 0;
        expected_overflow = 0;
        
        case (top)
            3'b000: begin // AND
                expected_y = ta & tb_val;
            end
            3'b001: begin // OR
                expected_y = ta | tb_val;
            end
            3'b010: begin // XOR
                expected_y = ta ^ tb_val;
            end
            3'b011: begin // ADD
                sum_ext = ta + tb_val;
                expected_y = sum_ext[7:0];
                expected_carry = sum_ext[8];
                // Overflow: same sign bits, result sign differs
                if (ta[7] == tb_val[7] && expected_y[7] != ta[7])
                    expected_overflow = 1;
            end
            3'b100: begin // SUB
                // Spec: carry is 1 when a >= b as unsigned, else 0
                expected_carry = (ta >= tb_val) ? 1 : 0;
                // subtraction for y calculation
                expected_y = ta - tb_val;
                // Overflow: different sign bits, result sign differs from a
                if (ta[7] != tb_val[7] && expected_y[7] != ta[7])
                    expected_overflow = 1;
            end
            3'b101: begin // SRA
                expected_y = {ta[7], ta[7:1]};
                expected_carry = ta[0];
            end
            3'b110: begin // ROL
                expected_y = {ta[6:0], ta[7]};
                expected_carry = ta[7];
            end
            3'b111: begin // SLT (Signed)
                a_signed = $signed(ta);
                b_signed = $signed(tb_val);
                if (a_signed < b_signed) expected_y = 8'h01;
                else expected_y = 8'h00;
            end
        endcase

        expected_zero = (expected_y == 8'h00);
        expected_negative = expected_y[7];

        // Compare
        total = total + 1;
        if (y !== expected_y || zero !== expected_zero || carry !== expected_carry || 
            overflow !== expected_overflow || negative !== expected_negative) begin
            $display("FAIL: op=%b a=%h b=%h | exp: y=%h z=%b c=%b v=%b n=%b | act: y=%h z=%b c=%b v=%b n=%b", 
                     top, ta, tb_val, expected_y, expected_zero, expected_carry, expected_overflow, expected_negative,
                     y, zero, carry, overflow, negative);
        end else begin
            passed = passed + 1;
        end
    end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // Test all combinations of op, a, and b is too large (256*256*8), 
        // so we use a representative set including corners.
        
        // Exhaustive for small values or specific patterns
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                // Test op=0, 1, 2 with all b for a fixed set of a
                a = 8'hAA; b = j; op = i[2:0]; check_alu(a, b, op);
                // Test op=3, 4 (Arithmetic) with various a, b
                if (i < 2) begin
                    a = j; b = j + 1; op = 3'b011; check_alu(a, b, op);
                    a = j; b = j - 1; op = 3'b100; check_alu(a, b, op);
                end
            end
        end

        // Specific Corner Cases for Arithmetic/Logic
        // ADD Overflow: 7F + 01 = 80 (pos+pos=neg)
        a = 8'h7F; b = 8'h01; op = 3'b011; check_alu(a, b, op);
        // ADD Overflow: 80 + 80 = 00 (neg+neg=pos)
        a = 8'h80; b = 8'h80; op = 3'b011; check_alu(a, b, op);
        // SUB Overflow: 7F - 80 = FF (pos-neg=neg)
        a = 8'h7F; b = 8'h80; op = 3'b100; check_alu(a, b, op);
        // SUB Overflow: 80 - 7F = 01 (neg-pos=pos)
        a = 8'h80; b = 8'h7F; op = 3'b100; check_alu(a, b, op);

        // SRA/ROL corners
        a = 8'h80; b = 8'h00; op = 3'b101; check_alu(a, b, op); // SRA: bit7 stays 1
        a = 8'h01; b = 8'h00; op = 3'b101; check_alu(a, b, op); // SRA: carry is a[0]
        a = 8'h80; b = 8'h00; op = 3'b110; check_alu(a, b, op); // ROL: bit7 to bit0
        a = 8'h01; b = 8'h00; op = 3'b110; check_alu(a, b, op); // ROL: carry is a[7]

        // SLT corners
        a = 8'h7F; b = 8'h80; op = 3'b111; check_alu(a, b, op); // 127 < -128? No (0)
        a = 8'h80; b = 8'h7F; op = 3'b111; check_alu(a, b, op); // -128 < 127? Yes (1)
        a = 8'hFF; b = 8'hFF; op = 3'b111; check_alu(a, b, op); // -1 < -1? No (0)

        // Zero flag corner
        a = 8'h00; b = 8'h00; op = 3'b000; check_alu(a, b, op);
        a = 8'hFF; b = 8'hFF; op = 3'b111; check_alu(a, b, op); // SLT result is 0

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```