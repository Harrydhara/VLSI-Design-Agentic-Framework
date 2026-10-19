module tb;
    reg [3:0] a, b;
    reg [2:0] op;
    wire [3:0] y;
    wire zero, carry, overflow, negative;

    integer passed, total;

    // Reference model outputs
    reg [3:0] m_y;
    reg       m_zero, m_carry, m_overflow, m_negative;

    alu4 dut (
        .a(a), .b(b), .op(op),
        .y(y), .zero(zero), .carry(carry), .overflow(overflow), .negative(negative)
    );

    task check;
        begin
            total = total + 1;
            if (y === m_y && zero === m_zero && carry === m_carry && overflow === m_overflow && negative === m_negative) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: a=%d b=%d op=%b | expected y=%b z=%b c=%b o=%b n=%b | actual y=%b z=%b c=%b o=%b n=%b",
                         a, b, op, m_y, m_zero, m_carry, m_overflow, m_negative, 
                         y, zero, carry, overflow, negative);
            end
        end
    endtask

    // Helper to update model based on spec logic
    task update_model;
        begin
            m_y = 0; m_zero = 0; m_carry = 0; m_overflow = 0; m_negative = 0;
            case (op)
                3'b000: begin // ADD
                    m_y = a + b;
                    m_carry = (a + b >= 16);
                    m_overflow = (a[3] == b[3]) && (m_y[3] != a[3]);
                end
                3'b001: begin // SUB
                    m_y = a - b;
                    m_carry = (a >= b);
                    m_overflow = (a[3] != b[3]) && (m_y[3] != a[3]);
                end
                3'b010: begin // AND
                    m_y = a & b;
                end
                3'b011: begin // OR
                    m_y = a | b;
                end
                3'b100: begin // XOR
                    m_y = a ^ b;
                end
                3'b101: begin // SHL
                    m_y = {a[2:0], 1'b0};
                    m_carry = a[3];
                end
                3'b110: begin // SHR
                    m_y = {1'b0, a[3:1]};
                    m_carry = a[0];
                end
                3'b111: begin // SLT
                    if ({a[3], a} < {b[3], b}) m_y = 4'h1; else m_y = 4'h0;
                end
            endcase
            m_zero = (m_y == 4'b0);
            m_negative = m_y[3];
        end
    endtask

    initial begin
        passed = 0; total = 0;
        a = 0; b = 0; op = 0;

        // Test ADD
        op = 3'b000; a = 4'd5; b = 4'd3; #1; update_model(); check(); // 8, c=0, ov=0
        op = 3'b000; a = 4'd10; b = 4'd7; #1; update_model(); check(); // 1, c=1, ov=1 (signed: -6 + -7 = -13)
        op = 3'b000; a = 4'd7; b = 4'd8; #1; update_model(); check(); // 15, c=0, ov=0
        op = 3'b000; a = 4'd15; b = 4'd1; #1; update_model(); check(); // 0, c=1, ov=0

        // Test SUB
        op = 3'b001; a = 4'd10; b = 4'd3; #1; update_model(); check(); // 7, c=1 (no borrow), ov=0
        op = 3'b001; a = 4'd3; b = 4'd10; #1; update_model(); check(); // 9, c=0 (borrow), ov=0
        op = 3'b001; a = 4'd7; b = 4'd8; #1; update_model(); check(); // -1(15), c=0, ov=0
        op = 3'b001; a = 4'd8; b = 4'd(-1); // 8 - (-1) is overflow for signed? No. 8 - 15 (signed).
        // Let's use explicit values: a=7(0111), b=-8(1000). 7 - (-8) = 15 (0111). Sign changed from + to +. Wait.
        // Spec says overflow for SUB is (a[3] != b[3]) && (y[3] != a[3]).
        op = 3'b001; a = 4'd7; b = 4'd8; #1; update_model(); check(); // a=0111, b=1000. y=0111-1000 = 1101 (signed -3).
        // a[3]=0, b[3]=1. y[3]=1. (0!=1) && (1!=0) is true. Overflow!
        op = 3'b001; a = 4'd7; b = 4'd8; #1; update_model(); check();

        // Test AND/OR/XOR
        op = 3'b010; a = 4'hF; b = 4'h5; #1; update_model(); check(); // 5
        op = 3'b011; a = 4'hA; b = 4'h5; #1; update_model(); check(); // F
        op = 3'b100; a = 4'hF; b = 4'h5; #1; update_model(); check(); // A

        // Test SHL/SHR
        op = 3'b101; a = 4'b1011; b = 0; #1; update_model(); check(); // y=0110, c=1
        op = 3'b110; a = 4'b1011; b = 0; #1; update_model(); check(); // y=0101, c=1

        // Test SLT
        op = 3'b111; a = 4'd2; b = 4'd5; #1; update_model(); check(); // 1
        op = 3'b111; a = 4'd5; b = 4'd2; #1; update_model(); check(); // 0
        op = 3'b111; a = 4'b1111; b = 4'b0001; #1; update_model(); check(); // -1 < 1 -> 1
        op = 3'b111; a = 4'b0001; b = 4'b1111; #1; update_model(); check(); // 1 < -1 -> 0

        // Test Zero/Negative
        op = 3'b010; a = 4'h0; b = 4'h0; #1; update_model(); check(); // y=0, z=1, n=0
        op = 3'b010; a = 4'h8; b = 4'h0; #1; update_model(); check(); // y=8, z=0, n=1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
