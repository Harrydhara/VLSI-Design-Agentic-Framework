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
        reg [8:0] sum_9bit;
        reg [8:0] diff_9bit; // Using 9 bits to handle signed subtraction logic if needed, but spec says unsigned for carry/sub

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
                sum_9bit = ta + tb_val;
                expected_y = sum_9bit[7:0];
                expected_carry = sum_9bit[8];
                // Overflow: same sign bits, result sign differs
                if (ta[7] == tb_val[7] && expected_y[7] != ta[7])
                    expected_overflow = 1;
            end
            3'b100: begin // SUB
                // Spec: carry is 1 when a >= b as unsigned, else 0.
                // Spec: overflow is 1 when signs differ and y sign differs from a.
                expected_y = ta - tb_val;
                if (ta >= tb_val) expected_carry = 1;
                else expected_carry = 0;
                
                if (ta[7] != tb_val[7] && expected_y[7] != ta[7])
                    expected_overflow = 1;
            end
            3'b101: begin // SRA
                // Arithmetic shift right: bit 7 keeps its value
                expected_y = {ta[7], ta[7:1]};
                expected_carry = ta[0];
            end
            3'b110: begin // ROL
                // Rotate left: bit 7 moves to bit 0
                expected_y = {ta[6:0], ta[7]};
                expected_carry = ta[7];
            end
            3'b111: begin // SLT (Signed)
                if ($signed(ta) < $signed(tb_val))
                    expected_y = 8'd1;
                else
                    expected_y = 8'd0;
            end
        endcase

        expected_zero = (expected_y == 8'b0);
        expected_negative = expected_y[7];

        // Compare actual vs expected
        total = total + 1;
        if (y !== expected_y || zero !== expected_zero || carry !== expected_carry || 
            overflow !== expected_overflow || negative !== expected_negative) begin
            $display("FAIL: op=%b a=%d b=%d | exp: y=%d z=%b c=%b v=%b n=%b | act: y=%d z=%b c=%b v=%b n=%b", 
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

        // Test all combinations of op, a, and b is too large (256*256*8).
        // We will test specific patterns and corner cases.

        // AND/OR/XOR tests
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                a = i; b = j; op = 3'b000; #1; check_alu(a, b, op);
                a = i; b = j; op = 3'b001; #1; check_alu(a, b, op);
                a = i; b = j; op = 3'b010; #1; check_alu(a, b, op);
            end
        end

        // ADD tests (including overflow and carry)
        for (i = 0; i < 256; i = i + 1) begin
            a = i;
            b = 8'hFF; op = 3'b011; #1; check_alu(a, b, op); // Test carry/overflow with max B
            b = 8'h01; op = 3'b011; #1; check_alu(a, b, op); // Test increment
            b = 8'h00; op = 3'b011; #1; check_alu(a, b, op); // Test zero
        end
        // Specific ADD overflow: 0x7F + 0x01 = 0x80 (pos+pos=neg)
        a = 8'h7F; b = 8'h01; op = 3'b011; #1; check_alu(a, b, op);
        // Specific ADD overflow: 0x81 + 0xFF = 0x80 (neg+neg=pos is impossible in 8bit addition? No. 0x81 + 0x81 = 0x02)
        a = 8'h81; b = 8'h81; op = 3'b011; #1; check_alu(a, b, op);

        // SUB tests (including carry/no-borrow and overflow)
        for (i = 0; i < 256; i = i + 1) begin
            a = i;
            b = 8'hFF; op = 3'b100; #1; check_alu(a, b, op); // a < b case (carry=0)
            b = 8'h00; op = 3'b100; #1; check_alu(a, b, op); // a >= b case (carry=1)
        end
        // Specific SUB overflow: 0x7F - 0x81 = 0xFF (pos-neg=neg)
        a = 8'h7F; b = 8'h81; op = 3'b100; #1; check_alu(a, b, op);
        // Specific SUB overflow: 0x81 - 0x7F = 0x02 (neg-pos=pos)
        a = 8'h81; b = 8'h7F; op = 3'b100; #1; check_alu(a, b, op);

        // SRA tests
        for (i = 0; i < 256; i = i + 1) begin
            a = i; b = 8'h00; op = 3'b101; #1; check_alu(a, b, op);
        end

        // ROL tests
        for (i = 0; i < 256; i = i + 1) begin
            a = i; b = 8'h00; op = 3'b110; #1; check_alu(a, b, op);
        end

        // SLT tests (Signed comparison)
        a = 8'h7F; b = 8'h80; op = 3'b111; #1; check_alu(a, b, op); // 127 < -128 is false -> 0
        a = 8'h80; b = 8'h7F; op = 3'b111; #1; check_alu(a, b, op); // -128 < 127 is true -> 1
        a = 8'h05; b = 8'h05; op = 3'b111; #1; check_alu(a, b, op); // equal -> 0
        a = 8'hFF; b = 8'h01; op = 3'b111; #1; check_alu(a, b, op); // -1 < 1 is true -> 1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
