# The polish loop: the owner's vision, taste and guardrails

A scheduled session runs this every hour (restarted 18 Nov 20:30 IST, until 08:35 IST 19 Nov). Its log is the Claude doc "Farm game:
polish loop log" (https://claude.ai/artifact/N3Tco9YLD79rwmApLH9hWP, doc id aa67cd85-0a81-4920-b45b-dc016d1fe1a8).
Read this, CLAUDE.md and docs/NEXT.md first. Act as the owner would ask, in the nature and depth they ask.

## The goal
We have a car's chassis and engine that run; it must look, feel and drive like a Mercedes. Not a new car. Every
part of the game is brought up to this finished-product bar:
1. Looks finished: any screen could be a store screenshot; coherent, soft, warm art; nothing cheap, flat, sharp or
   clashing; good on a full farm, at dawn, noon, dusk and night, on a small phone.
2. Feels good: motion with weight and real timing, every tap answered, sound and animation tuned, nothing jittery,
   rushed or placeholder.
3. Works: no bugs, crashes or stuck states; edge cases handled (full Barn, long offline, clock change, an empty or
   crammed farm); inside the phone performance budget.
4. Fair: the economy and progression make every choice worth something, rewards felt (a player gets a kick from
   achieving), challenging enough to come back daily, at most slightly pay-to-win, nothing redundant.
5. Solid: saves safe, cheating guarded against, code clean and data-driven.

## What the game is
The original FarmVille (2009), recreated in Godot 4.7 for Android phones and tablets, landscape. Pure FarmVille
first; our own touch only where it is clearly marked. Every system is built (docs/V1.md); new features are frozen
(17 Nov 2026). The work now is to bring what is there up to the bar, never to replace it.

## How the owner judges (from every session: project docs claude/owner-inputs/*.md hold their words)
- They play on a phone and react to what looks cheap, shallow, scary, sharp, cluttered, immature or inconsistent.
  They want a finished commercial game: soft, rounded, warm, cosy, mature. Over-saturated, deep colours read as
  immature to them (the rainbow was "too deep and saturated"); lighter, gentler colours win.
- Consistency is a rule: an icon in another style, a colour that does not match, a shape sharper than its
  neighbours stands out to them at once. Match the set; never introduce a new style.
- Motion must feel real and weighty: animals walk on the ground (not rubber, not puppets on threads), peck and
  turn at real speeds; celebrations stay restrained (a level-up is fireworks only, nothing else bouncing).
- Interactions stay minimal: a tap does the one obvious thing (a rusty vehicle's sign opens only its repair).
- They improve what exists; they rarely want it replaced: smaller, softer, better coloured, more detail where the
  eye goes (zoomed in), less noise where it doesn't.
- They look at the whole: does the farm look good filled? at night? does the showcase farm show every feature
  (it must keep up by itself)? The Barn is the hero building.
- Think beyond their words: their ideas are a starting point; find what else would make the same thing better.
- Audits run on main, never a feature branch. Rebase on main before pushing.
- Code quality is expected throughout: data-driven, each fix applied to every similar module, tests for rules.
- Picked looks so far (keep them): mown-stripes lawn with no grass clumps; ready signs as small bubblegum-pink
  pins; lawn yards with a trodden path gate to door; farmer with button eyes and an open smile; inbox icon an
  envelope with a red seal; chunky flowers; calm deep water with life; storybook buildings; VIP and rust on; VIP
  top boost x1.5; the wooden-tok tap sound; icon glow option C (gold behind money and rewards, blue-white behind
  something new); a deep night (pick B, 19 Nov: moonlit blue, about 60% darker than noon); the goal faces, the goal sheet and its calendar icon (approved 18 Nov 23:32). Parked by the owner: the Barn's weather looks (storm, wind, winter liked; a lighter rainbow).

## The owner's-eye checklist (owner, 19 Nov: every review, every screen, every change)
The owner plays on a phone, as a player, and judges what a player sees, hears and taps. Their issues of 19 Nov
(inbox, goal sheet, neighbour faces, the clock and night, a tip over empty plots, a dead tap on a rusty vehicle, the
combine's hidden seed step, beeping clicks and loading thuds, panels that snapped, strays every few hours) all break
one of these. Judge on a real farm (a new one, and one played a day), not only the showcase's tidy data:
1. Nothing contradicts itself: the clock, the light, the icons, the animals, the tips and the counts always agree
   with the farm's real state. Two things that disagree are a bug.
2. Every tap does the obvious thing at once: no dead taps, no hidden order of steps; what can't be done says why
   and offers the fix on the spot.
3. Every screen looks like its neighbours: the same panel size, line shape, spacing and style as the panels beside
   it; nothing overflowing, overlapping, cut off, empty-boxed or stretched into long lines; small pictures in line.
4. Sound and motion feel premium: soft, weighty, smooth; quiet when it should be (loading); no beeps, no snaps.
5. Rewards stay special: nothing floods (caps per day or week, data/rolls.json); FarmVille's rhythm, not a slot machine.
6. Simple but awesome: fewer, stronger moments; cheap and beautiful together; never a feature half done.
7. The owner can see every state: the showcase shows every feature and lets them try every weather and moment.
8. The economy keeps its promises: data/sim_targets.json lists each one (with the gap that put it there). The
   Economy audit workflow (tools/audit.sh: every bot style, two seeds, 45 days, and the first hour) checks them on
   every economy push and nightly. **Every audit run starts by reading its last result**
   (`gh run list --workflow=audit.yml -L 1`, then the run's summary): a "TARGETS MISSED" is the run's first
   finding, fixed or reported, never a figure to note (owner, 19-20 Nov: repairs at under 1% of earnings and idle
   coins on 75% of days went unflagged). A new gap the owner finds gets its target added, so it is caught next time.
Depth expected: fix the cause, then find the same mistake everywhere else; ask why it was not caught and add a
check (a test) so it cannot come back; bring the next problem before the owner finds it.

## Guardrails
- Fix and polish only: code quality, stress tests, edge cases, phone UI checks, player progression, economy,
  bugs, cheating and bad practice, the whole farm's look, small UI, graphics and animation improvements.
- Stop and report in the log's "Reported, not built" (never build) when the work would: start a new feature;
  diverge from the vision above; need a new look or concept the owner has not picked (make the options sheet
  only if cheap, attach nothing, describe it); or be a very expensive change or a redo (say what and the rough cost).
- Do not change the model or use another one (no model switch, no sub-agents on another model).
- Be very frugal with Claude usage (the owner's plan limits): one backlog item per run; grep, never read whole
  files; no sub-agents; no screenshots unless a look must be checked (then one, at 1x, never sent); skip a run's
  item if it cannot be finished cheaply and report it; a run with nothing worth doing ends at once.
- Never touch the owner's real save, secrets or settings; never delete branches; never force-push main.

## Safe merging and no overlap (both loops, every run; the owner's hard rule)
Two loops run at once (this fix loop and the art loop, docs/ART_POLISH.md), and runs of one loop can overlap.
- Main only ever moves forward: `git push origin HEAD:main` as a fast-forward, never `--force`, never a merge
  commit, never a push of anything that has not passed `tools/precheck.sh` on exactly that commit.
- If the push is rejected (main moved meanwhile): `git fetch`, rebase on the new main, run the full precheck again,
  then push. Never resolve a conflict by dropping the other side's work: keep both, or stop and report.
- After pushing, check `git log origin/main -3` shows your commit on top of what was there; if not, stop and report.
- Claim before working: before starting an item, mark it "in progress (<loop> <time IST>)" in the log doc's
  backlog. Skip any item marked in progress less than 60 minutes ago; clear the mark when merged or reported.
- Four loops run at once from 18 Nov 20:30 IST: fix (this), art, performance (docs/PERF_RUN.md, rows "Perf:")
  and the first hour build (docs/FIRST_HOUR_RUN.md, rows "Goals:"). The fix and art loops leave alone what the other
  two are building: goals, the first hour and its UI (GoalSystem, HudGoals, data/goals.json, the Welcome chain),
  loading and rendering cost (Objects3D's building and batching, AssetRegistry loading, LoadingCover, Instancer).
- Lanes: the fix loop owns rules, numbers, data, saves, tests and code quality; the art loop owns how things look
  and move (shaders, art builders and exports, ui_theme, icons, layout and animation timing). Do not change the
  other lane's files for your own item; if your item needs it, report it for the other loop instead.
- Before starting, `git fetch` and look at the other loop's newest remote branches (polish/*, art/*, art-polish):
  avoid files it is touching right now.

## Procedure for one run
1. Setup: the repo is at /home/claude/farm-game (else clone aniket-patra-1998/farm-game there); `git config
   core.hooksPath tools/hooks`. Godot: /home/claude/godot/godot. If Godot is missing and cannot be installed,
   push a branch, open a pull request and let CI's Tests check it before merging.
2. Deadline: if it is past 08:35 IST on 19 Nov 2026, disable this scheduled task, add a final summary line to
   the log, and stop.
3. Read the log doc (its Backlog and the last rows) and `git log --oneline -15` to see what the last runs did.
4. Other sessions' branches first (every run): for each remote branch with commits not on main and each open
   pull request: read its diff and description; if it is finished, in scope and safe, rebase it on main, run
   the full precheck, fast-forward main to it, and log it; if unsure, report it instead. Never merge a red one.
5. Audit and fix, never idle. The loop does not stop at the backlog: it keeps auditing the game aspect by
   aspect (on main) and fixing what it finds. Each run does one of:
   - Fix: the best open finding in the log's backlog (most runs). Easy gains first: rank by what the player
     gains for the effort, so a cheap fix that clearly improves the game beats a big one.
   - Audit: when no finding is ready, or every third run, take the next aspect in the rotation below, analyse it
     in full against the goal's bar (measure: tests, probes, the balance bot, the code itself), write its
     findings into the backlog ranked by gain for effort (easy gains first), then fix the top one if it is cheap.
   Rotation (then round again, deeper each time): economy; player progression; phone UI; edge cases and stress;
   cheating and save safety; code quality; whole-farm look (full farm, dawn, noon, dusk, night); motion and
   animation; feedback and sound; first-hour feel of what exists; performance on a phone.
6. Fix on a branch `polish/<topic>`, with a test for any rule; apply the fix to every similar module.
7. Merge properly: `git fetch origin && git rebase origin/main`, then `tools/precheck.sh <godot>` must pass,
   then `git push origin HEAD:main` (a fast-forward: no merge commits). If main moved meanwhile, rebase and
   check again. CI's review runs on the push.
8. Log: one row in "Merged to main" (time, what changed and why, short sha) or "Reported, not built"; tick or add
   backlog items; keep docs/NEXT.md's handoff current.

## Backlog (seed; the log doc's copy is the live one, fed by the audits)
Owner-approved first (18 Nov), in order:
A. Random play covers every system (VIP, rust, crafting levels, feeding, storing, helpers, mystery young) and
   jumps the clock mid-run (+1 hour, +1 day, +30 days, -1 day), checking every invariant after each jump; the push
   run stays small, a long run (hundreds of seeds, thousands of steps) goes in its own nightly CI workflow.
B. Validation of the number files outside the catalog (balance.json, rolls.json and the rest): no negative cost,
   no chance over 1, no missing field; fails the build.
C. Exploit hunter: the balance simulator searches for the fastest coin and XP loops (search code, not an LLM);
   a loop that beats the intended pace is a finding.
(Clock-tamper protection against server time waits for cloud saves: a launch item, not now.)
1. Other sessions' branches (see step 4).
2. Phone UI: every panel and sheet at 20:9 and 4:3; nothing cut, off screen or too small to tap.
3. Edge cases and stress: full farm, empty farm, full Barn and inbox, long offline time, clock changes.
4. Cheating and bad practice: save tampering, clock rewinds, buy-and-sell loops, negative counts.
5. Economy pass with the balance bot (docs/NEXT.md "Economy" lists the findings).
6. Player progression: XP curve after level 20, unlocks through 31-40, a level-up reward that is felt.
7. Code quality: long functions, logic repeated across similar modules, rules outside data.
8. Whole-farm look: a filled farm at dawn, noon, dusk and night; anything cheap or out of place.
9. Small polish: UI motion, animation timing, sound balance (sound: measure first, tools/sound_cuts/audit.py).
