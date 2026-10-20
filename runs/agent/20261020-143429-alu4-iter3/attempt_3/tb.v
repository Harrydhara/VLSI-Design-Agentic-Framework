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

    task check_result;
        input [3:0] exp_y;
        input       exp_z;
        input       exp_c;
        input       exp_o;
        input       exp_n;
        begin
            total = total + 1;
            if (y !== exp_y || zero !== exp_z || carry !== exp_c || overflow !== exp_o || negative !== exp_n) begin
                $display("FAIL: op=%b a=%b b=%b | Exp: y=%b z=%b c=%b o=%b n=%b | Got: y=%b z=%b c=%b o=%b n=%b", 
                         op, a, b, exp_y, exp_z, exp_c, exp_o, exp_n, y, zero, carry, overflow, negative);
            end else begin
                passed = passed + 1;
            end
        end
    endtask

    initial begin
        passed = 0;
        total = 0;

        // ADD tests
        a = 4'd5; b = 4'd3; op = 3'b000; #1; // y=8, z=0, c=0, o=0, n=0
        check_result(4'd8, 0, 0, 0, 0);
        a = 4'd10; b = 4'd7; op = 3'b000; #1; // a=1010, b=0111. y=0001, c=1, o=0 (a[3]!=b[3])
        check_result(4'd1, 0, 1, 0, 0);
        a = 4'b1000; b = 4'b1000; op = 3'b000; #1; // a=-8, b=-8. y=0, c=1, o=(1==1 && 0!=1)=1
        check_result(4'd0, 1, 1, 1, 0);

        // SUB tests
        a = 4'd5; b = 4'd3; op = 3'b001; #1; // y=2, c=1 (5>=3), o=0, n=0
        check_result(4'd2, 0, 1, 0, 0);
        a = 4'd3; b = 4'd5; op = 3'b001; #1; // y=-2 (1110), c=0 (3<5), o=0 (a[3]==b[3])
        check_result(4'b1110, 0, 0, 0, 1);
        a = 4'b1000; b = 4'b0001; op = 3'b001; #1; // a=-8, b=1. y=7 (0111), c=0 (8<1 is false), o=(1!=0 && 0!=1)=1
        check_result(4'd7, 0, 0, 1, 0);

        // AND/OR/XOR tests
        a = 4'b1010; b = 4'b1100; op = 3'b010; #1; // AND: 1000
        check_result(4'b1000, 0, 0, 0, 1);
        a = 4'b1010; b = 4'b1100; op = 3'b011; #1; // OR: 1110
        check_result(4'b1110, 0, 0, 0, 1);
        a = 4'b1010; b = 4'b1100; op = 3'b100; #1; // XOR: 0110
        check_result(4'b0110, 0, 0, 0, 0);

        // SHL/SHR tests
        a = 4'b1011; op = 3'b101; #1; // SHL: y=0110, c=1
        check_result(4'b0110, 0, 1, 0, 0);
        a = 4'b1011; op = 3'b110; #1; // SHR: y=0101, c=1 (a[0]=1)
        check_result(4'b0101, 0, 1, 0, 0);
        a = 4'b0011; op = 3'b110; #1; // SHR: y=0001, c=1 (a[0]=1)
        check_result(4'b0001, 0, 1, 0, 0);

        // SLT tests
        a = 4'd2; b = 4'd3; op = 3'b111; #1; // 2 < 3 -> y=1
        check_result(4'd1, 0, 0, 0, 0);
        a = 4'b1111; b = 4'b0001; op = 3'b111; #1; // -1 < 1 -> y=1
        check_result(4'd1, 0, 0, 0, 0);
        a = 4'b0001; b = 4'b1111; op = 3'b111; #1; // 1 < -1 -> y=0
        check_result(4'd0, 1, 0, 0, 0);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end
endmodule
