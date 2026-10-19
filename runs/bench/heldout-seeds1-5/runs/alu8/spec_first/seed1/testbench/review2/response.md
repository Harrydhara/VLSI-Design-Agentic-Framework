1. For each failing check:
- `FAIL: op=000 a=aa b=00 | exp: y=00 z=1 c=0 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 000 AND a & b" requires `y=00`. "zero is 1 exactly when y == 0" requires `z=1`. My testbench expected value matches.
- `FAIL: op=011 a=00 b=01 | exp: y=01 z=0 c=0 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 011 ADD a + b (low 8 bits)" requires `y=01`. My testbench expected value matches.
- `FAIL: op=100 a=00 b=ff | exp: y=01 z=0 c=0 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 100 SUB a - b (low 8 bits)" requires `y=01`. My testbench expected value matches.
- `FAIL: op=000 a=aa b=01 | exp: y=00 z=1 c=0 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 000 AND a & b" requires `y=00`. "zero is 1 exactly when y == 0" requires `z=1`. My testbench expected value matches.
- `FAIL: op=011 a=01 b=02 | exp: y=03 z=0 c=0 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 011 ADD a + b (low 8 bits)" requires `y=03`. My testbench expected value matches.
- `FAIL: op=100 a=01 b=00 | exp: y=01 z=0 c=1 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 100 SUB a - b (low 8 bits)" requires `y=01`. "SUB: 1 exactly when a >= b as unsigned numbers" requires `c=1`. My testbench expected value matches.
- `FAIL: op=000 a=aa b=02 | exp: y=02 z=0 c=0 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 000 AND a & b" requires `y=02`. My testbench expected value matches.
- `FAIL: op=011 a=02 b=03 | exp: y=05 z=0 c=0 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 011 ADD a + b (low 8 bits)" requires `y=05`. My testbench expected value matches.
- `FAIL: op=100 a=02 b=01 | exp: y=01 z=0 c=1 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 100 SUB a - b (low 8 bits)" requires `y=01`. "SUB: 1 exactly when a >= b as unsigned numbers" requires `c=1`. My testbench expected value matches.
- `FAIL: op=000 a=aa b=03 | exp: y=02 z=0 c=0 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 000 AND a & b" requires `y=02`. My testbench expected value matches.
- `FAIL: op=011 a=03 b=04 | exp: y=07 z=0 c=0 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 011 ADD a + b (low 8 bits)" requires `y=07`. My testbench expected value matches.
- `FAIL: op=100 a=03 b=02 | exp: y=01 z=0 c=1 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 100 SUB a - b (low 8 bits)" requires `y=01`. "SUB: 1 exactly when a >= b as unsigned numbers" requires `c=1`. My testbench expected value matches.
- `FAIL: op=000 a=aa b=04 | exp: y=00 z=1 c=0 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 000 AND a & b" requires `y=00`. "zero is 1 exactly when y == 0" requires `z=1`. My testbench expected value matches.
- `FAIL: op=011 a=04 b=05 | exp: y=09 z=0 c=0 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 011 ADD a + b (low 8 bits)" requires `y=09`. My testbench expected value matches.
- `FAIL: op=100 a=04 b=03 | exp: y=01 z=0 c=1 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 100 SUB a - b (low 8 bits)" requires `y=01`. "SUB: 1 exactly when a >= b as unsigned numbers" requires `c=1`. My testbench expected value matches.
- `FAIL: op=000 a=aa b=05 | exp: y=00 z=1 c=0 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 000 AND a & b" requires `y=00`. "zero is 1 exactly when y == 0" requires `z=1`. My testbench expected value matches.
- `FAIL: op=011 a=05 b=06 | exp: y=0b z=0 c=0 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 011 ADD a + b (low 8 bits)" requires `y=0b`. My testbench expected value matches.
- `FAIL: op=100 a=05 b=04 | exp: y=01 z=0 c=1 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 100 SUB a - b (low 8 bits)" requires `y=01`. "SUB: 1 exactly when a >= b as unsigned numbers" requires `c=1`. My testbench expected value matches.
- `FAIL: op=000 a=aa b=06 | exp: y=02 z=0 c=0 v=0 n=0 | act: y=xx z=x c=x v=x n=x`: "op 000 AND a & b" requires `y=02`. My testbench expected value matches.

TESTBENCH OK