"""The learning path: what the dashboard teaches, in three levels that follow Bloom's taxonomy.

    Level 1, Beginner      Remember and Understand   lessons, small explorers, a quiz
    Level 2, Intermediate  Apply and Analyze         guided labs on the preconfigured tool
    Level 3, Advanced      Evaluate and Create       your own design, testbench or strategy

Everything here is plain Python: the lesson texts, the explorers (they compute their
answers, nothing is pre-drawn), the quiz and lab questions with their grading, and the
description of each lab. The dashboard only lays it out. Only the one figure needs Plotly
(the optional ui extra), and it is drawn by waveform.py like every other waveform.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Sequence

from vlsi_agent.waveform import Signal, waveform_figure

BLOOM_URL = "https://tips.uark.edu/using-blooms-taxonomy/"


# --------------------------------------------------------------------------- levels


@dataclass(frozen=True)
class Level:
    key: str  # the tab's id in the dashboard
    name: str
    bloom: str
    you_will: str
    needs: str


LEVELS = (
    Level("level1", "Level 1 · Beginner", "Remember & Understand",
          "Learn the words (Verilog, testbench, simulation, synthesis, agent loop), try four small explorers, "
          "and take a short quiz.",
          "Nothing but a browser. No model, no tools."),
    Level("level2", "Level 2 · Intermediate", "Apply & Analyze",
          "Work through four guided labs on the preconfigured tool: run the agent, read its checks, find a bug "
          "in a waveform, fix it, and read the benchmark charts.",
          "Recorded runs open without a model. New runs need the tools in the container; the scripted demo "
          "needs no GPU."),
    Level("level3", "Level 3 · Advanced", "Evaluate & Create",
          "Write your own design, testbench or prompt strategy, then let the tool compare it with a baseline "
          "and write down what the evidence supports.",
          "The tools in the container. Your own prompt strategy also needs the model (a GPU)."),
)


def levels_markdown() -> str:
    rows = ["| Level | Bloom's stages | What you do | What it needs |", "|---|---|---|---|"]
    rows += [f"| **{level.name}** | {level.bloom} | {level.you_will} | {level.needs} |" for level in LEVELS]
    return "\n".join(rows)


def badge(level: Level) -> str:
    """The line at the top of a level's tab."""
    return (f'<div class="level-badge"><span class="level-name">{level.name}</span>'
            f'<span class="level-bloom">Bloom\'s taxonomy: {level.bloom}</span></div>')


START_HERE = f"""
## What this site is about

Every digital chip starts as text. Engineers describe the circuit in a **hardware description language**
(here: Verilog), simulate that description to check that it behaves correctly, and then let a synthesis tool
turn it into logic gates. This field is called **VLSI design** (very-large-scale integration).

Large language models can now write Verilog. The open question, and the subject of this site, is:

> **Does a language model write better Verilog when it can see what the compiler, the simulator and the
> synthesis tool say about its code, and revise?**

The site lets you watch that loop, inspect every step of it, and test the answer yourself.

## Why it matters

- **Hardware bugs are expensive.** Software can be patched after release; a chip that has been manufactured
  cannot. Industry surveys regularly report that checking a design (verification) takes about half of a chip
  project's engineering effort or more.
- **Code that compiles is not code that is correct.** A Verilog file can compile, simulate and synthesize
  without a single warning and still describe the wrong circuit. Telling these apart is the core skill this
  site trains.
- **A model can be wrong about its own work.** In this project the model also writes the test for its design.
  In our 200 benchmark runs, that test rejected 163 of the 305 attempts whose design was in fact correct.
  A tool that only says "the tests pass" is not enough; you need to know who wrote the tests.

## Who benefits

| You are | What you get |
|---|---|
| A student in a digital design course | Practice in reading simulation failures and deciding whether the design or the test is wrong |
| An instructor | Ready-made, repeatable examples of real bugs (carry, signed comparison, timing) with waveforms |
| A researcher on AI for hardware | A measured comparison of one-shot and iterative generation, with every run inspectable |
| An engineer evaluating AI coding tools | A concrete picture of what tool feedback can and cannot fix |

## What you should know before you start

- **Binary numbers**: that 4 bits hold the values 0 to 15. Lesson 2 covers negative numbers.
- **Basic logic**: AND, OR, NOT, and the idea of a clock that makes a circuit move one step at a time.
- **No Verilog is needed for Level 1.** Level 2 asks you to read short Verilog; Level 3 asks you to write a
  few lines.
- **No GPU is needed to learn.** All of Level 1 and every recorded run in Level 2 work without a model.

## How the site is organised

The three levels follow [Bloom's taxonomy]({BLOOM_URL}): first remember and understand the ideas, then
apply and analyze them with a prepared tool, then evaluate and create with your own variations. Go through
the tabs from left to right. The **Developer view** tab shows the code and the data behind everything you see.

{levels_markdown()}
"""


# --------------------------------------------------------------------------- lessons

GLOSSARY = """
| Word | Meaning |
|---|---|
| **Verilog** | A language that describes digital circuits as text. |
| **RTL** | Register-transfer level: Verilog written so that a tool can turn it into gates. |
| **Module** | One circuit block with named inputs and outputs (its *ports*). |
| **Testbench** | Verilog that is not a circuit: it feeds inputs to a design in simulation and checks the outputs. |
| **Simulation** | Running the Verilog in software to see what the circuit would do (here: Icarus Verilog). |
| **Synthesis** | Translating RTL into logic gates and flip-flops (here: Yosys). |
| **Latch** | A memory element that synthesis creates by accident when combinational code forgets a case. |
| **Waveform** | A plot of signal values over time, recorded during simulation. |
| **Agent loop** | Generate code, check it with tools, send the results back to the model, revise. |
| **One-shot** | The model gets one attempt and no feedback. The baseline. |
| **Development checks** | The checks whose results the model sees: compile, its own testbench, synthesis. |
| **Hidden reference test** | A test written by people, never shown to the model, used only to score the result. |
"""

LESSON_VERILOG = """
A Verilog **module** is a box with ports. Inside, you say how the outputs follow from the inputs.
This is the complete, correct 4-bit adder used all over this site:

```verilog
module adder4(
    input  [3:0] a,      // 4-bit input: wires a[3] ... a[0]
    input  [3:0] b,
    input        cin,    // carry-in, 1 bit
    output [3:0] sum,
    output       cout    // carry-out, 1 bit
);
  assign {cout, sum} = a + b + cin;   // the 5-bit result, split into cout and sum
endmodule
```

Three things to remember:

1. **`assign` describes wiring, not steps.** The line above is always true, like a formula in a spreadsheet.
   Logic that depends only on the current inputs is called *combinational*.
2. **`always @(posedge clk)` describes memory.** Its outputs change only when the clock rises. A counter is
   written this way. Such logic is called *sequential*.
3. **The module header is a contract.** Another module connects to these exact names and widths. A design
   with a port called `carry_out` instead of `cout` does not even compile against its test.
"""

LESSON_SIGNED = """
A wire carries bits. Whether `1000 0000` means 128 or -128 is not stored anywhere: it is decided by the
code that *reads* the bits. Read as an **unsigned** number it is 128. Read as a **signed** number
(two's complement, where the top bit counts as -128) it is -128.

In Verilog a plain `wire [7:0]` is unsigned, so `a < b` compares unsigned values. To compare as signed
numbers, the operands must be declared `signed`. Copying the sign bit into a wider wire (*sign extension*)
does **not** make the comparison signed.

Try it. The starting values are the first inputs on which a model-written 8-bit ALU fails in Level 2.
"""

LESSON_TESTBENCH = """
A **testbench** is a Verilog module with no ports. It creates the design, drives its inputs, waits, and
compares each output with the value it expects. In this project every testbench ends by printing one line:

```verilog
$display("RESULT: %0d/%0d passed", passed, total);
$finish;
```

The run counts as a pass only if that line appears with `passed == total` and `total > 0`. The simulator's
exit code is not enough: it is 0 even for a testbench that checks nothing.

**A test only finds a bug if its inputs reach the bug.** Below, two faulty adders are compared with the
correct one on the inputs you choose. Find inputs on which a faulty adder gives the right answer anyway.
"""

LESSON_TIMING = """
In a clocked circuit the outputs change just *after* the rising clock edge. A testbench has to look at the
right moment. If it looks at the edge itself or before it, it reads the previous value, reports a failure,
and blames a design that is correct.

Language models make this mistake often in the testbenches they write. The example below is a correct
4-bit counter. Move the slider to choose when the testbench looks.
"""

LESSON_SYNTHESIS = """
**Synthesis** turns RTL into logic cells. This project uses Yosys and reports two things:

- **Cell count**: how many generic logic cells the design needs. It is a rough size, not a chip area.
- **Latches**: if combinational code does not assign an output in every case, the output has to *remember*
  its old value, and synthesis adds a latch. That is almost always a mistake, so the checks reject it.

```verilog
always @(*) begin
    if (sel) y = a;     // no else: when sel is 0, y keeps its old value -> a latch
end
```

Remember what each tool can and cannot tell you:

| Check | Tool | It proves | It does not prove |
|---|---|---|---|
| Compile | Icarus Verilog | The code is legal Verilog with the right ports | That it does the right thing |
| Simulate | Icarus Verilog + a testbench | The design gave the expected outputs **for the inputs tried** | Anything about untried inputs, or that the expectations are right |
| Synthesize | Yosys | The code can become gates, with no accidental latches | That those gates compute the right function |
"""

LESSON_AGENT = """
The **agent loop** connects a language model to those tools:

1. The model gets the circuit's description and its exact module header.
2. It writes a design **and its own testbench**.
3. The tools compile, simulate and synthesize. These are the **development checks**.
4. If a check fails, the tool output goes back to the model, and it revises (up to a limit).
5. Only after the loop has ended, a **hidden reference test** scores each design. The model never sees this
   test or its result.

Because the model wrote the test it is judged by during the loop, its own checks and the hidden test can
disagree. Choose a combination below to see what each one means and how often it happened in our benchmark.
"""


# --------------------------------------------------------------------------- explorers


def bits(value: int, width: int) -> str:
    return format(int(value) % (1 << width), f"0{width}b")


def as_signed(value: int, width: int) -> int:
    """The value of a width-bit pattern read as a two's complement number."""
    value = int(value) % (1 << width)
    return value - (1 << width) if value >> (width - 1) else value


def _grouped(pattern: str) -> str:
    """'10000000' as '1000 0000': groups of four, counted from the right."""
    groups = [pattern[max(0, i - 4):i] for i in range(len(pattern), 0, -4)]
    return " ".join(reversed(groups))


def signed_explorer(a: int, b: int, width: int = 8) -> str:
    """Two bit patterns read as unsigned and as signed numbers, and `a < b` both ways."""
    a, b = int(a) % (1 << width), int(b) % (1 << width)
    sa, sb = as_signed(a, width), as_signed(b, width)
    unsigned_less, signed_less = a < b, sa < sb
    # What the faulty ALU did: sign-extend by one bit, then compare the wider wires (still unsigned).
    ea, eb = sa % (1 << (width + 1)), sb % (1 << (width + 1))
    rows = ["| | Bits | Read as unsigned | Read as signed |", "|---|---|---|---|",
            f"| `a` | `{_grouped(bits(a, width))}` | {a} | {sa} |",
            f"| `b` | `{_grouped(bits(b, width))}` | {b} | {sb} |"]
    text = "\n".join(rows)
    text += (f"\n\n- Unsigned: `a < b` is **{str(unsigned_less).lower()}** ({a} < {b}).\n"
             f"- Signed: `a < b` is **{str(signed_less).lower()}** ({sa} < {sb}).\n"
             f"- Sign-extended to {width + 1} bits but still unsigned: {ea} < {eb} is "
             f"**{str(ea < eb).lower()}**.")
    if unsigned_less != signed_less:
        text += ("\n\n**The two readings disagree.** They always do when exactly one of the two numbers is "
                 "negative. A design that needs the signed answer but compares unsigned wires is wrong on "
                 "these inputs, and sign extension alone does not help: the last line gives the unsigned answer.")
    else:
        text += ("\n\nThe two readings agree here, because both numbers have the same sign bit. A test that only "
                 "uses inputs like these cannot tell a signed comparison from an unsigned one.")
    return text


ADDER_BUGS = (
    ("Bug A: carry-out tied to 0", "assign sum = a + b + cin;  assign cout = 1'b0;"),
    ("Bug B: carry-in ignored", "assign {cout, sum} = a + b;"),
)


def adder_outputs(a: int, b: int, cin: int) -> tuple[int, int, int]:
    """The 5-bit result {cout, sum} of the correct adder, of bug A and of bug B."""
    a, b, cin = int(a) & 15, int(b) & 15, 1 if int(cin) else 0
    correct = a + b + cin
    return correct, correct & 15, a + b


def adder_bug_exposure() -> tuple[int, int]:
    """Of the 512 input combinations, how many give a wrong result for bug A and for bug B."""
    results = [adder_outputs(a, b, cin) for a in range(16) for b in range(16) for cin in (0, 1)]
    return sum(r[1] != r[0] for r in results), sum(r[2] != r[0] for r in results)


def adder_explorer(a: int, b: int, cin: int) -> str:
    a, b, cin = int(a) & 15, int(b) & 15, 1 if int(cin) else 0
    correct, bug_a, bug_b = adder_outputs(a, b, cin)

    def row(name: str, value: int) -> str:
        verdict = "reference" if name == "Correct" else ("**yes, the test would fail it**" if value != correct
                                                         else "no, it looks correct here")
        return f"| {name} | {value >> 4} | `{bits(value, 4)}` ({value & 15}) | {value} | {verdict} |"

    exposed_a, exposed_b = adder_bug_exposure()
    table = "\n".join(["| Design | cout | sum | {cout, sum} | Do these inputs expose the bug? |", "|---|---|---|---|---|",
                       row("Correct", correct), row(ADDER_BUGS[0][0], bug_a), row(ADDER_BUGS[1][0], bug_b)])
    return (f"`a = {a}`, `b = {b}`, `cin = {cin}`: the correct result is {a} + {b} + {cin} = **{correct}**.\n\n"
            f"{table}\n\n"
            f"Of all 512 input combinations, {exposed_a} expose bug A (those whose sum is 16 or more) and "
            f"{exposed_b} expose bug B (those with `cin = 1`). A testbench that only tries small numbers with "
            "`cin = 0` passes both faulty adders. That is why the hidden test for this adder tries all 512.")


CLOCK_PERIOD_NS = 10
FIRST_EDGE_NS = 5
SAMPLED_EDGES = 5
SAMPLING_END_NS = 60
SAMPLING_OFFSETS = (-4, 8)  # the slider's range, in ns relative to the rising edge


def sampling_checks(offset_ns: int) -> list[tuple[int, int, int]]:
    """(time the testbench looks, count it reads, count it expects) for each rising clock edge.
    The counter is correct: after rising edge k it holds k. Looking at the edge or before it
    reads the value from before the edge."""
    offset_ns = int(offset_ns)
    checks = []
    for k in range(1, SAMPLED_EDGES + 1):
        edge = FIRST_EDGE_NS + CLOCK_PERIOD_NS * (k - 1)
        checks.append((edge + offset_ns, k if offset_ns > 0 else k - 1, k))
    return checks


def sampling_rows(offset_ns: int) -> list[tuple[str, Signal]]:
    """The explorer's waveform rows: clock, the counter, what the testbench read and what it expected."""
    clk = Signal("clk", 1, [(0.0, "0")])
    count = Signal("count", 4, [(0.0, bits(0, 4))])
    for k in range(1, SAMPLED_EDGES + 1):
        edge = float(FIRST_EDGE_NS + CLOCK_PERIOD_NS * (k - 1))
        clk.changes += [(edge, "1"), (edge + CLOCK_PERIOD_NS / 2, "0")]
        count.changes.append((edge, bits(k, 4)))
    reads = Signal("reads", 4, [(0.0, "x")])
    expects = Signal("expects", 4, [(0.0, "x")])
    for when, read, expected in sampling_checks(offset_ns):
        reads.changes.append((float(when), bits(read, 4)))
        expects.changes.append((float(when), bits(expected, 4)))
    return [("clk", clk), ("count (design)", count), ("testbench reads", reads), ("testbench expects", expects)]


def sampling_explorer(offset_ns: int) -> str:
    offset_ns = int(offset_ns)
    checks = sampling_checks(offset_ns)
    passed = sum(read == expected for _, read, expected in checks)
    where = (f"{offset_ns} ns after" if offset_ns > 0 else "exactly at" if offset_ns == 0
             else f"{-offset_ns} ns before")
    lines = [f"The clock rises at {', '.join(str(FIRST_EDGE_NS + CLOCK_PERIOD_NS * k) for k in range(SAMPLED_EDGES))} "
             f"ns. The testbench looks **{where}** each rising edge and expects the new count.", ""]
    lines += [f"- at {when} ns it reads {read}, expects {expected}: {'ok' if read == expected else '**FAIL**'}"
              for when, read, expected in checks]
    lines += ["", f"`RESULT: {passed}/{len(checks)} passed`", ""]
    if passed == len(checks):
        lines.append("The testbench looks after the counter has changed, so it agrees with the design.")
    elif offset_ns == 0:
        lines.append("**A false alarm.** At the edge itself the counter has not been updated yet, so the "
                     "testbench reads the old value. The design is correct; the testbench looks too early. "
                     "In the agent loop this failure would be sent to the model as if the design were wrong.")
    else:
        lines.append("**A false alarm.** The testbench reads the value from before the edge. The design is "
                     "correct; the testbench looks too early.")
    lines.append("In the plot, dashed lines mark the failed checks and red means the testbench has not looked yet.")
    return "\n".join(lines)


def sampling_figure(offset_ns: int):
    """The explorer's waveform (Plotly), drawn like the hidden-test waveforms in Level 2."""
    failed = [when for when, read, expected in sampling_checks(offset_ns) if read != expected]
    return waveform_figure(sampling_rows(offset_ns), 0, SAMPLING_END_NS, failed)


# Measured over the 200 benchmark runs in runs/bench/dev-seeds1-5 and heldout-seeds1-5 (gemma4:26b, four
# strategies): every scored attempt, grouped by the hidden test's verdict and the agent's own checks.
BENCH_CORRECT_ATTEMPTS, BENCH_CORRECT_REJECTED = 305, 163
BENCH_WRONG_ATTEMPTS, BENCH_WRONG_ACCEPTED = 40, 7

VERDICTS = {
    ("PASS", "PASS"): (
        "Correct design, accepted",
        "Both agree. The loop stops, and it was right to stop.",
        f"{BENCH_CORRECT_ATTEMPTS - BENCH_CORRECT_REJECTED} of the {BENCH_CORRECT_ATTEMPTS} correct attempts."),
    ("FAIL", "PASS"): (
        "Correct design, rejected: a false alarm",
        "The design is right and the model's own testbench is wrong (a wrong expected value, or it looks at "
        "the wrong time). The loop keeps revising a design that needed no change, which costs time and tokens "
        "and can even break the design.",
        f"{BENCH_CORRECT_REJECTED} of the {BENCH_CORRECT_ATTEMPTS} correct attempts. This was the most common "
        "disagreement by far."),
    ("PASS", "FAIL"): (
        "Wrong design, accepted: a missed bug",
        "The model's testbench did not try the inputs that expose the bug, or it expects the same wrong "
        "answer the design gives. The loop stops early and hands over a faulty design.",
        f"{BENCH_WRONG_ACCEPTED} of the {BENCH_WRONG_ATTEMPTS} wrong attempts."),
    ("FAIL", "FAIL"): (
        "Wrong design, rejected",
        "Both agree that something is wrong. Whether the next attempt fixes it depends on how useful the "
        "feedback is: a compile error with a line number helps; a testbench that fails for another reason "
        "does not.",
        f"{BENCH_WRONG_ATTEMPTS - BENCH_WRONG_ACCEPTED} of the {BENCH_WRONG_ATTEMPTS} wrong attempts."),
}


def verdict_explorer(own: str, hidden: str) -> str:
    title, meaning, measured = VERDICTS[(own, hidden)]
    return (f"### {title}\n\nOwn checks **{own}**, hidden test **{hidden}**.\n\n{meaning}\n\n"
            f"**In our benchmark:** {measured}")


PIPELINE_HTML = """
<div class="pipe">
  <div class="pipe-box"><b>Specification</b><span>description and exact module header</span></div>
  <div class="pipe-arrow">&darr;</div>
  <div class="pipe-box pipe-model"><b>Language model</b><span>writes the design and its own testbench</span></div>
  <div class="pipe-arrow">&darr;</div>
  <div class="pipe-box"><b>Development checks</b><span>compile &middot; run the testbench &middot; synthesize</span></div>
  <div class="pipe-arrow">&darr; <i>a check failed: the tool output goes back to the model (up to the attempt limit)</i> &uarr;</div>
  <div class="pipe-box pipe-hidden"><b>Hidden reference test</b><span>runs only after the loop has ended; the model never sees it</span></div>
  <div class="pipe-arrow">&darr;</div>
  <div class="pipe-box"><b>Score</b><span>one-shot (attempt 1) and iterative (final attempt), from the same run</span></div>
</div>
"""


# --------------------------------------------------------------------------- questions


@dataclass(frozen=True)
class Question:
    prompt: str
    choices: tuple[str, ...]
    answer: int  # index into choices
    explain: str
    bloom: str = "Understand"

    @property
    def correct(self) -> str:
        return self.choices[self.answer]


def grade(questions: Sequence[Question], answers: Sequence[str | None]) -> tuple[int, str]:
    """(number correct, one feedback line per question) for the chosen answers."""
    score, lines = 0, []
    for number, question in enumerate(questions, start=1):
        given = answers[number - 1] if number - 1 < len(answers) else None
        if not given:
            lines.append(f"{number}. ⬜ Not answered yet.")
        elif given == question.correct:
            score += 1
            lines.append(f"{number}. ✅ Correct. {question.explain}")
        else:
            lines.append(f"{number}. ❌ Not this one. {question.explain}")
    return score, "\n".join(lines)


QUIZ = (
    Question("What is a testbench?",
             ("A faster version of the design", "Code that drives a design's inputs in simulation and checks its outputs",
              "The tool that turns Verilog into gates", "The list of a module's ports"), 1,
             "A testbench is not a circuit: it applies inputs to the design and compares the outputs with expected "
             "values.", "Remember"),
    Question("Which tool turns Verilog into logic cells in this project?",
             ("Icarus Verilog", "Yosys", "Ollama", "Gradio"), 1,
             "Yosys synthesizes. Icarus Verilog compiles and simulates, Ollama runs the model, Gradio draws the page.",
             "Remember"),
    Question("Which line must a testbench print for its run to count?",
             ("PASS", "$finish", "RESULT: <passed>/<total> passed", "Nothing: exit code 0 is enough"), 2,
             "Only the RESULT line counts, and only with passed equal to total and total above 0. The simulator "
             "exits with code 0 even when a testbench checks nothing.", "Remember"),
    Question("When does the hidden reference test run?",
             ("Before the model writes anything", "After every attempt, and its result is sent to the model",
              "Only after the loop has ended; the model never sees it", "Only when the development checks fail"), 2,
             "Scoring starts once the loop is over, so it cannot influence the model.", "Remember"),
    Question("A design compiles and synthesizes with no warnings. What do you know?",
             ("It is correct", "It is legal Verilog that can become gates; it may still be the wrong circuit",
              "It will pass its testbench", "It has no timing problems on a real chip"), 1,
             "Compiling and synthesizing prove the form, not the function.", "Understand"),
    Question("Why can the comparison a < b give different answers for the same two 8-bit wires?",
             ("Simulators are not deterministic", "It depends on whether the bits are read as unsigned or signed numbers",
              "Because of the clock", "Because synthesis reorders the bits"), 1,
             "`1000 0000` is 128 unsigned and -128 signed. Verilog compares unsigned unless the operands are "
             "declared signed.", "Understand"),
    Question("The agent's own checks FAIL, but the hidden test PASSES the same design. What is the most likely cause?",
             ("The hidden test is too easy", "The model's own testbench is wrong",
              "The design has a latch", "The simulator timed out"), 1,
             "The design is correct, so the failure came from the testbench: a wrong expected value or a check at "
             "the wrong time.", "Understand"),
    Question("Why is the final score taken from a hidden test and not from the model's own testbench?",
             ("The hidden test runs faster", "A model-written testbench can be wrong in either direction, so it "
              "cannot be the judge of its own design", "Model-written testbenches never compile",
              "To save tokens"), 1,
             "An independent test is the only way to tell a false alarm from a real bug, and a missed bug from a "
             "correct design.", "Understand"),
)
QUIZ_PASS_MARK = 6


def quiz_markdown(answers: Sequence[str | None]) -> str:
    score, lines = grade(QUIZ, answers)
    answered = sum(1 for a in answers if a)
    head = f"### {score} of {len(QUIZ)} correct"
    if answered < len(QUIZ):
        head += f" ({len(QUIZ) - answered} not answered yet)"
    elif score >= QUIZ_PASS_MARK:
        head += ". You are ready for **Level 2 · Intermediate**."
    else:
        head += ". Reread the lessons the wrong answers point to, then try again."
    return head + "\n\n" + lines


# --------------------------------------------------------------------------- guided labs (Level 2)


@dataclass(frozen=True)
class Lab:
    key: str
    title: str
    bloom: str
    needs: str
    steps: str  # markdown
    questions: tuple[Question, ...]
    circuit: str | None = None  # put into "1. Design and run"
    demo: bool = False  # choose the scripted model there
    run: str | None = None  # a recorded run to open in "2. Results", relative to runs/
    bench: str | None = None  # a benchmark to open in "3. Benchmarks"


LABS = (
    Lab("loop", "Lab 1 · Watch the loop fix a bug", "Apply",
        "The tools in the container; no GPU (scripted model replies, real tool checks).",
        """
**Goal:** run the agent yourself and follow one failed check from the tool output to the fix.

1. Press **Set up this lab**. It selects `adder4`, the default strategy, up to 3 attempts and the scripted model.
2. In **1. Design and run**, press **Generate & test** and read the log as it appears.
3. **2. Results** opens by itself. Read the table: attempt 1 fails its own testbench with 256/512, attempt 2 passes.
4. Choose **Attempt** 2 and open the tab **Changes from the previous attempt**.
5. Choose **Attempt** 1 and open **Feedback sent to the model**: this text is everything the model was told.

If the tools are not installed on this machine, the same run was recorded: after step 1 it is already open in
**2. Results**.
""",
        (Question("What did the model learn from the feedback after attempt 1?",
                  ("The correct Verilog for the adder", "That its own testbench passed 256 of 512 checks, with examples of failing inputs",
                   "The hidden test's score", "Nothing; it just tried again"), 1,
                  "The feedback is the development-check output only. The hidden test's result never reaches the model."),
         Question("What changed in the design between attempt 1 and attempt 2?",
                  ("The module's port names", "The carry-out: cout is no longer tied to 0",
                   "The testbench now tries fewer inputs", "Nothing changed"), 1,
                  "Attempt 1 had `assign cout = 1'b0;`. Attempt 2 computes `{cout, sum} = a + b + cin`. This is bug A "
                  "from Lesson 3.")),
        circuit="adder4", demo=True, run="agent/20261020-143413-adder4-iter3"),
    Lab("false-alarm", "Lab 2 · A correct design that was rejected three times", "Analyze",
        "Nothing: a recorded run.",
        """
**Goal:** decide who is wrong, the design or the testbench, using the specification as the judge.

1. Press **Set up this lab**. It opens a recorded run of the 4-bit ALU `alu4` with the real model, and shows the
   ALU's specification in **1. Design and run**.
2. In **2. Results**, read the table. Compare the columns **Own checks** and **Hidden test** for all three attempts.
3. Open **Feedback sent to the model**. The first line is
   `FAIL: op=000 a=0101 b=0011 | Exp: ... o=0 n=0 | Got: y=1000 ... o=1 n=1`.
4. Work it out from the specification: `op=000` is ADD, and 5 + 3 = 8 = `1000`. The specification says
   `overflow = (a[3] == b[3]) && (y[3] != a[3])` and `negative = y[3]`. What should `o` and `n` be?
5. Open the **Testbench** tab and find that check. Which values did the model write as expected?
""",
        (Question("On that first FAIL line, who is wrong?",
                  ("The design: overflow should be 0", "The testbench: by the specification, overflow and negative are both 1",
                   "Both are wrong", "Neither; the simulator made an error"), 1,
                  "a[3] and b[3] are both 0 and y[3] is 1, so overflow = 1 and negative = 1. The design is right and "
                  "the testbench expected 0 for both."),
         Question("The first attempt was already correct. What did the two further attempts cost?",
                  ("Nothing", "About 15,000 of the run's 18,560 tokens and half of its 53 seconds",
                   "They made the design smaller", "They fixed the testbench"), 1,
                  "Attempt 1 used 3,535 tokens. The two revisions used the other 15,025, changed nothing in the score, "
                  "and the testbench still failed 13/15 at the end.")),
        circuit="alu4", run="agent/20261020-143429-alu4-iter3"),
    Lab("waveform", "Lab 3 · Find a real bug in a waveform and fix it", "Analyze",
        "The tools in the container for the waveform and the re-test; no GPU.",
        """
**Goal:** trace a failed hidden test back to one line of RTL, fix it, and confirm the fix.

1. Press **Set up this lab**. It opens a recorded benchmark run of the 8-bit ALU `alu8`, attempt 3.
2. Open the **Hidden test** tab. Every listed mismatch has `op=111` (SLT, signed "set if less than") and `a=0`.
3. Open the **Waveform** tab and press **Draw waveform**. The window starts just before the first mismatch.
   Compare the rows `y` and `expected y` where `b` reaches 128.
4. Open **Edit & re-test**. In `design.v (editable)` find
   `wire [8:0] sa = {a[7], a};` and `wire [8:0] sb = {b[7], b};` and write `signed` after `wire` on both lines.
5. Press **Check & test**. The result is saved as a new run; the benchmark run is not changed.

Without the tools, open the saved result instead: type `alu8-edit` into the **Run** list and pick
`manual/20261020-141335-alu8-edit`.
""",
        (Question("Which inputs expose this bug?",
                  ("All SLT inputs", "SLT inputs where exactly one of a and b is negative",
                   "Only a = 0", "Inputs where a equals b"), 1,
                  "With equal sign bits, signed and unsigned comparison agree (Lesson 2). The hidden test counts "
                  "32,768 failures: half of the 65,536 SLT inputs."),
         Question("Why did three attempts not fix it, although the model's own checks failed every time?",
                  ("The model ran out of tokens", "Its testbench failed every check for an unrelated reason, so the "
                   "feedback never pointed at SLT", "The hidden test was shown to the model too late",
                   "Synthesis failed"), 1,
                  "The testbench read `x` on every output (0/22), a testbench problem. Feedback that is wrong about "
                  "everything says nothing about the one real bug.")),
        circuit="alu8", run="bench/heldout-seeds1-5/runs/alu8/default/seed4"),
    Lab("benchmark", "Lab 4 · Does revising help? Read the benchmark", "Analyze",
        "Nothing: recorded benchmark runs.",
        """
**Goal:** move from single runs to evidence: 100 runs on circuits the prompts were never tuned on.

1. Press **Set up this lab**. It opens the benchmark `heldout-seeds1-5` in **3. Benchmarks**.
2. **Hidden-test passes if stopped after k attempts**: how much do the bars grow after the first attempt?
3. **Own checks vs the hidden test**: compare the two bar colours for each strategy.
4. **Revisions that fixed or broke a design**: revising is not free of risk.
5. **Cost: tokens per run**: hover the points to see which runs were expensive, and how they ended.
6. Then choose `dev-seeds1-5` and check whether the same pattern holds on the development circuits.
""",
        (Question("Which mistake do the model's own checks make far more often?",
                  ("Accepting wrong designs", "Rejecting correct designs", "Both equally", "Neither"), 1,
                  "On held-out circuits they rejected 54 to 81% of correct designs, depending on the strategy, and "
                  "accepted 3 of 24 wrong ones."),
         Question("Across both benchmarks, revision fixed 10 runs and broke 4. What is a fair conclusion?",
                  ("Revision always helps", "Revision never helps",
                   "Revision helped a little here (net +6 of 200), limited by the quality of the feedback",
                   "The strategies are ranked with statistical confidence"), 2,
                  "One model, small circuits and 25 runs per strategy and split support a careful statement, not a "
                  "ranking.")),
        bench="heldout-seeds1-5"),
)
LAB_QUESTION_SLOTS = max(len(lab.questions) for lab in LABS)


def lab_titles() -> list[str]:
    return [lab.title for lab in LABS]


def get_lab(title: str | None) -> Lab:
    """The lab with this title (the first lab if there is none)."""
    return next((lab for lab in LABS if lab.title == title), LABS[0])


def lab_markdown(lab: Lab) -> str:
    return f"### {lab.title}\n\n**Bloom's stage:** {lab.bloom} · **Needs:** {lab.needs}\n{lab.steps}"


def lab_feedback(lab: Lab, answers: Sequence[str | None]) -> str:
    score, lines = grade(lab.questions, answers)
    return f"**{score} of {len(lab.questions)} correct**\n\n{lines}"


# --------------------------------------------------------------------------- Level 3

ADVANCED_INTRO = """
In Level 2 every step was prepared. Here you make the choices, and the tool's job changes: it measures your
variation against a baseline and shows what the evidence supports.

| Create | Then evaluate |
|---|---|
| **A design of your own** (section A): write RTL for one of the circuits, or start from a known-faulty design and repair it | The hidden test scores it; the waveform in Level 2 shows any mismatch |
| **A testbench of your own** (section A): write the checks you think are needed | Its verdict is compared with the hidden test's: did it raise a false alarm, or miss a bug? |
| **A prompt strategy of your own** (section B): change what the model is told | Run it in Level 2 and compare it with the default strategy on the same circuit |

Section C compares any two runs side by side and asks you to reason about the difference.
"""

CSS = """
.level-badge { display: flex; gap: 12px; align-items: baseline; flex-wrap: wrap; padding: 8px 12px; border-radius: 6px;
               border: 1px solid var(--border-color-primary); background: var(--block-background-fill); }
.level-badge .level-name { font-weight: 600; }
.level-badge .level-bloom { color: var(--body-text-color-subdued); }
.pipe { display: flex; flex-direction: column; align-items: center; gap: 2px; padding: 8px 0; }
.pipe-box { width: min(520px, 100%); box-sizing: border-box; padding: 8px 12px; border-radius: 6px; text-align: center;
            border: 1px solid var(--border-color-primary); background: var(--block-background-fill); }
.pipe-box b { display: block; }
.pipe-box span { color: var(--body-text-color-subdued); font-size: 13px; }
.pipe-model { border-color: #4a90d9; }
.pipe-hidden { border-style: dashed; }
.pipe-arrow { color: var(--body-text-color-subdued); font-size: 13px; text-align: center; }
"""
