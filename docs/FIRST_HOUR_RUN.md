# The first hour and goals: the automated build (owner-approved 18 Nov 2026)

The feature freeze lifts for this one feature. Hourly sessions, 03:05 to 15:05 IST 19 Nov (after the performance build), build it end
to end from docs/PLAYER_EXPERIENCE.md (its Parts 1, 2 and 4, and the owner's five decisions at its end). Each run
works about 50 minutes. Follow CLAUDE.md, and docs/POLISH.md's "Safe merging and no overlap" and owner's taste.
Log: the Claude doc "Farm game: polish loop log", rows prefixed "Goals:".

## Steps (PLAYER_EXPERIENCE.md "Order of work and size")
| step | what | done when |
|---|---|---|
| 1 | `Game.record` and the event stream (replaces `ribbons.bump`) | tests pass; ribbons still work |
| 2 | `GoalSystem` and data/goals.json: story chains, daily jobs, projects; progress, rewards, saving | tests pass |
| 3 | `HudGoals`: goal faces, the goal sheet, Show me, rewards, in the existing kit | fits every phone shape (menu sweep) |
| CHECKPOINT | upload one picture of the goal faces and sheet (noon, 20:9) to the log under "Goals: waiting for your look" | the owner approves in the log or chat |
| 4 | the Welcome chain, Starter Seeds (one 3-minute plot, first session only), buttons that appear as goals need them, reveals | a bot plays a new farm and hits every step of Part 2's minute-by-minute plan |
| 6 | the balance bot follows goals and takes breaks; first-hour measurements in the log | numbers logged |
| 7 | six neighbour chains, daily job templates, three projects: the orchard, rebuilding the broken tractor, the rare coop | the bot completes every chain |
| then | 5, 8, 9 only if time allows | |
While the checkpoint waits, work on 6 and the data side of 7; build step 4 only after the owner's approval.

## Rules
- One step per branch (`goals/<step>`), tests for every rule, data-driven, player text in locale/strings.csv,
  the existing UI kit (BookPanel, UiKit, CardList, FloatText) and icon style (tools/make_ui_icons.py).
- Merge only a finished step: `git fetch`, rebase on main, full `tools/precheck.sh`, fast-forward push to main,
  never force, never a merge commit; a rejected push means fetch, rebase, check again. A half-done step stays on
  its branch, with a handoff in docs/NEXT.md.
- After every merged step, a bot plays a brand-new farm from minute zero; a broken first hour is fixed first.
- The showcase farm shows goals (GoalSystem.showcase()).
- New goal icons are drawn in the existing icon style without waiting; list them in the log so the owner can veto.
- Report, do not build: anything the spec does not decide, a change to a look the owner picked, a redesign, a
  feature outside this one.
- Frugal: read only what you need; no sub-agents; no model change; never send pictures except the checkpoint's.
