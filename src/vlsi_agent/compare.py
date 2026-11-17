"""Evaluate a run, or two runs side by side (Level 3 of the learning path).

Each scored attempt falls into one of four cases, from what the run's own checks said
and what the hidden reference test said. From those cases this module derives plain
statements about a run (did revising help, how much of the run was spent after the
design was already correct, did the testbench miss a bug) and about the difference
between two runs. Plain Python over runview.RunView; only the figure needs Plotly.
"""

from __future__ import annotations

from pathlib import Path

from vlsi_agent.runview import AttemptView, RunView

VERDICT_TEXT = {
    "correct_accepted": "correct design, accepted",
    "correct_rejected": "correct design, rejected (false alarm)",
    "wrong_accepted": "wrong design, accepted (missed bug)",
    "wrong_rejected": "wrong design, rejected",
    "unscored": "not scored by the hidden test",
}
VERDICT_COLORS = {"correct_accepted": "#3fa66b", "correct_rejected": "#e0b25a", "wrong_accepted": "#e3705d",
                  "wrong_rejected": "#8a94a0", "unscored": "#c5ccd3"}

REASONING_PROMPTS = (
    "What exactly did you change between the two runs, and what did you expect to happen?",
    "What do the hidden-test scores say? Did your change fix something, break something, or neither?",
    "Did the run's own checks agree with the hidden test? If not, was the design or the testbench wrong?",
    "What did the change cost in attempts, tokens and time?",
    "One run of each is weak evidence. What would you run next to be more sure?",
)


def attempt_verdict(a: AttemptView) -> str:
    """Which of the four cases an attempt is (a key of VERDICT_TEXT)."""
    if a.reference is None:
        return "unscored"
    if a.reference["outcome"] == "pass":
        return "correct_accepted" if a.dev_passed else "correct_rejected"
    return "wrong_accepted" if a.dev_passed else "wrong_rejected"


def _attempt_tokens(history: dict, number: int) -> int:
    entry = next((a for a in history["attempts"] if a["number"] == number), {})
    return int(entry.get("prompt_tokens", 0)) + int(entry.get("output_tokens", 0))


def _source(run: RunView) -> str:
    if run.origin:
        return "your own design" if run.origin.get("own_design") else "a manual edit"
    settings = run.history["settings"]
    name = Path(str(settings["prompts"]).replace("\\", "/")).name
    return f"strategy `{name}`" + (" (testbench written first)" if settings.get("workflow") == "spec_first" else "")


def run_facts(run: RunView) -> dict:
    """What happened in a run, as plain values."""
    h = run.history
    verdicts = [attempt_verdict(a) for a in run.attempts]
    final = h.get("reference")
    first = run.attempts[0].reference if run.attempts else None
    if final is None:
        effect = "no_design"
    elif len(run.attempts) < 2:
        effect = "single"
    elif first is None:
        effect = "unknown"  # earlier attempts were not scored (the run was made without score_every_attempt)
    else:
        effect = {(True, True): "kept", (False, True): "fixed", (True, False): "broken",
                  (False, False): "still_wrong"}[(first["outcome"] == "pass", final["outcome"] == "pass")]
    correct_at = next((i for i, v in enumerate(verdicts) if v.startswith("correct")), None)
    later = run.attempts[correct_at + 1:] if correct_at is not None else []
    final_number = h.get("final_attempt")
    final_attempt = run.attempt(final_number) if final_number is not None else None
    return {
        "circuit": h["circuit"],
        "split": h["split"],
        "source": _source(run),
        "model": h["settings"]["model"],
        "attempts": len(run.attempts),
        "max_attempts": h["settings"]["max_attempts"],
        "status": h["status"],
        "tokens": h["tokens"]["total"],
        "seconds": h["duration_s"],
        "first_outcome": first["outcome"] if first else None,
        "final_outcome": final["outcome"] if final else None,
        "final_score": f"{final['passed']}/{final['total']}" if final and final.get("total") else "",
        "effect": effect,
        "verdicts": verdicts,
        "first_correct_attempt": run.attempts[correct_at].number if correct_at is not None else None,
        "attempts_after_correct": len(later),
        "tokens_after_correct": sum(_attempt_tokens(h, a.number) for a in later),
        "cells": final_attempt.checks.get("cells") if final_attempt else None,
    }


def _times(n: int) -> str:
    return "once" if n == 1 else f"{n} times"


def observations(facts: dict) -> list[str]:
    """Statements about one run that follow from its facts."""
    out = []
    final, score = facts["final_outcome"], facts["final_score"]
    if final is None:
        return ["No reply contained a Verilog module, so there is no design to score."]
    counts = f" ({score} checks)" if score else ""
    out.append(f"The final design **{'passes' if final == 'pass' else 'does not pass'}** the hidden test: "
               f"{final.upper()}{counts}.")
    effect = facts["effect"]
    if effect == "fixed":
        out.append("Revising helped: the first attempt was wrong and the final design is correct.")
    elif effect == "broken":
        out.append("Revising hurt: the first attempt was correct and the final design is not.")
    elif effect == "kept":
        out.append("The first attempt was already correct, so the later attempts could not improve the score.")
    elif effect == "still_wrong":
        out.append("The design was wrong on the first attempt and is still wrong at the end.")
    elif effect == "unknown":
        out.append("Only the final attempt was scored, so this run cannot show whether revising helped.")
    verdicts = facts["verdicts"]
    false_alarms, missed = verdicts.count("correct_rejected"), verdicts.count("wrong_accepted")
    if false_alarms:
        out.append(f"Its own checks rejected a correct design {_times(false_alarms)}: on those attempts the "
                   "testbench was wrong, not the design.")
    if missed:
        out.append(f"Its own checks accepted a wrong design {_times(missed)}: the testbench did not catch the bug.")
    if facts["attempts_after_correct"]:
        share = (f" ({facts['tokens_after_correct']:,} of {facts['tokens']:,} tokens)"
                 if facts["tokens_after_correct"] else "")
        out.append(f"Attempt {facts['first_correct_attempt']} was already correct; "
                   f"{facts['attempts_after_correct']} further attempt(s){share} were spent after that.")
    if final != "pass" and "wrong_rejected" in verdicts and not missed:
        out.append("The checks did flag the wrong design, but the feedback did not lead to a fix within the limit. "
                   "Read the feedback: does it point at the real bug?")
    if not facts["tokens"]:
        out.append("No model was called: this design was written or edited by hand.")
    return out


def _cell(value) -> str:
    return "none" if value is None or value == "" else str(value)


def facts_table(a: dict, b: dict) -> str:
    def outcome(f: dict, key: str) -> str:
        return f[key].upper() if f[key] else "none"

    rows = [
        ("Circuit", f"`{a['circuit']}` ({a['split']})", f"`{b['circuit']}` ({b['split']})"),
        ("Made by", a["source"], b["source"]),
        ("Model", a["model"], b["model"]),
        ("Hidden test, final design", f"**{outcome(a, 'final_outcome')}** {a['final_score']}",
         f"**{outcome(b, 'final_outcome')}** {b['final_score']}"),
        ("Hidden test, first attempt", outcome(a, "first_outcome"), outcome(b, "first_outcome")),
        ("Attempts used", f"{a['attempts']} of {a['max_attempts']}", f"{b['attempts']} of {b['max_attempts']}"),
        ("Stopped because", a["status"].replace("_", " "), b["status"].replace("_", " ")),
        ("Tokens", f"{a['tokens']:,}", f"{b['tokens']:,}"),
        ("Time", f"{a['seconds']:.1f} s", f"{b['seconds']:.1f} s"),
        ("Cells after synthesis", _cell(a["cells"]), _cell(b["cells"])),
    ]
    lines = ["| | Run A | Run B |", "|---|---|---|"] + [f"| {name} | {x} | {y} |" for name, x, y in rows]
    return "\n".join(lines)


def _same_text(x: str | None, y: str | None) -> bool:
    return x is not None and y is not None and " ".join(x.split()) == " ".join(y.split())


def final_design(run: RunView) -> str | None:
    number = run.history.get("final_attempt")
    return run.attempt(number).design if number is not None else None


def differences(a: RunView, b: RunView) -> list[str]:
    """Statements about run B relative to run A."""
    fa, fb = run_facts(a), run_facts(b)
    out = []
    if fa["circuit"] != fb["circuit"]:
        out.append(f"**The runs are on different circuits** (`{fa['circuit']}` and `{fb['circuit']}`), so a "
                   "difference may come from the circuit and not from your change. Compare runs on the same circuit.")
    pass_a, pass_b = fa["final_outcome"] == "pass", fb["final_outcome"] == "pass"
    if pass_a and pass_b:
        out.append("Both final designs pass the hidden test, so the hidden test cannot rank them. Compare cost "
                   "(tokens, time) and size (cells) instead.")
    elif pass_b:
        out.append("Run B's final design passes the hidden test and run A's does not.")
    elif pass_a:
        out.append("Run A's final design passes the hidden test and run B's does not.")
    else:
        out.append("Neither final design passes the hidden test. Compare the scores and the first mismatches "
                   "(Level 2, **Hidden test** tab) to see whether they fail in the same way.")
    if _same_text(final_design(a), final_design(b)):
        out.append("The two final designs are the same code (ignoring spacing).")
    if fa["tokens"] and fb["tokens"]:
        ratio = fb["tokens"] / fa["tokens"]
        if ratio >= 1.25 or ratio <= 0.8:
            out.append(f"Run B used {ratio:.1f} times the tokens of run A ({fb['tokens']:,} against {fa['tokens']:,}).")
        else:
            out.append(f"The runs used a similar number of tokens ({fa['tokens']:,} and {fb['tokens']:,}).")
    out.append("**One run of each is an example, not a result.** The same settings can give a different design on "
               "the next run. The benchmark in Level 2 uses 25 runs per strategy for that reason.")
    return out


def _bullets(lines: list[str]) -> str:
    return "\n".join(f"- {line}" for line in lines)


def comparison_markdown(a: RunView, b: RunView) -> str:
    fa, fb = run_facts(a), run_facts(b)
    return "\n\n".join([
        facts_table(fa, fb),
        "#### What run A shows", _bullets(observations(fa)),
        "#### What run B shows", _bullets(observations(fb)),
        "#### B compared with A", _bullets(differences(a, b)),
    ])


def evaluation_report(a: RunView, b: RunView, name_a: str, name_b: str, answers: list[str]) -> str:
    """The comparison plus the user's own reasoning, as one markdown document."""
    parts = ["# Evaluation of two runs", f"- Run A: `{name_a}`\n- Run B: `{name_b}`", comparison_markdown(a, b),
             "## My reasoning"]
    for prompt, answer in zip(REASONING_PROMPTS, list(answers) + [""] * len(REASONING_PROMPTS)):
        parts += [f"**{prompt}**", (answer or "").strip() or "(not answered)"]
    return "\n\n".join(parts) + "\n"


def verdict_figure(runs: list[tuple[str, RunView]]):
    """One bar per attempt of each run: the share of hidden-test checks passed, coloured by the
    case the attempt falls into."""
    import plotly.graph_objects as go

    bars: dict[str, dict[str, list]] = {key: {"x": [], "y": [], "hover": []} for key in VERDICT_TEXT}
    order = []
    for label, run in runs:
        for a in run.attempts:
            verdict = attempt_verdict(a)
            ref = a.reference or {}
            share = 100 * ref["passed"] / ref["total"] if ref.get("total") and ref.get("passed") is not None else 0
            name = f"{label} · attempt {a.number}"
            order.append(name)
            bars[verdict]["x"].append(name)
            bars[verdict]["y"].append(max(share, 2))  # a sliver, so a 0% attempt still shows its colour
            score = f"{ref['passed']}/{ref['total']}" if ref.get("total") else (ref.get("outcome") or "not scored")
            bars[verdict]["hover"].append(f"{name}<br>{VERDICT_TEXT[verdict]}<br>hidden test: {score}<br>"
                                          f"own checks: {'PASS' if a.dev_passed else 'FAIL'}<br>"
                                          f"{_attempt_tokens(run.history, a.number):,} tokens")
    fig = go.Figure()
    for verdict, data in bars.items():
        if data["x"]:
            fig.add_bar(name=VERDICT_TEXT[verdict], x=data["x"], y=data["y"], hovertext=data["hover"],
                        hoverinfo="text", marker_color=VERDICT_COLORS[verdict])
    fig.update_layout(
        title={"text": "Each attempt: hidden-test score, coloured by what its own checks said",
               "font": {"size": 14}, "x": 0, "xanchor": "left"},
        height=360, margin={"l": 50, "r": 20, "t": 40, "b": 40}, paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)", font={"color": "#8a94a0"}, bargap=0.3,
        legend={"orientation": "h", "y": -0.2, "yanchor": "top", "x": 0},
        modebar={"bgcolor": "rgba(0,0,0,0)", "color": "#8a94a0"},
    )
    fig.update_xaxes(categoryorder="array", categoryarray=order, showgrid=False)
    fig.update_yaxes(title="hidden-test checks passed", range=[0, 105], ticksuffix="%",
                     gridcolor="rgba(128,128,128,0.2)", zeroline=False)
    return fig
