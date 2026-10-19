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
                default: begin
                    m_y = 4'b0; m_carry = 0; m_overflow = 0;
                end
            endcase
            m_zero = (m_y == 4'b0);
            m_negative = m_y[3];
        end
    endtask

    // Fixed task: Verilog-2005 requires input declarations inside the task header or using a specific style.
    // The error was likely due to how parameters were passed in some compilers. 
    // Using standard task syntax.
    task run_test(input [3:0] ta, input [3:0] tb_val, input [2:0] top);
        begin
            a = ta; b = tb_val; op = top;
            #1; 
            update_model();
            check();
        end
    endtask

    initial begin
        passed = 0; total = 0;
        
        // ADD tests
        run_test(4'd5, 4'd3, 3'b000);  
        run_test(4'd7, 4'd1, 3'b000);  
        run_test(4'd8, 4'd8, 3'b000);  
        run_test(4'd7, 4'd7, 3'b000);  
        run_test(4'd15, 4'd1, 3'b000); 
        run_test(4'd10, 4'd10, 3'b000);

        // SUB tests
        run_test(4'd5, 4'd3, 3'b001);  
        run_test(4'd3, 4'd5, 3'b001);  
        run_test(4'd0, 4'd0, 3'b001);  
        run_test(4'd7, 4'd8, 3'b001);  
        run_test(4'd7, 4'd0, 3'b001);  
        run_test(4'd8, 4'd0, 3'b001);  
        run_test(4'd7, 4'd15, 3'b001); 
        run_test(4'd15, 4'd7, 3'b001); 

        // AND/OR/XOR tests
        run_test(4'b1010, 4'b1100, 3'b010); 
        run_test(4'b1010, 4'b1100, 3'b011); 
        run_test(4'b1010, 4'b1100, 3'b100); 
        run_test(4'b0000, 4'b1111, 3'b010); 

        // SHL/SHR tests
        run_test(4'b1011, 4'd0, 3'b101);   
        run_test(4'b0111, 4'd0, 3'b101);   
        run_test(4'b1011, 4'd0, 3'b110);   
        run_test(4'b0111, 4'd0, 3'b110);   

        // SLT tests
        run_test(4'd2, 4'd5, 3'b111);      
        run_test(4'd5, 4'd2, 3'b111);      
        run_test(4'd15, 4'd0, 3'b111);     // -1 < 0 (signed)
        run_test(4'd0, 4'd15, 3'b111);     // 0 < -1 (signed) is false
        run_test(4'd7, 4'd8, 3'b111);      // 7 < -8 (signed) is false

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
