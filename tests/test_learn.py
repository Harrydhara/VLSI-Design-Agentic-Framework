import pytest

from vlsi_agent import learn
from vlsi_agent.circuits import load_circuits


def test_levels_follow_blooms_taxonomy_in_order():
    assert [level.bloom for level in learn.LEVELS] == ["Remember & Understand", "Apply & Analyze", "Evaluate & Create"]
    assert [level.key for level in learn.LEVELS] == ["level1", "level2", "level3"]
    table = learn.levels_markdown()
    assert all(level.name in table and level.bloom in table for level in learn.LEVELS)
    assert learn.LEVELS[0].name in learn.badge(learn.LEVELS[0])


def test_start_here_covers_the_field_its_importance_its_audience_and_the_prerequisites():
    for heading in ("## What this site is about", "## Why it matters", "## Who benefits",
                    "## What you should know before you start", "## How the site is organised"):
        assert heading in learn.START_HERE
    assert learn.BLOOM_URL in learn.START_HERE and learn.levels_markdown() in learn.START_HERE


def test_signed_and_unsigned_readings_of_the_same_bits():
    assert learn.bits(5, 4) == "0101" and learn.bits(-1, 4) == "1111"
    assert [learn.as_signed(v, 8) for v in (0, 127, 128, 255)] == [0, 127, -128, -1]
    text = learn.signed_explorer(0, 128)  # the first inputs on which the recorded alu8 design fails
    assert "| `b` | `1000 0000` | 128 | -128 |" in text
    assert "Unsigned: `a < b` is **true** (0 < 128)" in text
    assert "Signed: `a < b` is **false** (0 < -128)" in text
    assert "0 < 384 is **true**" in text  # sign extension alone still compares unsigned
    assert "disagree" in text
    assert "agree here" in learn.signed_explorer(3, 5) and "agree here" in learn.signed_explorer(200, 250)


def test_adder_explorer_shows_which_inputs_expose_each_bug():
    assert learn.adder_bug_exposure() == (256, 256)  # the hidden test also fails no_carry_out.v on 256 of 512
    assert learn.adder_outputs(15, 1, 0) == (16, 0, 16)
    assert learn.adder_outputs(3, 4, 1) == (8, 8, 7)
    assert learn.adder_explorer(3, 4, 0).count("no, it looks correct here") == 2
    carry = learn.adder_explorer(15, 1, 0)
    assert "| Bug A: carry-out tied to 0 | 0 | `0000` (0) | 0 | **yes, the test would fail it** |" in carry
    assert "| Bug B: carry-in ignored | 1 | `0000` (0) | 16 | no, it looks correct here |" in carry
    assert "= **16**" in carry


def test_sampling_explorer_reads_the_old_value_at_or_before_the_edge():
    assert learn.sampling_checks(3) == [(8, 1, 1), (18, 2, 2), (28, 3, 3), (38, 4, 4), (48, 5, 5)]
    assert [read for _, read, _ in learn.sampling_checks(0)] == [0, 1, 2, 3, 4]
    assert "RESULT: 5/5 passed" in learn.sampling_explorer(3)
    at_edge = learn.sampling_explorer(0)
    assert "RESULT: 0/5 passed" in at_edge and "exactly at" in at_edge and "A false alarm" in at_edge
    assert "2 ns before" in learn.sampling_explorer(-2) and "A false alarm" in learn.sampling_explorer(-2)
    low, high = learn.SAMPLING_OFFSETS
    assert all(when >= 0 for offset in range(low, high + 1) for when, _, _ in learn.sampling_checks(offset))

    rows = learn.sampling_rows(-2)
    assert [label for label, _ in rows] == ["clk", "count (design)", "testbench reads", "testbench expects"]
    signals = dict(rows)
    count, reads = signals["count (design)"], signals["testbench reads"]
    assert (count.value_at(4), count.value_at(5), count.value_at(46)) == ("0000", "0001", "0101")
    assert (reads.value_at(2), reads.value_at(3), reads.value_at(13)) == ("x", "0000", "0001")
    assert signals["clk"].value_at(7) == "1" and signals["clk"].value_at(12) == "0"


def test_sampling_figure_marks_the_failed_checks():
    pytest.importorskip("plotly")
    early, late = learn.sampling_figure(0), learn.sampling_figure(3)
    assert len(early.layout.shapes) == 5 and len(late.layout.shapes) == 0  # one dashed line per failed check
    assert list(late.layout.yaxis.ticktext) == ["clk", "count (design)", "testbench reads", "testbench expects"]


def test_verdict_explorer_covers_the_four_cases():
    for own in ("PASS", "FAIL"):
        for hidden in ("PASS", "FAIL"):
            assert f"Own checks **{own}**, hidden test **{hidden}**" in learn.verdict_explorer(own, hidden)
    assert "false alarm" in learn.verdict_explorer("FAIL", "PASS")
    assert "missed bug" in learn.verdict_explorer("PASS", "FAIL")
    assert f"{learn.BENCH_CORRECT_REJECTED} of the {learn.BENCH_CORRECT_ATTEMPTS}" in learn.verdict_explorer("FAIL", "PASS")
    assert 0 < learn.BENCH_CORRECT_REJECTED < learn.BENCH_CORRECT_ATTEMPTS
    assert 0 < learn.BENCH_WRONG_ACCEPTED < learn.BENCH_WRONG_ATTEMPTS


def test_every_question_has_one_right_answer_and_plain_text_choices():
    questions = list(learn.QUIZ) + [q for lab in learn.LABS for q in lab.questions]
    for q in questions:
        assert 0 <= q.answer < len(q.choices) and q.correct == q.choices[q.answer], q.prompt
        assert len(set(q.choices)) == len(q.choices) >= 2, q.prompt
        assert q.explain and "`" not in q.prompt and not any("`" in c for c in q.choices), q.prompt  # labels are plain text
    assert [q.bloom for q in learn.QUIZ].count("Remember") == [q.bloom for q in learn.QUIZ].count("Understand") == 4


def test_quiz_grading():
    right = [q.correct for q in learn.QUIZ]
    wrong = [q.choices[(q.answer + 1) % len(q.choices)] for q in learn.QUIZ]
    assert learn.grade(learn.QUIZ, right)[0] == len(learn.QUIZ)
    score, lines = learn.grade(learn.QUIZ, wrong)
    assert score == 0 and lines.count("❌") == len(learn.QUIZ) and learn.QUIZ[0].explain in lines
    assert "You are ready for **Level 2" in learn.quiz_markdown(right)
    assert "Reread the lessons" in learn.quiz_markdown(wrong)
    partly = right[:3] + [None] * (len(learn.QUIZ) - 3)
    assert learn.quiz_markdown(partly).startswith(f"### 3 of {len(learn.QUIZ)} correct (5 not answered yet)")
    assert learn.grade(learn.QUIZ, [])[1].count("Not answered yet") == len(learn.QUIZ)
    assert learn.QUIZ_PASS_MARK <= len(learn.QUIZ)


def test_labs_cover_apply_and_analyze_and_name_real_circuits():
    assert {lab.bloom for lab in learn.LABS} == {"Apply", "Analyze"}
    assert len({lab.key for lab in learn.LABS}) == len(set(learn.lab_titles())) == len(learn.LABS)
    circuits = {c.name for c in load_circuits()}
    for lab in learn.LABS:
        assert lab.circuit or lab.run or lab.bench, lab.key
        assert lab.circuit is None or lab.circuit in circuits, lab.key
        assert 1 <= len(lab.questions) <= learn.LAB_QUESTION_SLOTS
        text = learn.lab_markdown(lab)
        assert lab.title in text and lab.bloom in text and "Set up this lab" in text
    assert learn.get_lab(learn.LABS[2].title) is learn.LABS[2]
    assert learn.get_lab("no such lab") is learn.LABS[0] and learn.get_lab(None) is learn.LABS[0]
    lab = learn.LABS[1]
    assert learn.lab_feedback(lab, [q.correct for q in lab.questions]).startswith("**2 of 2 correct**")
    assert learn.lab_feedback(lab, [None, None]).startswith("**0 of 2 correct**")
