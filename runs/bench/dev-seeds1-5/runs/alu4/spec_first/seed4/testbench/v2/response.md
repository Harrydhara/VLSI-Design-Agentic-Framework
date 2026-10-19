```verilog
module tb;
    // Inputs
    reg [3:0] a;
    reg [3:0] b;
    reg [2:0] op;

    // Outputs
    wire [3:0] y;
    wire zero;
    wire carry;
    wire overflow;
    wire negative;

    // Instantiate the Unit Under Test (UUT)
    alu4 uut (
        .a(a),
        .b(b),
        .op(op),
        .y(y),
        .zero(zero),
        .carry(carry),
        .overflow(overflow),
        .negative(negative)
    );

    // Verification Logic
    integer i, j, k;
    integer total_checks;
    integer passed_checks;
    
    reg [3:0] ref_y;
    reg ref_zero;
    reg ref_carry;
    reg ref_overflow;
    reg ref_negative;

    // Task to perform the check
    task run_test;
        input [2:0] test_op;
        input [3:0] test_a;
        input [3:0] test_b;
        begin
            a = test_a;
            b = test_b;
            op = test_op;
            #1; // Wait for combinational logic to settle
            
            total_checks = total_checks + 1;

            // Reference Model calculation
            ref_y = 4'b0;
            ref_carry = 1'b0;
            ref_overflow = 1'b0;
            
            case (op)
                3'b000: begin // ADD
                    {ref_carry, ref_y} = a + b;
                    if (a[3] == b[3] && ref_y[3] != a[3]) 
                        ref_overflow = 1'b1;
                end
                3'b001: begin // SUB
                    // Carry is 1 when a >= b as unsigned
                    if (a >= b) ref_carry = 1'b1;
                    else        ref_carry = 1'b0;
                    ref_y = a - b;
                    // Overflow: (a[3] != b[3]) && (y[3] != a[3])
                    if (a[3] != b[3] && ref_y[3] != a[3])
                        ref_overflow = 1'b1;
                end
                3'b010: begin // AND
                    ref_y = a & b;
                    ref_carry = 1'b0;
                    ref_overflow = 1'b0;
                end
                3'b011: begin // OR
                    ref_y = a | b;
                    ref_carry = 1'b0;
                    ref_overflow = 1'b0;
                end
                3'b100: begin // XOR
                    ref_y = a ^ b;
                    ref_carry = 1'b0;
                    ref_overflow = 1'b0;
                end
                3'b101: begin // SHL
                    ref_y = a << 1;
                    ref_carry = a[3];
                    ref_overflow = 1'b0;
                end
                3'b110: begin // SHR
                    ref_y = a >> 1;
                    ref_carry = a[0];
                    ref_overflow = 1'b0;
                end
                3'b111: begin // SLT (Signed)
                    if ($signed(a) < $signed(b)) ref_y = 4'd1;
                    else                         ref_y = 4'd0;
                    ref_carry = 1'b0;
                    ref_overflow = 1'b0;
                end
            endcase

            ref_zero = (ref_y == 4'b0);
            ref_negative = ref_y[3];

            // Comparison
            if (y !== ref_y || zero !== ref_zero || carry !== ref_carry || 
                overflow !== ref_overflow || negative !== ref_negative) begin
                $display("FAIL: op=%b a=%d b=%d | Exp: y=%d z=%b c=%b o=%b n=%b | Act: y=%d z=%b c=%b o=%b n=%b",
                         op, a, b, ref_y, ref_zero, ref_carry, ref_overflow, ref_negative,
                         y, zero, carry, overflow, negative);
            end else begin
                passed_checks = passed_checks + 1;
            end
        end
    endtask

    initial begin
        passed_checks = 0;
        total_checks = 0;

        // Exhaustive testing for all operations and inputs
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                for (k = 0; k < 16; k = k + 1) begin
                    run_test(i[2:0], j[3:0], k[3:0]);
                end
            end
        end

        $display("RESULT: %0d/%0d passed", passed_checks, total_checks);
        $finish;
    end

endmodule
```