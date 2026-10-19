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

    // Reference Model and Verification Logic
    integer i, j, k;
    integer total_checks;
    integer passed_checks;
    
    reg [3:0] ref_y;
    reg ref_zero;
    reg ref_carry;
    reg ref_overflow;
    reg ref_negative;

    // Helper to perform signed comparison correctly for 4-bit
    function signed [3:0] to_signed(input [3:0] val);
        begin
            if (val[3]) to_signed = {val[3], val[3:0]}; // Sign extend
            else        to_signed = {1'b0, val};
        end
    endfunction

    initial begin
        total_checks = 0;
        passed_checks = 0;

        for (i = 0; i < 8; i = i + 1) begin // op
            for (j = 0; j < 16; j = j + 1) begin // a
                for (k = 0; k < 16; k = k + 1) begin // b
                    op = i[2:0];
                    a = j[3:0];
                    b = k[3:0];

                    // Reference Model Calculation
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
                            ref_y = a - b;
                            ref_carry = (a >= b);
                            if (a[3] != b[3] && ref_y[3] != a[3])
                                ref_overflow = 1'b1;
                        end
                        3'b010: begin // AND
                            ref_y = a & b;
                        end
                        3'b011: begin // OR
                            ref_y = a | b;
                        end
                        3'b100: begin // XOR
                            ref_y = a ^ b;
                        end
                        3'b101: begin // SHL
                            ref_y = {a[2:0], 1'b0};
                            ref_carry = a[3];
                        end
                        3'b110: begin // SHR
                            ref_y = {1'b0, a[3:1]};
                            ref_carry = a[0];
                        end
                        3'b111: begin // SLT (Signed)
                            // Manual signed comparison for 4-bit to avoid ambiguity with $signed
                            // A number is negative if bit 3 is 1.
                            // We compare the values as 5-bit sign-extended integers.
                            if (((a[3] ? {1'b1, a} : {1'b0, a}) < (b[3] ? {1'b1, b} : {1'b0, b})))
                                ref_y = 4'd1;
                            else
                                ref_y = 4'd0;
                        end
                    endcase

                    ref_zero = (ref_y == 4'b0);
                    ref_negative = ref_y[3];

                    #1; // Wait for combinational logic

                    if (y !== ref_y || zero !== ref_zero || carry !== ref_carry || 
                        overflow !== ref_overflow || negative !== ref_negative) begin
                        $display("FAIL: op=%b a=%d b=%d | exp: y=%d z=%b c=%b o=%b n=%b | act: y=%d z=%b c=%b o=%b n=%b",
                            op, a, b, ref_y, ref_zero, ref_carry, ref_overflow, ref_negative,
                            y, zero, carry, overflow, negative);
                    end else begin
                        passed_checks = passed_checks + 1;
                    end
                    total_checks = total_checks + 1;
                end
            end
        end

        $display("RESULT: %0d/%0d passed", passed_checks, total_checks);
        $finish;
    end

endmodule
```