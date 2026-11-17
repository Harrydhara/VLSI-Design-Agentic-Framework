import dataclasses
from pathlib import Path

import pytest

from vlsi_agent.compare import (REASONING_PROMPTS, VERDICT_TEXT, attempt_verdict, comparison_markdown, differences,
                                evaluation_report, final_design, observations, run_facts, verdict_figure)
from vlsi_agent.runview import AttemptView, RunView


def attempt(number, dev_passed, outcome, passed=None, total=None, design=None):
    """One attempt as the results view reads it; outcome None means the reply had no Verilog."""
    reference = None if outcome is None else {"outcome": outcome, "passed": passed, "total": total}
    return AttemptView(number=number, folder=Path(f"attempt_{number}"),
                       design=None if outcome is None else (design or f"module m{number};\nendmodule\n"),
                       testbench=None, reply="", feedback="" if dev_passed else "- failed",
                       checks={"code_found": outcome is not None, "cells": 10 + number}, dev_passed=dev_passed,
                       reference=reference, reference_log="")


def run(attempts, tokens_each=100, circuit="alu4", origin=None, prompts="/somewhere/prompts/default"):
    final = next((a for a in reversed(attempts) if a.reference), None)
    history = {
        "circuit": circuit, "split": "dev", "status": "attempts_exhausted", "duration_s": 2.5,
        "settings": {"model": "fake", "max_attempts": 3, "prompts": prompts, "workflow": "single"},
        "tokens": {"total": tokens_each * len(attempts)},
        "attempts": [{"number": a.number, "prompt_tokens": tokens_each // 2, "output_tokens": tokens_each // 2}
                     for a in attempts],
        "final_attempt": final.number if final else None,
        "reference": None if final is None else {**final.reference, "detail": "checks"},
    }
    return RunView(Path("run"), history, attempts, origin)


FALSE_ALARMS = run([attempt(n, False, "pass", 2048, 2048) for n in (1, 2, 3)])       # like the recorded alu4 run
FIXED = run([attempt(1, False, "fail", 256, 512), attempt(2, True, "pass", 512, 512)], circuit="adder4")
BROKEN = run([attempt(1, False, "pass", 8, 8), attempt(2, False, "fail", 3, 8)])
MISSED = run([attempt(1, True, "fail", 3, 8)])
NO_DESIGN = run([attempt(1, False, None)])
BY_HAND = run([attempt(1, False, "pass", 8, 8)], tokens_each=0, origin={"own_design": True, "circuit": "alu4"})


def test_each_attempt_is_one_of_four_cases():
    assert [attempt_verdict(attempt(1, own, outcome, 1, 1)) for own, outcome in
            ((True, "pass"), (False, "pass"), (True, "fail"), (False, "compile_error"))] == [
        "correct_accepted", "correct_rejected", "wrong_accepted", "wrong_rejected"]
    assert attempt_verdict(attempt(1, False, None)) == "unscored"
    assert set(VERDICT_TEXT) == {"correct_accepted", "correct_rejected", "wrong_accepted", "wrong_rejected", "unscored"}


def test_a_run_that_kept_revising_a_correct_design():
    facts = run_facts(FALSE_ALARMS)
    assert facts["effect"] == "kept" and facts["final_outcome"] == "pass" and facts["final_score"] == "2048/2048"
    assert facts["verdicts"] == ["correct_rejected"] * 3 and facts["source"] == "strategy `default`"
    assert (facts["first_correct_attempt"], facts["attempts_after_correct"], facts["tokens_after_correct"]) == (1, 2, 200)
    assert facts["cells"] == 13  # of the final attempt
    text = "\n".join(observations(facts))
    assert "**passes** the hidden test: PASS (2048/2048 checks)" in text
    assert "rejected a correct design 3 times" in text
    assert "Attempt 1 was already correct; 2 further attempt(s) (200 of 300 tokens)" in text


def test_revisions_that_fixed_or_broke_a_design():
    fixed, broken = run_facts(FIXED), run_facts(BROKEN)
    assert fixed["effect"] == "fixed" and "Revising helped" in "\n".join(observations(fixed))
    assert fixed["attempts_after_correct"] == 0
    assert broken["effect"] == "broken" and broken["final_outcome"] == "fail"
    text = "\n".join(observations(broken))
    assert "Revising hurt" in text and "**does not pass**" in text and "rejected a correct design once" in text


def test_a_testbench_that_missed_a_bug_and_runs_without_a_design():
    missed = run_facts(MISSED)
    assert missed["effect"] == "single" and missed["verdicts"] == ["wrong_accepted"]
    assert "accepted a wrong design once" in "\n".join(observations(missed))
    nothing = run_facts(NO_DESIGN)
    assert nothing["effect"] == "no_design" and nothing["final_outcome"] is None and nothing["cells"] is None
    assert observations(nothing) == ["No reply contained a Verilog module, so there is no design to score."]
    by_hand = run_facts(BY_HAND)
    assert by_hand["source"] == "your own design" and "No model was called" in "\n".join(observations(by_hand))
    assert run_facts(run([attempt(1, False, "pass", 1, 1)], origin={"edited_from": "ui/x", "attempt": 1}))["source"] == "a manual edit"


def test_earlier_attempts_that_were_not_scored():
    first = dataclasses.replace(attempt(1, False, "pass", 8, 8), reference=None)  # the run scored only its final design
    facts = run_facts(run([first, attempt(2, False, "pass", 8, 8)]))
    assert facts["verdicts"] == ["unscored", "correct_rejected"] and facts["effect"] == "unknown"
    assert "cannot show whether revising helped" in "\n".join(observations(facts))


def test_comparison_of_two_runs():
    text = comparison_markdown(BROKEN, FALSE_ALARMS)
    assert "| | Run A | Run B |" in text and "| Hidden test, final design | **FAIL** 3/8 | **PASS** 2048/2048 |" in text
    assert "#### What run A shows" in text and "#### What run B shows" in text and "#### B compared with A" in text
    assert "Run B's final design passes the hidden test and run A's does not." in text
    assert "One run of each is an example, not a result." in text
    assert "similar number of tokens" not in text  # 300 against 200 tokens: 1.5 times

    other_circuit = "\n".join(differences(FIXED, FALSE_ALARMS))
    assert "different circuits" in other_circuit and "cannot rank them" in other_circuit
    assert "Neither final design passes" in "\n".join(differences(BROKEN, MISSED))
    same = run([attempt(1, True, "pass", 8, 8, design="module m;  endmodule")])
    again = run([attempt(1, True, "pass", 8, 8, design="module m;\nendmodule\n")])
    assert final_design(same) == "module m;  endmodule" and final_design(NO_DESIGN) is None
    assert "the same code" in "\n".join(differences(same, again))
    assert "similar number of tokens" in "\n".join(differences(same, again))


def test_evaluation_report_holds_the_comparison_and_the_answers():
    text = evaluation_report(FIXED, FALSE_ALARMS, "ui/a", "ui/b", ["I changed the prompt.", "  "])
    assert text.startswith("# Evaluation of two runs\n\n- Run A: `ui/a`\n- Run B: `ui/b`")
    assert "| | Run A | Run B |" in text and "## My reasoning" in text
    assert all(f"**{prompt}**" in text for prompt in REASONING_PROMPTS)
    assert "I changed the prompt." in text and text.count("(not answered)") == len(REASONING_PROMPTS) - 1


def test_verdict_figure_has_one_bar_per_attempt():
    pytest.importorskip("plotly")
    fig = verdict_figure([("A", BROKEN), ("B", FALSE_ALARMS)])
    assert sum(len(trace.x) for trace in fig.data) == 5
    assert {trace.name for trace in fig.data} == {VERDICT_TEXT["correct_rejected"], VERDICT_TEXT["wrong_rejected"]}
    assert list(fig.layout.xaxis.categoryarray) == ["A · attempt 1", "A · attempt 2", "B · attempt 1",
                                                    "B · attempt 2", "B · attempt 3"]
    assert verdict_figure([("A", NO_DESIGN)]).data[0].name == VERDICT_TEXT["unscored"]
