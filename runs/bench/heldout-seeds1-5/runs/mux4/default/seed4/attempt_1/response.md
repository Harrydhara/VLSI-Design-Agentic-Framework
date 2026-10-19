```verilog
module mux4(
    input  [3:0] d0,
    input  [3:0] d1,
    input  [3:0] d2,
    input  [3:0] d3,
    input  [1:0] sel,
    output [3:0] y
);

    always @(*) begin
        case (sel)
            2'b00:   y = d0;
            2'b01:   y = d1;
            2'b10:   y = d2;
            2'b11:   y = d3;
            default: y = 4'b0000; // Should not be reached with 2-bit sel
        endcase
    end

endmodule
```

```verilog
module tb();

    reg [3:0] d0, d1, d2, d3;
    reg [1:0] sel;
    wire [3:0] y;

    integer i;
    integer passed;
    integer total;

    mux4 uut (
        .d0(d0),
        .d1(d1),
        .d2(d2),
        .d3(d3),
        .sel(sel),
        .y(y)
    );

    initial begin
        passed = 0;
        total = 0;

        // Test Case 1: Exhaustive check of all select lines with specific values
        d0 = 4'hA; d1 = 4'hB; d2 = 4'hC; d3 = 4'hD;
        
        // sel = 0
        sel = 2'b00; #1;
        total = total + 1;
        if (y === 4'hA) passed = passed + 1;
        else $display("FAIL: sel=%b, d0=%h, d1=%h, d2=%h, d3=%h, expected=4'hA, actual=%h", sel, d0, d1, d2, d3, y);

        // sel = 1
        sel = 2'b01; #1;
        total = total + 1;
        if (y === 4'hB) passed = passed + 1;
        else $display("FAIL: sel=%b, d0=%h, d1=%h, d2=%h, d3=%h, expected=4'hB, actual=%h", sel, d0, d1, d2, d3, y);

        // sel = 2
        sel = 2'b10; #1;
        total = total + 1;
        if (y === 4'hC) passed = passed + 1;
        else $display("FAIL: sel=%b, d0=%h, d1=%h, d2=%h, d3=%h, expected=4'hC, actual=%h", sel, d0, d1, d2, d3, y);

        // sel = 3
        sel = 2'b11; #1;
        total = total + 1;
        if (y === 4'hD) passed = passed + 1;
        else $display("FAIL: sel=%b, d0=%h, d1=%h, d2=%h, d3=%h, expected=4'hD, actual=%h", sel, d0, d1, d2, d3, y);

        // Test Case 2: All zeros
        d0 = 4'b0000; d1 = 4'b0000; d2 = 4'b0000; d3 = 4'b0000;
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0]; #1;
            total = total + 1;
            if (y === 4'b0000) passed = passed + 1;
            else $display("FAIL: sel=%b, expected=0, actual=%h", sel, y);
        end

        // Test Case 3: All ones
        d0 = 4'b1111; d1 = 4'b1111; d2 = 4'b1111; d3 = 4'b1111;
        for (i = 0; i < 4; i = i + 1) begin
            sel = i[1:0]; #1;
            total = total + 1;
            if (y === 4'b1111) passed = passed + 1;
            else $display("FAIL: sel=%b, expected=F, actual=%h", sel, y);
        end

        // Test Case 4: Random patterns
        d0 = 4'h5; d1 = 4'hA; d2 = 4'h3; d3 = 4'hE;
        sel = 2'b00; #1; total++; if(y===4'h5) passed++; else $display("FAIL: sel=0, exp=5, act=%h", y);
        sel = 2'b01; #1; total++; if(y===4'hA) passed++; else $display("FAIL: sel=1, exp=A, act=%h", y);
        sel = 2'b10; #1; total++; if(y===4'h3) passed++; else $display("FAIL: sel=2, exp=3, act=%h", y);
        sel = 2'b11; #1; total++; if(y===4'hE) passed++; else $display("FAIL: sel=3, exp=E, act=%h", y);

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
```