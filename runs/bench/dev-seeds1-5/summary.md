# Benchmark results

2026-10-15 18:52 · model `gemma4:26b` (temperature 0.2, think False) · up to 3 attempts · budget 50000 tokens · seeds [1, 2, 3, 4, 5]

Strategies: `default` = prompts/default, `tb_timing` = prompts/examples/tb_timing, `spec_first_v1` = prompts/examples/spec_first_v1, `spec_first` = prompts/examples/spec_first

**One-shot** is the hidden reference result for attempt 1; **iterative** is the result for the final design. Both come from the same runs (paired). **fixed** = one-shot failed but the final design passed; **broken** = one-shot passed but a revision made it fail. **Own checks passed** = the agent's own development checks accepted its design. Counts are shown as passed/runs.

## By strategy

| strategy | runs | one-shot pass | iterative pass | fixed | broken | pass after 1 | pass after 2 | pass after 3 | own checks passed | mean attempts | mean tokens | mean s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| default | 25 | 24/25 | 24/25 | 0 | 0 | 24/25 | 24/25 | 24/25 | 19/25 | 1.7 | 7296.5 | 16.6 |
| tb_timing | 25 | 23/25 | 22/25 | 0 | 1 | 23/25 | 22/25 | 22/25 | 23/25 | 1.6 | 5905.7 | 15.9 |
| spec_first_v1 | 25 | 23/25 | 24/25 | 1 | 0 | 23/25 | 24/25 | 24/25 | 24/25 | 1.2 | 5984.6 | 15.4 |
| spec_first | 25 | 23/25 | 23/25 | 2 | 2 | 23/25 | 24/25 | 23/25 | 22/25 | 1.4 | 6744 | 15.6 |

## By split

| strategy / split | runs | one-shot pass | iterative pass | fixed | broken | pass after 1 | pass after 2 | pass after 3 | own checks passed | mean attempts | mean tokens | mean s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| default / dev | 25 | 24/25 | 24/25 | 0 | 0 | 24/25 | 24/25 | 24/25 | 19/25 | 1.7 | 7296.5 | 16.6 |
| tb_timing / dev | 25 | 23/25 | 22/25 | 0 | 1 | 23/25 | 22/25 | 22/25 | 23/25 | 1.6 | 5905.7 | 15.9 |
| spec_first_v1 / dev | 25 | 23/25 | 24/25 | 1 | 0 | 23/25 | 24/25 | 24/25 | 24/25 | 1.2 | 5984.6 | 15.4 |
| spec_first / dev | 25 | 23/25 | 23/25 | 2 | 2 | 23/25 | 24/25 | 23/25 | 22/25 | 1.4 | 6744 | 15.6 |

## By circuit

| circuit / strategy | runs | one-shot pass | iterative pass | fixed | broken | pass after 1 | pass after 2 | pass after 3 | own checks passed | mean attempts | mean tokens | mean s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| adder4 / default | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1.4 | 2619.6 | 7.4 |
| adder4 / tb_timing | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1.4 | 3218.4 | 8.8 |
| adder4 / spec_first_v1 | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1 | 1385.2 | 4.8 |
| adder4 / spec_first | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1 | 1385.2 | 4.8 |
| alu4 / default | 5 | 4/5 | 4/5 | 0 | 0 | 4/5 | 4/5 | 4/5 | 0/5 | 3 | 23682 | 45.5 |
| alu4 / tb_timing | 5 | 4/5 | 3/5 | 0 | 1 | 4/5 | 3/5 | 3/5 | 5/5 | 1.8 | 9430 | 26.0 |
| alu4 / spec_first_v1 | 5 | 3/5 | 4/5 | 1 | 0 | 3/5 | 4/5 | 4/5 | 5/5 | 1.2 | 8343.2 | 21.8 |
| alu4 / spec_first | 5 | 3/5 | 5/5 | 2 | 0 | 3/5 | 4/5 | 5/5 | 5/5 | 1.6 | 10134.8 | 20.4 |
| counter4 / default | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1 | 1454.6 | 5.8 |
| counter4 / tb_timing | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1 | 1998.4 | 6.8 |
| counter4 / spec_first_v1 | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1.6 | 8410.8 | 17.7 |
| counter4 / spec_first | 5 | 5/5 | 3/5 | 0 | 2 | 5/5 | 5/5 | 3/5 | 3/5 | 2.2 | 11022.8 | 22.9 |
| mux2 / default | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1 | 1385 | 5.2 |
| mux2 / tb_timing | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1 | 1671.4 | 5.3 |
| mux2 / spec_first_v1 | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1 | 1690.2 | 6.3 |
| mux2 / spec_first | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 5/5 | 1 | 1690.2 | 6.5 |
| seqdet_moore / default | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 4/5 | 2 | 7341.2 | 18.9 |
| seqdet_moore / tb_timing | 5 | 4/5 | 4/5 | 0 | 0 | 4/5 | 4/5 | 4/5 | 3/5 | 2.6 | 13210.2 | 32.6 |
| seqdet_moore / spec_first_v1 | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 4/5 | 1.4 | 10093.4 | 26.5 |
| seqdet_moore / spec_first | 5 | 5/5 | 5/5 | 0 | 0 | 5/5 | 5/5 | 5/5 | 4/5 | 1.4 | 9487 | 23.6 |

## Compile, synthesis and area

Cell counts are compared only for designs that pass the reference test, all synthesized with the same Yosys `synth` flow. They are a rough area proxy, not real power, area or timing.

| circuit / strategy | compiled (one-shot -> final) | synthesized (one-shot -> final) | median cells (passing final designs) |
|---|---|---|---|
| adder4 / default | 5/5 -> 5/5 | 5/5 -> 5/5 | 23 |
| adder4 / tb_timing | 5/5 -> 5/5 | 5/5 -> 5/5 | 23 |
| adder4 / spec_first_v1 | 5/5 -> 5/5 | 5/5 -> 5/5 | 23 |
| adder4 / spec_first | 5/5 -> 5/5 | 5/5 -> 5/5 | 23 |
| alu4 / default | 5/5 -> 5/5 | 5/5 -> 5/5 | 134 |
| alu4 / tb_timing | 5/5 -> 5/5 | 5/5 -> 5/5 | 134 |
| alu4 / spec_first_v1 | 5/5 -> 5/5 | 5/5 -> 5/5 | 134 |
| alu4 / spec_first | 5/5 -> 5/5 | 5/5 -> 5/5 | 134 |
| counter4 / default | 5/5 -> 5/5 | 5/5 -> 5/5 | 10 |
| counter4 / tb_timing | 5/5 -> 5/5 | 5/5 -> 5/5 | 10 |
| counter4 / spec_first_v1 | 5/5 -> 5/5 | 5/5 -> 5/5 | 10 |
| counter4 / spec_first | 5/5 -> 4/5 | 5/5 -> 4/5 | 10 |
| mux2 / default | 5/5 -> 5/5 | 5/5 -> 5/5 | 8 |
| mux2 / tb_timing | 5/5 -> 5/5 | 5/5 -> 5/5 | 8 |
| mux2 / spec_first_v1 | 5/5 -> 5/5 | 5/5 -> 5/5 | 8 |
| mux2 / spec_first | 5/5 -> 5/5 | 5/5 -> 5/5 | 8 |
| seqdet_moore / default | 5/5 -> 5/5 | 5/5 -> 5/5 | 18 |
| seqdet_moore / tb_timing | 5/5 -> 5/5 | 5/5 -> 5/5 | 18 |
| seqdet_moore / spec_first_v1 | 5/5 -> 5/5 | 5/5 -> 5/5 | 18 |
| seqdet_moore / spec_first | 5/5 -> 5/5 | 5/5 -> 5/5 | 18 |
