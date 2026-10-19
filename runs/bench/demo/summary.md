# Benchmark results

2026-10-15 17:30 · model `gemma4:26b` (temperature 0.2, think False) · up to 3 attempts · budget 50000 tokens · seeds [1, 2, 3]

Strategies: `default` = /mnt/c/Users/harrydhara16/Documents/Claude framework/prompts/default, `tb_timing` = /mnt/c/Users/harrydhara16/Documents/Claude framework/prompts/examples/tb_timing

**One-shot** is the hidden reference result for attempt 1; **iterative** is the result for the final design. Both come from the same runs (paired). **fixed** = one-shot failed but the final design passed; **broken** = one-shot passed but a revision made it fail. **Own checks passed** = the agent's own development checks accepted its design. Counts are shown as passed/runs.

## By strategy

| strategy | runs | one-shot pass | iterative pass | fixed | broken | pass after 1 | pass after 2 | pass after 3 | own checks passed | mean attempts | mean tokens | mean s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| default | 3 | 0/3 | 3/3 | 3 | 0 | 0/3 | 3/3 | 3/3 | 3/3 | 2 | 1597 | 0.9 |
| tb_timing | 3 | 0/3 | 3/3 | 3 | 0 | 0/3 | 3/3 | 3/3 | 3/3 | 2 | 2318 | 0.7 |

## By split

| strategy / split | runs | one-shot pass | iterative pass | fixed | broken | pass after 1 | pass after 2 | pass after 3 | own checks passed | mean attempts | mean tokens | mean s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| default / dev | 3 | 0/3 | 3/3 | 3 | 0 | 0/3 | 3/3 | 3/3 | 3/3 | 2 | 1597 | 0.9 |
| tb_timing / dev | 3 | 0/3 | 3/3 | 3 | 0 | 0/3 | 3/3 | 3/3 | 3/3 | 2 | 2318 | 0.7 |

## By circuit

| circuit / strategy | runs | one-shot pass | iterative pass | fixed | broken | pass after 1 | pass after 2 | pass after 3 | own checks passed | mean attempts | mean tokens | mean s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| adder4 / default | 3 | 0/3 | 3/3 | 3 | 0 | 0/3 | 3/3 | 3/3 | 3/3 | 2 | 1597 | 0.9 |
| adder4 / tb_timing | 3 | 0/3 | 3/3 | 3 | 0 | 0/3 | 3/3 | 3/3 | 3/3 | 2 | 2318 | 0.7 |

## Compile, synthesis and area

Cell counts are compared only for designs that pass the reference test, all synthesized with the same Yosys `synth` flow. They are a rough area proxy, not real power, area or timing.

| circuit / strategy | compiled (one-shot -> final) | synthesized (one-shot -> final) | median cells (passing final designs) |
|---|---|---|---|
| adder4 / default | 3/3 -> 3/3 | 3/3 -> 3/3 | 23 |
| adder4 / tb_timing | 3/3 -> 3/3 | 3/3 -> 3/3 | 23 |
