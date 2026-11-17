from pathlib import Path

from samples import ADDER, ADDER_NO_CARRY, TB, TB_FORGETS_CIN, reply
from vlsi_agent.agent import STATUSES, Attempt, same_revision
from vlsi_agent.config import load_config
from vlsi_agent.llm import Completion, extract_verilog
from vlsi_agent.progress import describe_event


def attempt(number: int, text: str | None, feedback: str = "- the testbench reported failures") -> Attempt:
    code = extract_verilog(text) if text else None
    return Attempt(number, Path(f"attempt_{number}"), Completion(text or "", "fake", 0, 0, 0.0, False), code, None,
                   feedback)


def test_a_revision_repeats_when_design_and_check_results_are_the_same():
    first = attempt(1, reply(ADDER_NO_CARRY))
    assert same_revision(first, attempt(2, reply(ADDER_NO_CARRY)), "adder4")
    respaced = reply(ADDER_NO_CARRY.replace("  assign", "\n      assign"))
    assert same_revision(first, attempt(2, respaced), "adder4")  # spacing does not count
    # Only the design counts, not the testbench next to it: a changed testbench shows up in the check results.
    assert same_revision(first, attempt(2, reply(ADDER_NO_CARRY, TB_FORGETS_CIN)), "adder4")


def test_a_revision_does_not_repeat_when_anything_that_matters_changed():
    first = attempt(1, reply(ADDER_NO_CARRY))
    assert not same_revision(first, attempt(2, reply(ADDER)), "adder4")  # another design
    assert not same_revision(first, attempt(2, reply(ADDER_NO_CARRY), feedback="- other results"), "adder4")
    assert not same_revision(first, attempt(2, None), "adder4")  # a reply without Verilog
    assert not same_revision(attempt(1, None), attempt(2, None), "adder4")
    assert TB in reply(ADDER)  # the sample replies do carry a testbench


def test_duplicate_stop_is_off_by_default_and_has_a_status_and_a_progress_line():
    assert load_config().agent.stop_on_duplicate is False  # the recorded benchmarks ran without it
    assert "duplicate_revision" in STATUSES
    line = describe_event({"t": 1.0, "event": "duplicate_revision", "attempt": 2, "same_as": 1})
    assert line == ("attempt 2: the same design and the same check results as attempt 1, "
                    "stopping instead of revising again")
