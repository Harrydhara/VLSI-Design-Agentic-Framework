# The learning path: how the site meets the final requirements

The dashboard (`vlsi-agent ui`, http://localhost:7860) is one self-contained page with five tabs. A visitor
reads them from left to right and moves from knowing nothing about Verilog to judging their own experiment.
The three levels follow [Bloom's taxonomy](https://tips.uark.edu/using-blooms-taxonomy/).

## Requirement by requirement

| Requirement | Where it is met | Code |
|---|---|---|
| User-controlled and intuitive | Every explorer, lab and tool is driven by the visitor's own choices (sliders, pickers, editors); each level ends with a button to the next | `dashboard.py` |
| Teaches what the domain covers | **Start here**: "What this site is about"; **Level 1**: lessons 1 to 6 and the glossary | `learn.START_HERE`, `learn.LESSON_*`, `learn.GLOSSARY` |
| Its importance | **Start here**: "Why it matters" (cost of hardware bugs, compiling is not correctness, a model's own tests can be wrong, with the measured 163 of 305) | `learn.START_HERE` |
| Who benefits | **Start here**: "Who benefits" (student, instructor, researcher, engineer) | `learn.START_HERE` |
| What to know before interacting | **Start here**: "What you should know before you start", and the "What it needs" column for each level | `learn.START_HERE`, `learn.LEVELS` |
| Beginner: Remember and Understand | **Level 1 · Beginner**: glossary, six lessons, four explorers, an eight-question quiz (four Remember, four Understand) with an explanation for every answer | `learn.py` |
| Intermediate: Apply and Analyze, on a preconfigured tool | **Level 2 · Intermediate**: four guided labs. **Set up this lab** preselects the circuit, the recorded run or the benchmark; the visitor then runs, inspects, draws a waveform, edits and re-tests. Each lab ends with two questions | `learn.LABS`, `dashboard.lab_setup` |
| Advanced: Evaluate and Create, with the visitor's own variations | **Level 3 · Advanced**: A. their own design and testbench, judged against the hidden test; B. their own prompt strategy; C. a comparison of any two runs that works out the facts and asks five reasoning questions; the result downloads as `evaluation.md` | `dashboard.check_own_design`, `strategy_editor.py`, `compare.py` |
| The tool helps evaluate choices and reason about observations | Level 3 names the case of every attempt (correct or wrong design, accepted or rejected by its own checks), states what follows (revising helped or hurt, tokens spent after the design was already correct, a missed bug), warns when two runs are not comparable, and says that one run each is an example and not a result | `compare.observations`, `compare.differences` |
| Inspect the technical code or developer view | **Developer view**: the data flow from a click to a chart, the function behind every control, a browser for every source file, and for any run its events, timing, messages to and from the model, and files | `devview.py` |
| Self-sufficient | Level 1, every recorded run in Level 2, the comparison in Level 3 and the Developer view need no model and no GPU. The scripted demo needs the tools only | `runs/`, `examples/scripted_adder4.json` |

## The three levels in detail

### Level 1 · Beginner (Remember, Understand)

| Lesson | Idea | Explorer |
|---|---|---|
| Words | Twelve terms used across the site | |
| 1 · Verilog | A module, `assign`, `always @(posedge clk)`, the header as a contract | |
| 2 · Signed numbers | The same bits read as unsigned or signed; sign extension does not make `<` signed | Two 8-bit values: both readings and `a < b` three ways |
| 3 · Testbenches | The RESULT line; a test only finds a bug its inputs reach | A correct adder and two faulty ones on chosen inputs, and how many of the 512 inputs expose each bug |
| 4 · Timing | A testbench that looks at the clock edge reads the old value | A slider for when the testbench looks, with the resulting waveform and RESULT line |
| 5 · Synthesis | Cells, latches, and what each tool does and does not prove | |
| 6 · The agent loop | The pipeline, development checks versus the hidden test | The four combinations of own checks and hidden test, with how often each occurred in the benchmark |
| Quiz | Four Remember and four Understand questions; 6 of 8 to continue | |

The explorers compute their answers (`learn.signed_explorer`, `adder_explorer`, `sampling_checks`,
`verdict_explorer`); nothing is a picture. Their starting values are the inputs of the bugs met again in Level 2.

### Level 2 · Intermediate (Apply, Analyze)

| Lab | Stage | The visitor does | Recorded run |
|---|---|---|---|
| 1 · Watch the loop fix a bug | Apply | Runs the agent on `adder4` with scripted model replies and real tool checks; reads the log, the table, the diff and the feedback | `runs/agent/20261020-143413-adder4-iter3` |
| 2 · A correct design that was rejected three times | Analyze | Decides from the specification whether the design or the model's testbench is wrong | `runs/agent/20261020-143429-alu4-iter3` |
| 3 · Find a real bug in a waveform and fix it | Analyze | Reads the hidden test's mismatches, draws the waveform, adds `signed` on two lines, re-tests | `runs/bench/heldout-seeds1-5/runs/alu8/default/seed4` (the fix: `runs/manual/20261020-141335-alu8-edit`) |
| 4 · Does revising help? | Analyze | Reads the five benchmark charts for 100 held-out and 100 development runs | `runs/bench/heldout-seeds1-5`, `dev-seeds1-5` |

If a recorded run is missing (for example in a container started without the repository's `runs/` folder),
the lab says so and the rest still works.

### Level 3 · Advanced (Evaluate, Create)

- **A. A design and a testbench of your own.** Any of the ten circuits; start from the module header or from one
  of the circuit's prepared designs (known-correct and deliberately faulty). **Check & test** runs compile, your
  testbench, synthesis and the hidden test, saves the result as a run, and says which of the four cases it is:
  for example "wrong design, accepted (missed bug)" when your testbench passes a design the hidden test fails.
- **B. A prompt strategy of your own.** The strategy editor; the saved strategy appears in Level 2's strategy list.
- **C. Compare two runs.** A table of both runs, statements about each, statements about the difference, a chart
  of every attempt's hidden-test score coloured by its case, the diff of the two final designs, five questions,
  and a download of the comparison with the answers.

## What was checked, and what still has to be

Checked on a Windows machine without the EDA tools and without Gradio (2026-11-16):

- The pure-Python tests pass (`pytest -m "not integration"`), including the new `tests/test_learn.py`,
  `tests/test_compare.py`, `tests/test_devview.py`, `tests/test_duplicate_revision.py` and the additions to
  `tests/test_dashboard.py`. The only failures there are three existing tests in `tests/test_eda.py` that need
  Linux process groups.
- The Plotly figures were built with the pinned Plotly version.
- The page was built and its callbacks fired against a stand-in for Gradio that checks component and event
  names, and the tool-dependent tests were run with the three tool calls replaced by a stand-in.

Still to do on the Linux or Docker setup, before recording:

1. `docker compose up -d --build`, then `docker compose exec app pytest -m "not ollama"` and
   `docker compose exec app vlsi-agent check-fixtures`. This is the first run of the page under real Gradio and
   of the new tool-dependent tests (the testbench skeleton has never been compiled by Icarus Verilog).
2. Click through every tab once: each lesson's explorer, the quiz, the four labs, Level 3 sections A to C, the
   Developer view's three sections. Check the page at 125% zoom, in light and dark mode.
3. Pilot with 3 to 5 students (the mid-project plan): for each participant record whether they can say which
   tests give feedback and which give the score (G1), connect a waveform mismatch to an RTL line and state the
   expected signed result (G2), produce an edited run whose score changes while the original stays (G3); and
   read the times in the Developer view's "Where the time went" (G4).

## Not done in this round (from the mid-project plan)

| Item | State |
|---|---|
| Stop on a duplicate revision | Done as an opt-in setting, `[agent] stop_on_duplicate` (see the README). Not benchmarked. |
| Keep the last compilable design | Not done. It changes which design a run hands over, so `bench.delivered_after` and the benchmark tables would have to follow the same rule. |
| Clock/reset/sampling harness | Partly: Level 3's "testbench skeleton" generates the declarations, the clock and a check task with the right sampling for any circuit. It is offered to people, not yet to the model as a prompt strategy. |
| FIFO circuit, fresh seeds, second model, retrieval | Not done: they need the tools or the GPU to verify. |
