module tb;
    reg [7:0] a, b;
    reg [2:0] op;
    wire [7:0] y;
    wire zero, carry, overflow, negative;

    integer passed, total;

    alu8 dut (
        .a(a), .b(b), .op(op),
        .y(y), .zero(zero), .carry(carry), .overflow(overflow), .negative(negative)
    );

    reg [7:0] m_y;
    reg m_zero, m_carry, m_overflow, m_negative;

    task check;
        begin
            total = total + 1;
            if (y === m_y && zero === m_zero && carry === m_carry && overflow === m_overflow && negative === m_negative) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: a=%d b=%d op=%b | expected y=%d z=%b c=%b o=%b n=%b, actual y=%d z=%b c=%b o=%b n=%b",
                         a, b, op, m_y, m_zero, m_carry, m_overflow, m_negative, 
                         y, zero, carry, overflow, negative);
            end
        end
    endtask

    // Reference model logic
    always @(*) begin
        case (op)
            3'b000: begin m_y = a & b; m_carry = 0; m_overflow = 0; end
            3'b001: begin m_y = a | b; m_carry = 0; m_overflow = 0; end
            3'b010: begin m_y = a ^ b; m_carry = 0; m_overflow = 0; end
            3'b011: begin 
                m_y = a + b; 
                m_carry = (a + b > 255); 
                m_overflow = (a[7] == b[7]) && ((a + b)[7] != a[7]);
            end
            3'b100: begin 
                m_y = a - b; 
                m_carry = (a >= b); 
                m_overflow = (a[7] != b[7]) && ((a - b)[7] != a[7]);
            end
            3'b101: begin m_y = {a[7], a[7:1]}; m_carry = a[0]; m_overflow = 0; end
            3'b110: begin m_y = {a[6:0], a[7]}; m_carry = a[7]; m_overflow = 0; end
            3'b111: begin m_y = ($signed(a) < $signed(b)) ? 8'd1 : 8'd0; m_carry = 0; m_overflow = 0; end
            default: begin m_y = 0; m_carry = 0; m_overflow = 0; end
        endcase
        m_zero = (m_y == 0);
        m_negative = m_y[7];
    end

    initial begin
        passed = 0; total = 0;
        a = 0; b = 0; op = 0;
        #1; // Wait for combinational settling

        // Test AND
        op = 3'b000; a = 8'hAA; b = 8'h55; #1; check; // y=0, z=1
        op = 3'b000; a = 8'hFF; b = 8'h0F; #1; check; // y=0x0F

        // Test OR
        op = 3'b001; a = 8'hAA; b = 8'h55; #1; check; // y=FF
        op = 3'b001; a = 8'h0F; b = 8'hF0; #1; check; // y=FF

        // Test XOR
        op = 3'b010; a = 8'hAA; b = 8'h55; #1; check; // y=FF
        op = 3'b010; a = 8'hAA; b = 8'hAA; #1; check; // y=0, z=1

        // Test ADD
        op = 3'b011; a = 8'd10; b = 8'd20; #1; check; // y=30
        op = 3'b011; a = 8'hFF; b = 8'd1; #1; check;  // y=0, z=1, c=1
        op = 3'b011; a = 8'h7F; b = 8'd1; #1; check;  // y=80 (signed -128), o=1
        op = 3'b011; a = 8'h80; b = 8'h80; #1; check; // y=0, z=1, c=1, o=0

        // Test SUB
        op = 3'b100; a = 8'd20; b = 8'd10; #1; check; // y=10, c=1
        op = 3'b100; a = 8'd10; b = 8'd20; #1; check; // y= -10 (unsigned 246), c=0
        op = 3'b100; a = 8'h80; b = 8'h01; #1; check; // y=7F, o=1 (signed: -128 - 1 = -129 -> overflow)
        op = 3'b100; a = 8'h7F; b = 8'h80; #1; check; // y=FF, o=1 (signed: 127 - (-128) = 255 -> overflow)
        op = 3'b100; a = 8'h00; b = 8'h00; #1; check; // y=0, z=1, c=1

        // Test SRA
        op = 3'b101; a = 8'b1000_0001; b = 0; #1; check; // y=1000_0000 (signed -128), c=1, n=1
        op = 3'b101; a = 8'b0100_0001; b = 0; #1; check; // y=0010_0000, c=1, n=0

        // Test ROL
        op = 3'b110; a = 8'b1000_0001; b = 0; #1; check; // y=0000_0011 (wait: no, bit7 moves to bit0) -> y=0000_0011 is wrong.
        // ROL a[6:0], a[7] -> {a[6:0], a[7]}
        // a = 1000_0001 (8'h81). a[6:0]=000_0001, a[7]=1. y=0000_0011? No. {a[6:0], a[7]} is 0000_0011 if bit 7 was at pos 0.
        // Let's re-verify ROL logic in design: y_reg = {a[6:0], a[7]}; Correct.
        // For a=8'h81 (1000_0001): a[6:0]=000_0001, a[7]=1. Result is 0000_0011? No, that's 4 bits.
        // For 8-bit: {a[6:0], a[7]} = {0000001, 1} = 00000011 (Wait, that is only 7 bits).
        // Ah, the concatenation {a[6:0], a[7]} results in an 8-bit value.
        // If a=1000_0001, then a[6:0]=0000001, a[7]=1. Result = 00000011? No.
        // Let's re-calculate: a[6] is bit 6. a[0] is bit 0.
        // a = 1000_0001. bits are [7]=1, [6]=0, [5]=0, [4]=0, [3]=0, [2]=0, [1]=0, [0]=1.
        // a[6:0] is 0000001. {a[6:0], a[7]} is 00000011? No, that's 8 bits total. 
        // Let's trace: bit 7 moves to pos 0. Bits 0-6 move to 1-7.
        // So y[0] = a[7], y[1] = a[0], y[2] = a[1] ... y[7] = a[6].
        // My manual trace was wrong, the code {a[6:0], a[7]} is correct.
        // For a=8'h81 (1000_0001): a[6:0]=0000001, a[7]=1. y = 00000011? No, that's only 7 bits if I am not careful.
        // {a[6:0], a[7]} is (7 bits) + (1 bit) = 8 bits.
        // a=1000_0001 -> a[6:0]=0000001, a[7]=1. y = 00000011? No, that's 2^1 + 2^0 = 3.
        // Let's re-check: bit 7 (val 128) moves to bit 0 (val 1). Bits 0-6 move up.
        // a[0] was 1, now it is at y[1]. So y=...0010 + ...0001 = 3. Correct.
        op = 3'b110; a = 8'h81; #1; check; // y=3, c=1 (a[7]=1)
        op = 3'b110; a = 8'h01; #1; check; // y=2, c=0

        // Test SLT
        op = 3'b111; a = 8'd5; b = 8'd10; #1; check; // y=1
        op = 3'b111; a = 8'd10; b = 8'd5; #1; check; // y=0
        op = 3'b111; a = -8'd5; b = 8'd2; #1; check; // y=1 (signed)
        op = 3'b111; a = 8'h7F; b = 8'h80; #1; check; // y=1 (127 < -128 is false, wait. 127 < -128 is false)
        // SLT: 127 < -128? No. So y=0.
        op = 3'b111; a = 8'h80; b = 8'h7F; #1; check; // y=0 (-128 < 127 is true) -> y=1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
