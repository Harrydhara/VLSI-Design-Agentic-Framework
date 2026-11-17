# Final video: recording plan

The final video shows the site as a visitor meets it: Start here, then Level 1, Level 2, Level 3 and the
Developer view. Every team member records part of it on their own machine, from their own file, and the parts
are stitched together. This plan fixes the settings, the hand-over points and the transitions in advance, so
the parts fit without re-recording.

Speakers are named by role only, in this file and in the video.

## Rules from the assignment, and how each is met

| Rule | How |
|---|---|
| All members take part in the video and the demo | Three roles, each with its own demo segments and narration (table below) |
| No speaker's face or name in the video or the demo | Screen and microphone only, no webcam. Say "we" and "our team", never a name. Check the screen for names before recording (list below) |
| Clean screen: only the site, no Zoom or other tabs | Record the dashboard in an app window that has no tab bar (command below). No meeting software running |
| Transitions prepared beforehand | Six title cards made before recording; every segment starts and ends on an agreed screen (table below) |
| Members may speak from their own file; parts are stitched | One file per segment, same resolution, zoom and theme; joined in the order of the table |
| The site goes Beginner, Intermediate, Advanced, with a developer view | The segments follow the tabs from left to right |

## Before recording (everyone)

1. Update to the same commit: `git pull`, then `docker compose up -d --build` (or `pip install -e ".[dev,ui]"`
   in WSL). Run `docker compose exec app vlsi-agent doctor`.
2. No GPU on your machine? Start only the dashboard:
   `docker compose run --rm --no-deps --service-ports app`. Everything in your segment that uses recorded runs,
   the scripted demo, Level 1, the comparison and the Developer view works without the model.
3. Open the site in a window without tabs, address bar or bookmarks, in the light theme:
   - Windows: `start chrome --app="http://localhost:7860/?__theme=light"` (Edge: `start msedge --app=...`)
   - macOS: `open -na "Google Chrome" --args --app="http://localhost:7860/?__theme=light"`
4. Window 1920 x 1080, page zoom 125%. Record at 1080p, 30 frames per second, microphone only.
5. Close mail, chat and meeting software; turn on Do Not Disturb; hide the taskbar or dock.
6. **Names on screen.** None of these may be visible: a browser profile picture or account name, the operating
   system's user name (terminal prompt, file dialogs, window titles), the GitHub address of the repository,
   a file path with a user folder. The Developer view already replaces user folders in run files with `~`.
   Do not show a terminal; if a download dialog opens, stop the recording before it appears.
7. Record ten seconds of silence first, so the editor can match the noise level of the three microphones.

## Segments

Times are targets; the total is about nine minutes. "Starts on" and "ends on" are the exact screens, so the
cut from one file to the next is clean.

| # | Role | Tab | Starts on | What is shown | Ends on | Time |
|---|---|---|---|---|---|---|
| 0 | editor | | Title card 0 | Project title, course, "Interactive Deep Learning Toolkit". No names | | 0:10 |
| 1 | Evaluation lead | Start here, Level 1 | **Start here**, top of page | Scroll once through what, why, who, prerequisites and the level table. Press **Begin with Level 1**. Lesson 2: move `b` from 128 to 5 and back. Lesson 3: set `a = 15`, `b = 1`. Lesson 4: move the slider from 3 to 0. Lesson 6: choose FAIL and PASS. Quiz: answer two questions, one wrongly, press **Check my answers** | Quiz result visible | 2:20 |
| 2 | Implementation lead | Level 2 | **Level 2**, Guided labs, Lab 1 selected | Lab 1: **Set up this lab**, **Generate & test**, the log, the table, the diff. Lab 2: **Set up this lab**, own checks FAIL and hidden test PASS three times, the feedback, the testbench line; answer the first question | Lab 2 answers checked | 2:20 |
| 3 | Verification lead | Level 2, Level 3 | **Level 2**, Lab 3 selected | Lab 3: the hidden test's mismatches, **Draw waveform**, add `signed` twice, **Check & test**. Then **Level 3**, section A: load `ignores_cin.v` for `adder4`, **Put a testbench skeleton into tb.v**, **Check & test**, read the verdict; fix the design and test again | Section A verdict visible | 2:20 |
| 4 | Evaluation lead | Level 2, Level 3 | **Level 2**, Lab 4 selected | Lab 4: two charts (passes after k attempts; own checks against the hidden test). Then **Level 3**, section C: **Choose an example pair**, **Compare**, read two statements, type one answer, **Download my evaluation** | Section C with the download ready | 1:20 |
| 5 | Implementation lead | Developer view | **Developer view**, top of page | The data-flow table; open `learn.py` in Source code; in Inside one run choose the alu4 run: Events, Where the time went, Messages | Timing chart visible | 1:00 |
| 6 | editor | | Title card 6 | What the site does not claim (one model, small circuits, not a sign-off flow) and what is next | | 0:20 |

Roles: the evaluation lead presents the teaching content and the evidence, the implementation lead the agent
loop and the code, the verification lead the bug, the fix and the user's own design. Everyone speaks, and
everyone drives the demo in their own segment.

### What to say (keep to the point of each segment)

1. **Start here and Level 1.** What a chip designer writes, why a design that compiles can still be wrong, who
   the site is for, and what a visitor needs beforehand. Then: "Level 1 is Bloom's Remember and Understand."
   On the signed explorer: the same bits, two readings. On the timing explorer: a correct counter fails a
   testbench that looks too early.
2. **Level 2, labs 1 and 2.** "Level 2 is Apply and Analyze: the tool is set up, the visitor does the work."
   The loop fixes a carry bug from the tool's feedback. Then the opposite case: three correct designs, three
   rejections, and the specification shows the testbench was wrong.
3. **Lab 3 and Level 3 A.** From the hidden test's mismatches to one line of RTL: one word, `signed`, fixes it.
   "Level 3 is Evaluate and Create: now the visitor's own design and testbench are judged." Read the verdict
   aloud, for example "wrong design, accepted: the testbench missed the bug."
4. **Lab 4 and Level 3 C.** Single runs are examples; the benchmark is the evidence: 200 runs, revision fixed
   10 and broke 4, and the model's own checks rejected 163 of 305 correct attempts. Then the comparison: the
   tool states the facts, the visitor writes the conclusion.
5. **Developer view.** Every chart is rebuilt from a run folder. Show the function behind a control, the
   source, and one run's events and timing.

## Transitions (made before recording)

Six title cards, 1920 x 1080, same font and background as the slides, shown for two seconds with a half-second
cross-fade on each side:

| Card | Text |
|---|---|
| 0 | VLSI Design Agent: an interactive toolkit for Verilog generation and verification |
| 1 | Start here · Level 1 · Beginner: Remember and Understand |
| 2 | Level 2 · Intermediate: Apply and Analyze |
| 3 | From analysis to creation: Level 3 · Advanced: Evaluate and Create |
| 4 | Evidence and evaluation |
| 5 | Developer view: the code behind the page |
| 6 | Limits and next steps |

Cards 1 to 5 go in front of segments 1 to 5. Because each segment starts on the tab the card names and ends
on a still screen, no cut falls in the middle of an action.

## Stitching

1. Name the files `segment-1.mp4` to `segment-5.mp4`; keep the raw recordings.
2. Put them on one timeline in the order of the table with the cards between them. Any editor works
   (DaVinci Resolve, Shotcut, iMovie, Clipchamp).
3. Trim each file to its agreed first and last screen; normalise the loudness of the three voices; remove
   pauses longer than two seconds during model calls (a live run of `alu4` takes about 55 seconds: cut it to 10).
4. Watch the result once only for names and stray windows, then once for sound.
5. Export 1080p MP4.

## If something goes wrong

| Problem | What to do |
|---|---|
| No GPU, or the model is slow | Lab 1 uses the scripted model on purpose. For a live run use the recorded one: `ui/20261020-151728-alu4-default` |
| The tools are missing on the recording machine | Labs 2 and 4, Level 1, section C and the Developer view need none. Lab 3's saved result is `manual/20261020-141335-alu8-edit` |
| A recorded run is "not on this machine" | The `runs/` folder of the repository was not mounted: start the stack from the repository folder |
| A segment runs long | Cut inside the segment, never its first or last screen |
