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
                3'b000: expected_y = ta & tb_val; // AND
                3'b001: expected_y = ta | tb_val; // OR
                3'b010: expected_y = ta ^ tb_val; // XOR
                3'b011: begin                      // ADD
                    sum_ext = ta + tb_val;
                    expected_y = sum_ext[7:0];
                    expected_carry = sum_ext[8];
                    if (ta[7] == tb_val[7] && expected_y[7] != ta[7])
                        expected_overflow = 1;
                end
                3'b100: begin                      // SUB
                    sub_ext = {1'b0, ta} - {1'b0, tb_val};
                    expected_y = sub_ext[7:0];
                    expected_carry = (ta >= tb_val) ? 1 : 0;
                    // Overflow for SUB: different signs and result sign differs from 'a'
                    if (ta[7] != tb_val[7] && expected_y[7] != ta[7])
                        expected_overflow = 1;
                end
                3'b101: begin                      // SRA
                    expected_y = {ta[7], ta[7:1]};
                    expected_carry = ta[0];
                end
                3'b110: begin                      // ROL
                    expected_y = {ta[6:0], ta[7]};
                    expected_carry = ta[7];
                end
                3'b111: begin                      // SLT (Signed)
                    a_signed = $signed(ta);
                    b_signed = $signed(tb_val);
                    if (a_signed < b_signed) expected_y = 8'd1;
                    else                     expected_y = 8'd0;
                end
            endcase

            expected_zero     = (expected_y == 8'b0);
            expected_negative = expected_y[7];

            // Comparison
            total = total + 1;
            if (y !== expected_y || zero !== expected_zero || carry !== expected_carry || 
                overflow !== expected_overflow || negative !== expected_negative) begin
                $display("FAIL: a=%d, b=%d, op=%b | Exp: y=%d z=%b c=%b o=%b n=%b | Act: y=%d z=%b c=%b o=%b n=%b",
                         ta, tb_val, top, expected_y, expected_zero, expected_carry, expected_overflow, expected_negative,
                         y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // Test Case 1: Logical Operations
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                a = i; b = j;
                check_alu(a, b, 3'b000); // AND
                check_alu(a, b, 3'b001); // OR
                check_alu(a, b, 3'b010); // XOR
            end
        end

        // Test Case 2: Arithmetic Operations (ADD/SUB)
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                a = i; b = j;
                check_alu(a, b, 3'b011); // ADD
                check_alu(a, b, 3'b100); // SUB
            end
        end

        // Test Case 3: Shifts and Rotates
        for (i = 0; i < 256; i = i + 1) begin
            a = i; b = 0;
            check_alu(a, b, 3'b101); // SRA
            check_alu(a, b, 3'b110); // ROL
        end

        // Test Case 4: SLT (Signed Comparison) - Corner cases and randoms
        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 256; j = j + 1) begin
                a = i; b = j;
                check_alu(a, b, 3'b111); // SLT
            end
        end

        // Specific Corner Cases for Overflow/Carry
        a = 8'h7F; b = 8'h01; op = 3'b011; // ADD: Max pos + 1 -> overflow
        check_alu(a, b, op);
        a = 8'h80; b = 8'h01; op = 3'b100; // SUB: Min neg - 1 -> overflow
        check_alu(a, b, op);
        a = 8'h00; b = 8'h01; op = 3'b100; // SUB: 0 - 1 -> carry (borrow) should be 0 per spec (a >= b is false)
        check_alu(a, b, op);
        a = 8'h01; b = 8'h01; op = 3'b100; // SUB: a >= b -> carry 1
        check_alu(a, b, op);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```