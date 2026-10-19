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

    // Reference model logic
    reg [3:0] m_y;
    reg       m_zero, m_carry, m_overflow, m_negative;

    task check;
        begin
            total = total + 1;
            if (y === m_y && zero === m_zero && carry === m_carry && overflow === m_overflow && negative === m_negative) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: a=%d b=%d op=%d | expected y=%d z=%b c=%b o=%b n=%b, actual y=%d z=%b c=%b o=%b n=%b",
                         a, b, op, m_y, m_zero, m_carry, m_overflow, m_negative, 
                         y, zero, carry, overflow, negative);
            end
        end
    endtask

    task update_model;
        begin
            case (op)
                3'b000: begin // ADD
                    {m_carry, m_y} = a + b;
                    m_overflow = (a[3] == b[3]) && (m_y[3] != a[3]);
                end
                3'b001: begin // SUB
                    m_carry = (a >= b);
                    m_y = a - b;
                    m_overflow = (a[3] != b[3]) && (m_y[3] != a[3]);
                end
                3'b010: begin // AND
                    m_y = a & b; m_carry = 0; m_overflow = 0;
                end
                3'b011: begin // OR
                    m_y = a | b; m_carry = 0; m_overflow = 0;
                end
                3'b100: begin // XOR
                    m_y = a ^ b; m_carry = 0; m_overflow = 0;
                end
                3'b101: begin // SHL
                    m_y = {a[2:0], 1'b0}; m_carry = a[3]; m_overflow = 0;
                end
                3'b110: begin // SHR
                    m_y = {1'b0, a[3:1]}; m_carry = a[0]; m_overflow = 0;
                end
                3'b111: begin // SLT
                    if ($signed(a) < $signed(b)) m_y = 4'h1; else m_y = 4'h0;
                    m_carry = 0; m_overflow = 0;
                end
            endcase
            m_zero = (m_y == 4'b0);
            m_negative = m_y[3];
        end
    endtask

    task run_test(input [3:0] ta, input [3:0] tb_val, input [2:0] top);
        begin
            a = ta; b = tb_val; op = top;
            #1; // Wait for combinational logic
            update_model();
            check();
        end
    endtask

    initial begin
        passed = 0; total = 0;
        
        // ADD tests
        run_test(4'd5, 4'd3, 3'b000);  // 5+3=8 (y=8, c=0, ov=0)
        run_test(4'd7, 4'd1, 3'b000);  // 7+1=8 (y=8, c=0, ov=0)
        run_test(4'd8, 4'd8, 3'b000);  // 8+8=16 (y=0, c=1, ov=0)
        run_test(4'd7, 4'd7, 3'b000);  // 7+7=14 (y=14, c=0, ov=1: pos+pos=neg)
        run_test(4'd15, 4'd1, 3'b000); // 15+1=16 (y=0, c=1, ov=0)
        run_test(4'd10, 4'd10, 3'b000);// 10+10=20 (y=4, c=1, ov=1: neg+neg=pos)

        // SUB tests
        run_test(4'd5, 4'd3, 3'b001);  // 5-3=2 (y=2, c=1, ov=0)
        run_test(4'd3, 4'd5, 3'b001);  // 3-5=-2 (y=14, c=0, ov=0)
        run_test(4'd0, 4'd0, 3'b001);  // 0-0=0 (y=0, c=1, ov=0)
        run_test(4'd7, 4'd8, 3'b001);  // 7-8=-1 (y=15, c=0, ov=0)
        run_test(4'd7, 4'd0, 3'b001);  // 7-0=7 (y=7, c=1, ov=0)
        run_test(4'd8, 4'd0, 3'b001);  // -8-0=-8 (y=8, c=1, ov=0)
        run_test(4'd7, 4'd15, 3'b001); // 7-(-1)=8 (y=8, c=0, ov=1: pos-neg=neg)
        run_test(4'd15, 4'd7, 3'b001); // -1-7=-8 (y=8, c=1, ov=1: neg-pos=pos)

        // AND/OR/XOR tests
        run_test(4'b1010, 4'b1100, 3'b010); // AND -> 1000
        run_test(4'b1010, 4'b1100, 3'b011); // OR  -> 1110
        run_test(4'b1010, 4'b1100, 3'b100); // XOR -> 0110
        run_test(4'b0000, 4'b1111, 3'b010); // AND zero test

        // SHL/SHR tests
        run_test(4'b1011, 4'd0, 3'b101);   // SHL -> 0110 (c=1)
        run_test(4'b0111, 4'd0, 3'b101);   // SHL -> 1110 (c=0)
        run_test(4'b1011, 4'd0, 3'b110);   // SHR -> 0101 (c=1)
        run_test(4'b0111, 4'd0, 3'b110);   // SHR -> 0011 (c=1)

        // SLT tests
        run_test(4'd2, 4'd5, 3'b111);      // 2 < 5 -> 1
        run_test(4'd5, 4'd2, 3'b111);      // 5 < 2 -> 0
        run_test(4'd-8, 4'd7, 3'b111);     // -8 < 7 -> 1
        run_test(4'd7, 4'd-8, 3'b111);     // 7 < -8 -> 0
        run_test(4'd-1, 4'd-2, 3'b111);    // -1 < -2 -> 0
        run_test(4'd-2, 4'd-1, 3'b111);    // -2 < -1 -> 1

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
