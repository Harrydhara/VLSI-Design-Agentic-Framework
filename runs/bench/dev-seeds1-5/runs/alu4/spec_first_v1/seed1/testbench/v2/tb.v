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

    // Verification variables
    integer i, j, k;
    reg [4:0] expected_sum;
    reg [3:0] expected_y;
    reg expected_carry;
    reg expected_overflow;
    reg expected_zero;
    reg expected_negative;
    
    integer passed;
    integer total;

    // Task to perform a single test case and verify against reference model
    task run_test;
        input [2:0] o;
        input [3:0] va;
        input [3:0] vb;
        begin
            a = va; 
            b = vb; 
            op = o;
            #1; // Wait for combinational logic to settle
            
            // Reference Model Calculation
            case (op)
                3'b000: begin // ADD
                    expected_sum = a + b;
                    expected_y = expected_sum[3:0];
                    expected_carry = expected_sum[4];
                    expected_overflow = (a[3] == b[3]) && (expected_y[3] != a[3]);
                end
                3'b001: begin // SUB
                    // Specification says carry is 1 when a >= b as unsigned
                    expected_carry = (a >= b);
                    expected_y = a - b;
                    // Overflow for subtraction: (a[3] != b[3]) && (y[3] != a[3])
                    expected_overflow = (a[3] != b[3]) && (expected_y[3] != a[3]);
                end
                3'b010: begin // AND
                    expected_y = a & b;
                    expected_carry = 0;
                    expected_overflow = 0;
                end
                3'b011: begin // OR
                    expected_y = a | b;
                    expected_carry = 0;
                    expected_overflow = 0;
                end
                3'b100: begin // XOR
                    expected_y = a ^ b;
                    expected_carry = 0;
                    expected_overflow = 0;
                end
                3'b101: begin // SHL
                    expected_y = {a[2:0], 1'b0};
                    expected_carry = a[3];
                    expected_overflow = 0;
                end
                3'b110: begin // SHR
                    expected_y = {1'b0, a[3:1]};
                    expected_carry = a[0];
                    expected_overflow = 0;
                end
                3'b111: begin // SLT (Signed)
                    if ($signed(a) < $signed(b)) expected_y = 4'd1;
                    else expected_y = 4'd0;
                    expected_carry = 0;
                    expected_overflow = 0;
                end
                default: ;
            endcase

            expected_zero = (expected_y == 4'b0);
            expected_negative = expected_y[3];

            total = total + 1;
            if ((y !== expected_y) || (zero !== expected_zero) || (carry !== expected_carry) || 
                (overflow !== expected_overflow) || (negative !== expected_negative)) begin
                $display("FAIL: op=%b a=%b b=%b | exp: y=%b z=%b c=%b o=%b n=%b | act: y=%b z=%b c=%b o=%b n=%b", 
                         op, a, b, expected_y, expected_zero, expected_carry, expected_overflow, expected_negative,
                         y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // Exhaustive testing for all op/a/b combinations
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                for (k = 0; k < 16; k = k + 1) begin
                    run_test(i[2:0], j[3:0], k[3:0]);
                end
            end
        end

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
