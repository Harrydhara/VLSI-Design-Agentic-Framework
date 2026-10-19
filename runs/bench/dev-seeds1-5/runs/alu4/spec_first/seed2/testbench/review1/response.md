1. For each failing check:
- Quoted sentence: "SLT 1 if a < b as signed two's complement numbers, otherwise 0"
- Required value for `a=0, b=8`: Since `a` (0) is treated as signed 0 and `b` (8) is treated as signed -8 in 4-bit two's complement, the comparison $0 < -8$ is false. Therefore, `y` should be 0.
- My testbench expected value: `y=0`. This matches the specification.

- Quoted sentence: "SLT 1 if a < b as signed two's complement numbers, otherwise 0"
- Required value for `a=0, b=15`: Since `a` (0) is treated as signed 0 and `b` (15) is treated as signed -1 in 4-bit two's complement, the comparison $0 < -1$ is false. Therefore, `y` should be 0.
- My testbench expected value: `y=0`. This matches the specification.

The design's actual output (`y=1`) for these cases indicates that the design is incorrectly performing an unsigned comparison (where $0 < 8$ is true) or has a logic error in its signed interpretation, rather than the testbench being wrong. The testbench correctly implements the "signed two's complement" requirement using `$signed()`.

TESTBENCH OK