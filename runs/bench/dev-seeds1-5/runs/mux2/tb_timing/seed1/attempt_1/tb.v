module tb;

    reg [7:0] a;
    reg [7:0] b;
    reg       sel;
    wire [7:0] y;

    integer passed;
    integer total;

    mux2 dut (
        .a(a),
        .b(b),
        .sel(sel),
        .y(y)
    );

    task check;
        begin
            total = total + 1;
            if (y === model_y) begin
                passed = passed + 1;
            end else begin
                $display("FAIL: time=%0d a=%0d b=%0d sel=%b expected=%0d actual=%0d", 
                         $time, a, b, sel, model_y, y);
            end
        end
    endtask

    reg [7:0] model_y;

    initial begin
        // Initialize
        a = 8'h00;
        b = 8'h00;
        sel = 1'b0;
        passed = 0;
        total = 0;
        model_y = 8'h00;

        // Test Case 1: sel=0, a=0xAA, b=0xBB
        #1;
        a = 8'hAA; b = 8'hBB; sel = 1'b0;
        model_y = a;
        #1;
        check();

        // Test Case 2: sel=1, a=0xAA, b=0xBB
        a = 8'hAA; b = 8'hBB; sel = 1'b1;
        model_y = b;
        #1;
        check();

        // Test Case 3: Corner case - all zeros
        a = 8'h00; b = 8'h00; sel = 1'b0;
        model_y = a;
        #1;
        check();

        // Test Case 4: Corner case - all ones
        a = 8'hFF; b = 8'hFF; sel = 1'b1;
        model_y = b;
        #1;
        check();

        // Test Case 5: Alternating bits
        a = 8'h55; b = 8'hAA; sel = 1'b0;
        model_y = a;
        #1;
        check();

        a = 8'h55; b = 8'hAA; sel = 1'b1;
        model_y = b;
        #1;
        check();

        // Test Case 6: Random values
        a = 8'h12; b = 8'h34; sel = 1'b0;
        model_y = a;
        #1;
        check();

        a = 8'h12; b = 8'h34; sel = 1'b1;
        model_y = b;
        #1;
        check();

        $display("RESULT: %0d/%0d passed", passed, total);
        $finish;
    end

endmodule
