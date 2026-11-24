# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The project is still in initial development (`0.x`): file formats may change.
Since 0.10.0 no automatic migration ships with the skill: a project forged with an older format is brought up to date by hand.

## [Unreleased]

### Removed

- Test rules no longer live in the skill: no scoped tests imposed after a task, no full suite before engraving (`**Full check:**` line, CI detection and report lines included), no full suite run by a linked project's delegate (`full_check` dropped from `FORGE_DONE`, the parent note and the `Linked` question). What to run and when belongs to the project's `coding-standards.md` or `project.md`. An existing `**Full check:**` line is left as is and has no effect; `**Check pattern:**`, used for measurement only, stays.

## [0.13.5] — 2026-11-23

### Changed

- Human time: a wait of more than 60 min and up to 6 h before a prompt or an answer counts 3 min instead of its full length, placed just before the answer so a pause across two tasks counts once; more than 6 h still counts zero.

- Time outside tasks is visible: an `**Unplanned**` row under `**Total**`, written with the branch `**Actual:**` line at engrave and closure. A successful engrave moves the measure checkpoint after its commit, so engraving and the full suite no longer count in the next task (a task in progress keeps its start time). A linked task's estimate stays `· indicative` until its delegate has a plan, then follows that plan's files once.

- Linked worktrees are also removed once their branch is merged into one of the relayed engrave's target branches (`linked-worktree-cleanup.sh --merged-into`, e.g. an engrave limited to `dev`), and a kept worktree always gets a report line with its ready-to-copy `git worktree remove` command — at engrave, merge or not, and at closure.

- Tests scoped to the work: after each task only the tests covering its changed files run; the full suite (`**Full check:**` line of `project.md`, detected at project init or asked once) runs once before engraving, and a red suite stops the engrave before any git command. When a CI pipeline already runs the tests on every push, `**Full check:**` is set to `ci`: nothing runs locally, and the report warns when `master` / `main` was pushed before the CI result.

- The swarm spans repositories: open tasks sharing a `**Linked branch:**` form a `linked` unit, launched in parallel with child branches in the same N slots, relayed and resumed through `swarm.md` (new `Type` column), never merged by the parent. `swarm-status.sh` reports them (`type`, `linked`, `tasks`, `forged`) and reads a drafted plan with `--plan`; as soon as it finds one launchable unit (the parent being a parallel lane itself), the plan question puts "Validate and launch the swarm" first — no more linked tasks chained in series.

- Delegating to an unforged linked project no longer stops: the delegate forges it without a question in the linked worktree (`project.md`, then `coding-standards.md`, shipped with the linked branch), then carries out the mandate; one delegation at a time to the same unforged project.

### Fixed

- Measure journal and branch `input/` files no longer committed when `/forge` started on `main` / `master` (the startup check skips there and never ran again once the branch was created): `engrave.sh run` adds the missing forge `.gitignore` rules (`checks.sh`, new `--dry-run`) and removes such files still tracked from the index (`git rm --cached`, kept on disk) before `add`, so the journal written after an engrave no longer shows as a change. Both actions appear only when needed; history already pushed is never rewritten.

- A linked project's full suite runs again: the delegate runs its `**Full check:**` once, before `FORGE_DONE` (since tests were scoped to each task, nothing ran it any more without a CI). The result goes to the new `full_check:` line, then to the parent task's note, and a failure is shown in the `Linked` question before the relayed engrave, never blocking.
- A message received while a command runs no longer cuts the turn in the measure: when a command started before the prompt ends after it, the time lost between the last activity and the prompt is given back (branch and task); an Escape still counts no pause.
- The empty branch `input/` folder is also created for a linked branch (with its mandate) and a swarm child branch (with its brief), not only when the brief is written in place.
- Linked tasks get their delegate's time, not the parent session's: the plan hook recognises them by `**Linked branch:**` or the delegation note on any line, ties each delegate to its linked project in the journal (no model mark any more), and writes the actual at the tick from that project's delegates only (`time-aggregate.sh --project`) — repositories sharing a branch name no longer add up. No measure reads `—`. The branch `**Actual:**` line counts linked delegates too, outside agent time, total and calibration. A question answered after a delegate's return no longer makes a duration negative.
- Tasks started after a late measure journal (`late_start`) are measured again: only a task started before the journal opened stays unmeasured; the branch measure still reads ` · partial (log started after the branch)`.

## [0.13.4] — 2026-11-23

### Added

- `linked-write-guard.sh` (PreToolUse) refuses any write by the parent session into a linked forged project outside ROOT, except the mandate's `brief.md` and `log.md`: out-of-plan requests on a linked project go through the plan, then delegation.
- The branch's actual time — same shape as the task line, total last (agent incl. checks, human with questions, fixed costs, delegates in parallel) — is written into the plan header at engrave and closure time, not on every plan write.
- Linked worktrees are removed automatically once their branch is merged into the linked project's default branch — after a relayed engrave that merges it, or at parent closure for a merge done outside forge (e.g. a pull request); a worktree with uncommitted changes or an unmerged branch is kept and reported.

### Changed

- The SQL deployment script is a summary to run top to bottom: one `-- STEP` per step, either the path of the script to run (purpose, timing, check, rollback) or a short standalone query with its check query — never a copied script.
- Linked-project delegation names the linked branch with the same rule as a regular forge branch (short kebab-case slug of the delegated task, `-2`/`-3` on collision) and records the link in the parent plan only (`**Linked branch:** <path> @ <branch>`); the linked project never names the parent — the mandate carries the delegated tasks only, no parent brief, folder, branch or client data — unless the task's goal or a reference is required to carry it out, kept to the strict minimum inside the task.

### Fixed

- Deployment script no longer forgotten when the SQL file of a step already planned in `## Deployment` is written later: `plan-hook.sh` reports `deployment script missing` / `incomplete` on every plan write until the script references every written step file.

## [0.13.3] — 2026-11-22

### Added

- `time-calibrate.sh` reports `branch_files`: files of a group at the branch threshold (`branch_minutes` ÷ applied minutes per file, rounded up); the model no longer computes it.
- Swarm actually chosen: the groups table with a `branch` / `task` verdict is always shown once the plan reaches `branch_files`; tasks added during a branch that meet the branch rule are offered as branch tasks with "Validate and launch the swarm"; `Promotion` of a task that turns out branch-sized is offered in the parent too, before any file of the task is written (common text in `p5-resume.md`, delegates refer to it).
- Ordinary subagents limited to reading (exploration, search, review, checks): never parallel writing in the same working tree; writing stays in the session or goes through the swarm.

### Changed

- Swarm with a single branch: the plan of branches starts from one group meeting the branch rule (two before), the parent being a parallel lane itself; `time-calibrate.sh --groups … --parent <files>/<tasks>` counts the parent's ordinary tasks as one more lane (swarm time = longest lane + merges, serial time includes them, `parent_minutes` reported); the groups table gets a `Parent` row and shows from `branch_files` files.
- Swarm parent never idle: while delegates run, the parent chains the ordinary tasks it can take instead of one per turn, and hands back only when none is left. `Mode` is asked once for the whole swarm and kept in the `**Parent mode:**` line of `swarm.md`. A delegate's notification arrives between two tool calls: the parent ends the current action, relays at once, then resumes its task.

## [0.13.2] — 2026-11-22

### Changed

- Hooks live in the skill: `skills/forge/hooks/` holds `forge-precompact.sh`, `time-hook.sh` and `plan-hook.sh`, copied and updated with the skill; `settings.json` points to `~/.claude/skills/forge/hooks/<hook>.sh`. Reinstalling removes the former entries and the former `~/.claude/hooks/forge/` folder (forge files only, folder kept when it holds anything else). `scripts/` keeps what the model and the hooks call.

## [0.13.1] — 2026-11-22

### Added

- `/forge help` (`commands/help.md`): the cycle, every plain-word command (`engrave`, "clean the forge", "update the forge", "launch the swarm", closure, delegation) and the `.forge/` files, translated on display; `help` is reserved and never becomes a branch name. The first `project.md` written points to it.
- State hook also on `SessionStart` (matcher `compact|resume`): objective of the brief, plan and last three LOG entries are injected again after a compaction or when a session resumes.
- `status.sh --target <name>`: `target_exists` in the JSON, used by `/forge <argument>` instead of a separate `git rev-parse` call.
- Tick hook `plan-hook.sh` (`PostToolUse` on `Edit|Write|MultiEdit`, synchronous, declared by both installers): when a plan task is ticked `[x]`, it writes the task marks itself (start = last checkpoint, a `plan_checkpoint` line of the time log) and `**Actual time:**` under the task; the model no longer calls `time-mark.sh` nor `time-aggregate.sh --task`. Swarm branch tasks and tasks delegated to a linked project keep their own actual time.
- The same hook writes the estimates (`**Estimated time:**` of each task with `**Files:**`, frozen; `**Estimate:**` header recomputed from them) and rebuilds `## Summary` on every plan write: `Task | Effort | Files | Estimated | Actual | Status`, short titles kept, blocked reason copied, `**Total**` over the measured tasks only (estimated and actual of the same tasks) and `**Remaining**` rows. A measured actual time is never replaced by `—`. Resume shows this table as is instead of rebuilding it.
- `metrics.sh` writes `metrics.json` (same fields, same order) and reports the estimated vs actual line as JSON; `engrave.sh run --model <id>` calls it before `git add`, closure and swarm merges call it directly. The model no longer computes nor writes the summary.
- Estimate per task = fixed check cost + files × minutes per file: `time-aggregate.sh --task` reports `check_minutes`, the tick hook writes it into the actual time (`· <c> min checks`), `time-calibrate.sh` takes the median check cost from twenty such tasks (`check_minutes`: 2 in `references/estimation.json` before) and computes minutes per file without it; a list of tasks counts one check cost per task (summary `**Remaining**` included).
- Task measure: a task started again before its end keeps only its latest start; the older one no longer stays open forever and no longer makes every later task `overlapping_tasks`.
- Time hook outside forge projects: with no `.forge` folder in the session folder or its parents, `time-hook.sh` exits before any git process (≈ 70 ms instead of ≈ 97 ms per event under Git Bash, bash start-up being most of what is left).

### Changed

- Measure: ordinary subagents (the Agent tool used without a forge delegation) now count as delegated minutes, from their `SubagentStart` → `SubagentStop` pair in the branch log, for the branch and for each task (share inside the task window); an agent delegated to another branch (swarm child, linked project) stays excluded, its time belonging to that branch. Before, they were ignored and a task run by background agents measured only the parent's few seconds.
- Task measure: a task whose window overlaps another task of the same branch (started together, or one started inside the other) is no longer measured (`overlapping_tasks`, `**Actual time:** —`) and leaves the calibration; its time still counts in the branch measure.
- Script permissions: both installers allow the skill's scripts (`Bash(bash "<home>/.claude/skills/forge/scripts/*)`, quoted and unquoted), `SKILL.md` declares the same scripts in `allowed-tools` and fixes one call form, `bash "<SKILL_DIR>/scripts/<script>.sh" …`: outside auto mode, LOG entries, task marks and estimates no longer ask for permission. The unused rule `Bash(bash -c "git branch --show-current*)` is purged on install.
- Resume no longer reads `project.md` and `coding-standards.md`: they are read when the first task of the turn starts, or before a direct action that changes code (section « Contexte du code » of `p5-resume.md`).
- Rare sections load on demand from `commands/`: drafted email (`email.md`), teacher mode (`teacher.md`), SQL deployment script (`deployment-sql.md`), rule propagation to `CLAUDE.md` (`rule-propagation.md`), branch rename (`branch-rename.md`); their triggers stay in `SKILL.md` and `p5-resume.md`.
- A new forge version is announced at the end of the status line, without a question at startup; installing is offered only on "update the forge".
- Swarm estimate: `time-calibrate.sh --groups` takes `<files>/<tasks>` per group, each task paying the check cost.
- Closure no longer asks to copy statuses into `## Summary`: the hook rebuilds it.
- Shared code: hook JSON field reading moves to `json.sh` (`json_string_field`, `json_path_field`), used by both hooks; task status reading moves from `status.sh` to `task-files.sh` (also read by `plan-hook.sh`); clock, folder fingerprint and task mark line move from `time-mark.sh` to `task-marks.sh`. Same behaviour.
- Adding tasks during a branch offers the same choices as a new plan: validate and chain, validate (then choose how to run the tasks), cancel.
- One state hook in bash for both platforms: the Windows installer replaces `forge-precompact.ps1`, file and `settings.json` entry included.

### Removed

- `hooks/ps1/forge-precompact.ps1`.

## [0.13.0] — 2026-11-22

### Added

- Swarm of child branches (`commands/swarm.md`): a plan with at least two groups of tasks meeting the branch rule (one module or feature slice, ≥ 15 min of agent time, delivered and tested on its own) becomes a plan of branches with `**Depends on:**`; "Validate and launch the swarm" runs up to N = 3 delegated forges in parallel, each in its own worktree with its own dependency install and port; questions relayed with a branch prefix and grouped, one end-of-branch question, merges into the parent branch only (fast-forward or reverse merge), `swarm.md` state file, resume after interruption, parent works on ordinary tasks meanwhile, optional ClickUp sub-tasks.
- `scripts/swarm-status.sh`: running, launchable and waiting child branches, simulated merge of the parent, ordinary tasks the parent can take, as JSON.
- Time measurement hook `scripts/time-hook.sh`, added by both installers to `settings.json` (six events, asynchronous: Claude Code never waits for it; the aggregate sorts the log by time): one line per event in the branch's local `time-log.jsonl`, never any prompt, command or tool output.
- `scripts/time-aggregate.sh` and `metrics.json`: at each engrave and at closure, the branch measure (agent, human and check minutes, questions, delegates' tokens, files and lines; an absence of more than 6 h counts no human time) is written to `.forge/branch/<BRANCH>/metrics.json`, tracked in git.
- Estimate: each plan task counts the paths of its `**Files:**` (explicit `(≈ n)` for a glob or unknown files; an older `**Estimated files:**` field still wins); `scripts/time-calibrate.sh` and `references/estimation.json` turn it into agent minutes with a range, calibrated on the project's last measures; plan header `**Estimate:**`, remaining work on resume, estimated against actual at engrave.
- Time per task: `**Estimated time:**` frozen on each plan task; `scripts/time-mark.sh` marks a task's start and tick in `time-log.jsonl` (every delegate, same repository or linked project, writes to the parent's log, `TIME_LOG:` line of its prompt, and reports each task's actual time in `FORGE_DONE`); `time-aggregate.sh --task T<n>[,T<n>…]` measures the agent minutes between both marks, summed over the child tasks of a delegated parent task (unmeasured as soon as one child is); the tick writes `**Actual time:**` (`—` without a measure); progress table gains Estimated and Actual columns.
- `scripts/log-entry.sh`: every `log.md` entry is written by this script, which reads the local clock and puts the entry at the top (below a `# ` title if any, line endings kept); the skill passes the text only, never a date or time — timestamps written by the model were invented.
- `project.md` lines `**Check pattern:**` (commands counted as checks, also proposed when updating an existing `project.md`), `**Install command:**` (asked once, at the first swarm launch) and `**Dev port:**` (written by hand: base port of the swarm worktrees).

### Changed

- Effort letters keep their relative size but lose their human durations; the plan summary gains a files column.
- `checks.sh` also adds `/.forge/branch/**/time-log.jsonl` to the `.gitignore` forge block.
- Same-repository branch delegation records the delegate id and its tokens in the parent's `time-log.jsonl`.
- No absolute path in any file forge writes: the linked brief and log name the parent project by its folder name, the parent plan notes `delegated to <path relative to the root> @ <branch>`, `swarm.md` lists worktrees relative to the root. Older notes with an absolute path are still read.
- `metrics.json` gains `partial`: true when the time log misses the start of the branch (log created after the plan, or first branch commit older than the first event); `time-calibrate.sh` skips such branches.
- `time-calibrate.sh` skips a summary without actual files (no `master` or `main` to count from) instead of dividing by zero; an estimate is at least 1 minute, range bounds included; the file forecast error applies from three measured branches only.
- `time-calibrate.sh --files 3,5,8` estimates every task of a plan and their sum in one call; a task added along the branch gets its `**Estimated time:**` too.
- `time-aggregate.sh` closes a turn still open when the next prompt arrives (message typed while the agent works, Escape, background task notification) at its last observed event, instead of dropping it: agent time was measured about half short.
- `time-aggregate.sh` reads fields with `index()` instead of a regex rebuilt on every call: a 50,000-line log aggregates in 1 s instead of 20 s.
- `time-mark.sh --event delegate|delegate_usage` writes the delegate lines of the parent's time log (the model no longer appends JSON by hand); task marks accept micro-steps (`T2.1`), as does `time-aggregate.sh --task`.
- Swarm: the plan is also written on `Validate and launch the swarm`; resuming a plan of branches asks a `Swarm` question (launch, parent tasks, later) instead of launching delegates; with no launchable branch, the parent's ordinary tasks are offered; the end-of-branch question keeps to four options (one `Merge and launch`).
- Swarm: `swarm.md` keeps each branch's delegate id and port; resuming stopped delegates needs an answer to a `Resume` question (a delegate still running elsewhere would share the worktree); a branch waiting for merge gets its `Next` question again; a port is the lowest free one and kept on relaunch; `Check before merging` only when the branch has a port.
- `swarm-status.sh` reports `invalid` tasks (unknown or free-text dependency, blocked or dropped dependency, dependency cycle, branch name refused by git), `blocked` branch tasks and `stale` worktrees removed by hand, instead of leaving them waiting forever; reads a task's status on its status line only; `--assume-done` computes what a merge would unblock; a missing parent branch is an error, a failed merge simulation `conflict: null`.
- Swarm: merge options say they commit (branch work, parent task in progress first) and the worktree status is shown before `add -A`; decision context is required for choice questions only; no plan of branches in delegated mode; `Turn into a task` has a procedure; limits documented (relay between turns, worktree folder permissions, ignored files and shared database, `core.longpaths`); worktree paths quoted.
- Instructions: `<PARENT_FOLDER>` (delegation) and `<PARENT_BRANCH>` (swarm) replace an ambiguous `<PARENT>`; thresholds no longer overridden from `coding-standards.md`; child branches created at launch only; the delegate's writes outside ROOT (time log, scratchpad) spelled out.
- Branch rule on time alone: a group of tasks of one module or feature slice becomes a branch from 15 min of estimated agent time, if it is delivered and tested on its own; module/API, decision, layer and token criteria dropped (`tokens_per_file`, `branch_tokens`, `branch_criteria_required`, `branch_layers` removed; delegates' raw tokens still measured in `metrics.json`). `time-calibrate.sh --groups [--slots]` computes the swarm time saved or lost from the fixed costs of a branch (minutes only, no token estimate), shown under the groups table and in the launch option.
- Fixed costs of a branch measured: `time-aggregate.sh` returns `delegate_setup_minutes` (a delegate's start to its first task mark) and `merge_minutes` (average of `merge_start` → `merge_done` marks that `time-mark.sh` now writes around each child-branch merge, question waits removed), both kept in `metrics.json`; `time-calibrate.sh` replaces the reference 8 and 5 min with the project's medians (`fixed_costs_source`), so the swarm estimate uses measured costs. The swarm option is always offered, with the estimated time saved or lost.
- Estimate range fitted to the project: from twenty measured tasks, its bounds are the 20th and 80th percentiles of actual ÷ estimated time over the last forty, read from the `**Estimated time:**` / `**Actual time:**` of the branch plans (child branches included; a task-branch or a task delegated to a linked project, which sums several tasks, left out), `range_source`, recomputed at every call; `indicative` now means rates or range still come from the reference values (`checked` and `in_range` removed, the seven-in-ten check having become circular). `time-calibrate.sh` no longer copies `range_low` / `range_high` into its output.
- Actual files per task: task marks carry a fingerprint of the working folder (`time-mark.sh`, shared awk in `scripts/task-files.sh`); `time-aggregate.sh --task` returns `actual_files`, the branch measure `task_files`, `task_planned_files` and `measured_tasks`; the tick writes `· <n> files`. `metrics.json` compares planned and actual files per task on both sides (`branch_files` keeps git's distinct count). `time-calibrate.sh` takes minutes per file and the file forecast correction from the last forty tasks measured with their files, from twenty (`source: tasks`), reference values below — no fallback on whole branches, which now only give a swarm's fixed costs (`measured_branches` removed).
- Skill scripts need bash 5: without `EPOCHREALTIME`, `time-hook.sh` and `time-mark.sh` write nothing and exit 0, `log-entry.sh` exits 2 below bash 4.2. The hook reads the clock first, before parsing its input and calling git: a large tool output no longer delays the event time.
- `**Check pattern:**` matches a check command anywhere in the command line, never anchored with `^`: checks chained after `cd … &&` or run in a loop are counted.

## [0.12.6] — 2026-11-17

### Added

- Check request: a quick check (one command or one read) runs at once; a heavier one is written up as a plan task, with one question — add to plan, check without a task, or cancel.
- Drafted email: every email written for a third party is saved twice in `output/`, `YYYYMMDD-email-<topic>.txt` (plain text) and `.html` (inline styles, real tables, opened in the browser to paste into Outlook).

### Changed

- The closure client reply follows the drafted-email rule: `YYYYMMDD-email-client-reply.txt` and `.html` replace `YYYYMMDD-client-reply.txt`; existing files are neither read nor renamed.

### Fixed

- `SKILL.md` frontmatter: the `description` value is quoted, its ` : ` made the YAML invalid for strict parsers (IDE).

## [0.12.5] — 2026-11-16

### Added

- The branch `input/` folder is created empty when the brief is written.

## [0.12.4] — 2026-11-16

### Added

- `.forge/branch/<BRANCH>/input/`: files brought for the branch's task (CSV/XLSX exports, SQL dumps or extracts from a database Claude cannot reach, data received as files), read instead of a database access, kept out of git by a `.gitignore` line that `scripts/checks.sh`, run detached at startup without waiting, adds when missing; forge draws on it before the project-wide `.forge/input/`.

## [0.12.3] — 2026-11-16

### Added

- `.forge/input/`: reference files used to build the project (source software exports, SQL dumps, database structures, datasets), one subfolder per source, shared by all branches; forge draws on it when a brief or plan needs it.
- Question instead of a goal: on any branch, a question about the project that calls for no action, given as argument or in answer to the goal question, is answered read-only, with no branch, no brief and nothing written.
- Teacher mode writes no explanation file on `main` or `master`: the explanation stays in the answer.

## [0.12.2] — 2026-11-10

### Changed

- Skill update: the background check for a newer `vX.Y.Z` tag now runs at most once every 24 hours instead of every 7 days.
- The shipping command offered by forge now explains itself: `grave` / `engrave` commits and pushes the current branch, and target branches added in order receive it by merge (e.g. `grave dev master`).
- Generated content always stays a local file in the branch `output/` folder, reports and third-party deliverables included: never published online (Claude Docs document, Artifact or any external service), and no online version is offered.
- Task closure, customer message: a fix is announced as done, in the past tense with "we", and described by what the user will see — never by a block, a ban, or a page, file or variable name.

## [0.12.0] — 2026-11-09

### Added

- Skill update: at most once every 7 days, `/forge` asks the repository for its latest `vX.Y.Z` tag in a detached background process, never delaying startup (`skills/forge/scripts/update.sh check`, a few milliseconds on the fast path, silent offline). A newer version is offered at the next `/forge`; on `Update now`, `update.sh run` clones the tag in a temporary folder, runs the platform installer, and forge asks to relaunch; on failure, the last five lines of the clone or installer output are shown. `Later` skips that version (`update.sh dismiss`): only a newer one is offered at startup. "update the forge" checks at once, whatever the delay, skipped version included. Installers write `~/.claude/skills/forge/install.json` (version, repository, last check, latest known tag); an install without it is checked at once and offered the latest version. Tested by `tests/update.test.sh`.
- `tests/install.test.sh`: both installers run in a throwaway home — skills and hook copied, `settings.json` merged without duplicates on reinstall, `install.json` written from a tagged git copy and from a copy outside git. A missing `node` or `powershell.exe` skips the matching installer.

### Changed

- Forge never offers to commit: work left to save is answered with the shipping command, in the user's language: "Tape `grave` pour graver." in French, "Type `engrave` to ship." in English.
- First `project.md` generation no longer asks for validation: forge writes it after exploring, says so in one line and moves on. "clean the forge" still shows its changes before writing.

### Fixed

- Installers: `install.ps1` wrote `settings.json` with a UTF-8 byte order mark that `install.sh` could not parse, so running `install.sh` after it replaced every setting outside forge with an empty object. `install.ps1` now writes without BOM and `install.sh` strips one if present.

## [0.11.0] — 2026-11-06

### Added

- Ticket marker: `/forge-clickup` writes `.forge/branch/<CODE>/ticket.json` (`tracker`, `code`, `url`) when it creates or resumes a branch. Closure reads it to target the task, so renaming the branch no longer breaks the link. The task link is shown on resume and at closure.
- Closure settles open tasks: they are listed next to the objective and, after `Solved`, each one is marked done, dropped or kept open. Dropped tasks use the new `[-] dropped` status, which `status.sh` neither counts nor offers for resuming. Blocked tasks are left alone.
- `/forge` now accepts a goal in words or a ClickUp code as argument. With a space, the text becomes the objective. With `.forge/clickup.json` present, a word that is no existing branch but matches a task (`PRJ-1133` or raw id) opens that task through `forge-clickup`; otherwise it stays a new branch name.
- `/forge-clickup` now accepts the same two forms: a goal in words skips the goal question, a code reads the existing task and creates or resumes its branch, without creating a task.
- `skills/forge/scripts/status.sh`, tested by `tests/status.test.sh`: read-only JSON status of the branch (state, progress, recent log, resumable branches), called once at startup and shown as a one-line status.
- On `main` / `master`, the guard first offers to resume a local branch that has open tasks.
- Express mode: a one-task XS plan gets a single go-ahead instead of two questions.
- Correction rule proposal: when the user asks for a correction of syntax, structure or code convention on content Claude produced, forge applies it, logs it, then drafts a general `When [case] → [behaviour]` rule so the same case is handled right the first time next time. The rule is shown in full and the `Rule` question asks where it goes: global `~/.claude/CLAUDE.md`, the `CLAUDE.md` at the project root (created if absent), or nowhere; no `CLAUDE.md` is written without an answer. This extends the existing propagation section, so infrastructure choices get the same three options instead of `Add to CLAUDE.md` / `Keep it local`. Nothing is proposed for a functional bug, a change of need, a one-off case or a case either file already covers, and a delegated run proposes nothing.
- Branch rename on request: forge runs `git branch -m`, moves `.forge/branch/<name>/` and reports the old name if it still exists on the remote, without deleting it.
- Plan validation offers a third option, listed first: validate and chain. The plan is written, then every open task runs in order — no execution-mode question, no go-ahead between tasks. Validate keeps its behaviour and asks for the mode next. In a delegated `SCOPE: branch` run the option is relayed like the others and, once picked, replaces the mode question and each task go-ahead; in `SCOPE: linked` it is not offered, since validating the plan already chains.
- Generated SQL deployment script: whenever the `## Deployment` section of the plan gains or changes a step that runs SQL — migration, rebuild script, operating query — forge writes or rewrites in place, with no question, a single `output/YYYYMMDD-deployment-script.sql` per branch, dated at creation, and logs it. A header table lists the steps (number, target database, timing, `comment` / `query` form, source tasks); each SQL step gets a `-- STEP [n] — [database] — [timing] · T7, T9` section in plan order. A script versioned in the repository appears as a comment only (path, prerequisites, precautions, production and development variants), never copied; a standalone query (`EXEC`, job, operating `UPDATE`) appears as is, runnable, followed by its check query; date-dependent values are computed in the query; a section holding a `USE` comes last; a step with no SQL is left out.

### Changed

- The closing ClickUp report now depends on the branch, not only on the project: without a marker or a task named after the branch, the step stays silent. Closure no longer asks for a task identifier and never creates or offers a ClickUp task.
- `p5-resume.md` and `SKILL.md` are split: delegation, shipping, closure and delegated mode move to `skills/forge/commands/`, read only when triggered. What every resume loads drops from 40 KB to 15 KB for `p5-resume.md`.
- A file already read in the turn is no longer read again across phases.
- On `main` / `master`, the goal now comes first and forge creates a branch named after it, with no branch question. The temporary branch, stay-on-branch and name-a-branch options are gone; `/forge master` still works directly on `master`.
- With a single open task, resuming asks `Start T<n>` / `Cancel` instead of the `Mode` question.
- A task proposed by out-of-scope detection is now copied as plain text at the top of the `Plan` question — title, effort and the full description as bullets (numbered when order matters) — on a fixed template, since text written before a question may be hidden on screen; files and any `## Scope & rules` entry stay in the reply. A relayed `Plan` question gets its `content` copied the same way. No Markdown heading or table, no `preview` field.
- `engrave.sh run` now reports every git operation as one-line JSON (`branch`, `status`, then `step`, `action`, `branch`, `status`, `detail`, `reason` per action), written on a git failure too: each merge is split into `checkout`, `merge` and `push` of the target; an action is `done`, `skipped`, `failed` (`conflict` with the conflicted files, `rejected`, `git error`) or `not_run` when the sequence stopped before it; details give the commit hash, the pushed range or `up to date`, and `fast-forward`, the merge commit hash or `already up to date`. The final shipping report follows a fixed template laid out by the skill: one table per project, one row per operation — `#`, branch, operation, result, detail —, the result shown as `DONE`, `SKIPPED`, `FAILED` or `HALTED` in every language, with the git error under the table on failure; linked projects follow the parent. Conflicts are never resolved automatically.
- `grave` / `engrave` no longer ask for confirmation: at the start of the message, alone or followed only by existing branches, the command is the go-ahead for that sequence only — no recap table beforehand, the sequence runs at once and only the final report is shown. Any other text in the message means it is not a shipping request. Linked-project questions are still asked: they set the scope, they confirm nothing. A merge conflict or a rejected push still stops the sequence, never forced. In a delegated `SCOPE: branch` run the engrave question is no longer relayed.
- The shipping sequence (`grave` / `engrave`) now runs through a single bash script, `skills/forge/scripts/engrave.sh`, instead of git commands rebuilt from the instructions each time. `run` executes the action list, however many branches are named, and reports as JSON laid out by the skill — the script does the work, the model does the layout; `preview` returns the same planned actions as one-line JSON (`branch`, then `step`, `action`, `detail`, `skip` per action; no `jq` needed, the commit message escaped) without running anything, and is not called by the delivery. Skips (branch equal to the starting one, missing branch, branch checked out in another worktree, clean working tree) and the stop on a merge conflict or a rejected push are handled by the script, exit code `2`. Relayed shipping calls it with `--root` on the linked worktree. Covered by `tests/engrave.test.sh`, run on throwaway repositories.
- Any question about a piece of content — objective, plan, change, report, ticket, message, recap table, proposed rule — now requires that content to be written out in full in the reply, right before the question. Announcing "I'm drafting X" no longer stands in for X, and the content is never reduced to a summary, an option label or the question itself.
- Delegation to a branch of the same repository now creates its worktree in `<repo-folder>.worktrees/X` next to the repository instead of `<repo-folder>-X`: the branch becomes the path (`forge.worktrees/feature/x`). Existing worktrees are still found and reused through `git worktree list`.
- Delegation to a linked project now runs in a git worktree of the linked repository — `<linked-folder>.worktrees/<parent>/<BRANCH>` next to the linked repository, the branch becoming the path, reused when it exists — instead of checking the branch out in the linked folder itself. That folder is never touched, so you can keep working in it by hand while the subagent runs. The linked brief and log are written in the worktree, relayed shipping runs there, and a target branch checked out in another folder is skipped. The worktree holds versioned files only: the linked `.forge/` must be committed, and a task needing dependencies or `.env` comes back blocked. A `git worktree remove` reminder closes the run. Delegations opened before this change keep shipping from the linked folder.
- The client reply drafted at closure now follows explicit tone rules, in the voice of a technical support team: short, fluent, professional, direct and natural, empathetic without being overly warm, focused on solving the problem; it never repeats what the client wrote nor restates their whole request when not needed, and leaves out needless technical explanations, long sentences and heavy administrative wording. The former "pedagogical" tone is dropped.
- Validating a piece of content is no longer capped at two options: the only rule left is that no "rework" or "edit" option is ever offered — a change request still goes through the question's free-text field.
- The closing report now exists only for ClickUp and is no longer a state file: without `.forge/clickup.json`, closure goes straight from the solved confirmation to the client reply and no report is written. With it, the report is generated, saved like any generated content as `output/YYYYMMDD-clickup-report.txt` (rewritten in place on each requested change), then posted as a comment under a single `Post the comment` / `Cancel` question — the separate `Write it` step is gone. `.forge/branch/<BRANCH>/report.txt` is no longer written; existing ones are left untouched.
- Each step of the plan's `## Deployment` section now names the tasks it comes from (`· T1, T3`), and the silent plan-update rule requires those numbers and points to the new deployment script section. Existing plans are updated by hand.
- The main/master safety guard now runs right before the brief instead of right after the branch is read: in a project that has never been forged, `project.md` and `coding-standards.md` are written first — they are shared by every branch and never resolve `<BRANCH>` — and only then does forge ask for a ticket ID or a branch name. A fresh project no longer asks which branch to work under before knowing what the project is.
- The client reply drafted at closure is now also saved as a file: an exact plain-text copy of the draft lands in `.forge/branch/<BRANCH>/output/YYYYMMDD-client-reply.txt` (`-2`, `-3`… for further replies the same day), with no confirmation, as generated content. The draft is still written as an email — one paragraph per line, no Markdown — but it no longer lives only in the conversation: a ticket opened from an email, whatever the tracker, gets the reply as a text file.
- The README now says what per-branch shared context means for a team: developers work on different branches, and any of them can take over a branch started by another one with the actions already done, the context and the documentation needed to continue, since brief, plan, log and deliverables travel with the branch in git.

### Removed

- **Breaking:** ClickUp list aliases: `/forge-clickup <alias>` and the `aliases` key of `.forge/clickup.json`. A leftover key is ignored; tasks are created in the `default` list.
- `phases/p3-log.md` and State 3: `log.md` is created with the brief.

## [0.10.2] — 2026-09-20

### Changed

- The skill description, the README opening and the GitHub repository description now state what forge has become: it orchestrates the whole life of a development branch — validated brief, structured plan, tracked execution, sealed delegation, git delivery with releases, closure — rather than a brief-plan-tracking workflow.
- Once the engrave sequence has run, forge writes nothing more — no log entry, no plan note: the report is plain text and the working tree stays exactly as the delivery left it. Anything worth logging is written before `git add`.

## [0.10.1] — 2026-09-20

### Added

- Delegation to a branch of the same repository: "run a forge agent on branch X", "open branch X in an agent" and the like open `X` in a git worktree — an existing worktree is reused, otherwise `<repo-folder>-X` is created next to the repository — and run the forge skill there in a sealed subagent, after a single confirmation. `X` must exist and differ from the current branch: forge never creates it on your behalf. No mandate is written: the subagent reads project, brief, log and plan as the phases prescribe, and every choice — brief objective, plan validation, execution mode, go-ahead before each task, engrave — is relayed to the user. The run ends with a one-line `FORGE_DONE` that writes nothing into the parent plan; the worktree stays in place with a `git worktree remove` reminder.

### Changed

- The delegated prompt carries a `SCOPE:` line — `linked` (default: mandate, `## Origin`, a validated plan is the go-ahead) or `branch` (no mandate, every choice relayed). The phases read the scope where they decide whether to ask.
- The branch opened in a linked project is now named `<parent>/<BRANCH>` — the parent folder name as prefix, the parent branch unchanged on the right (`forge/linked-project`, `forge/CU-123`) — instead of the bare parent branch name. In the linked repository the branch says where it comes from at a glance and never collides with the project's own branches, ticket IDs included. The linked `.forge/branch/` folder, the delegated prompt, the `delegated to <path> @ …` notes and relayed shipping all carry that name; `## Origin` keeps the parent branch.
- A relayed `FORGE_QUESTION` carries the **full content** being decided on — the whole task description, the whole plan, the brief entry, the recap table — in a `content:` field, never a one-line summary; the parent shows it verbatim before asking. Both scopes.
- A direct action — a precise order that fits in one command or one local edit and calls for no design decision — is carried out at once and logged, never turned into a plan task nor confirmed again; in doubt, forge treats the request as a direct action.
- A request whose result is generated content — documentation, export, SQL script, checking workbook, analysis, client deliverable — is a direct action too, whatever its size: produced in `output/` and logged, never turned into a plan task. The plan only tracks the tasks that implement the brief's objective.

## [0.10.0] — 2026-09-16

### Added

- Delegation to a linked project: a request that targets a folder outside the current project opens the same branch in that already-forged repository, hands it the parent brief plus a mandate — the delegated tasks copied in full under `## Origin` — and runs the forge skill there in a sealed subagent. The linked plan is derived from the mandate alone, every task traced to its parent (`← parent T<n>`); blocking questions are relayed to the user as `FORGE_QUESTION` blocks and answered through the usual `AskUserQuestion`; once the plan is validated the subagent chains every task without asking for a mode; the run ends with a single `FORGE_DONE` report from which the parent checks or blocks each delegated task. A folder without `.forge/` is refused, never initialized.
- Relayed shipping: engraving the parent offers to ship each linked project with uncommitted changes — whether to ship it, then onto which branches (same as the parent, `<BRANCH>` only, or a list of your own). The linked commit message is generated from the delegated tasks marked done; the linked actions get their own recap table and the single confirmation covers parent and linked projects alike. Plain git run by the parent — the delegated subagent is never involved.
- Anything published on the remote forge after a delivery — release title and notes, tag or PR description — is written in English, whatever the user's language; the commit message keeps following the repository's commit language.

### Changed

- Release archives ("Source code" zip / tar.gz) leave out `.forge/`, `docs/`, `.gitattributes` and `.gitignore` through `export-ignore` in `.gitattributes`; the repository itself still tracks them.
- A request outside the current plan always becomes a plan task: forge writes it up — with the brief's `## Scope & rules` entry it implies, if any — and asks one validation only. The "add to the plan / handle it off-plan" choice and the separate brief question are gone.
- `/forge-clickup` asks for the goal of the task, never its title: the ClickUp title and description are derived from the goal and shown for validation before the task is created. Forge then pre-fills the brief's `## Objective` from that same goal.
- Every selectable question — its text, header, option labels and descriptions — is written in the user's language. The English labels in the skill files are internal references only; previously they were shown as-is on screen.
- `log.md` entries carry the time as well as the date: `- [YYYY-MM-DD HH:MM] …`, local time.
- The client reply drafted at closure is empathetic as well as fluent, professional and pedagogical.
- Validating a presented content — brief objective, plan, closing report — offers `Validate` / `Cancel` only. The "rework" option is gone: it cost a round-trip before the user could even say what to change. A change request now comes through the question's free-text field with its explanation; a bare disagreement gets a one-line "what should change?" and the content is never shown again unchanged.
- `/forge <branch-name>` creates a missing branch from the up-to-date default branch — `master`, else `main` — never from the current one, so a new branch never inherits the unmerged commits of whatever branch happened to be checked out. Same sequence as forge-clickup: `checkout <default>`, `pull`, `checkout -b <name>`.

### Removed

- Hammering (`frappe` / `hammer`): the subagent dispatch over the plan, its adversarial review cell and its cross-review. Little used, and the way tasks get executed belongs to the user's coding preferences in `CLAUDE.md`, not to forge. The mode question now offers chaining or picking a task.
- `TODO.txt`: its notes described the log split out of the brief, shipped long ago.
- Every migration and compatibility mechanism: the `.claude/` → `.forge/` move with its `.gitignore` rewrite, the `coding_standards.md` → `coding-standards.md` rename, State 3 moving dated entries out of the brief's `## Decisions & Constraints`, and the background label normalization run by "tidy the forge". State 3 now only creates an empty `log.md`; "tidy the forge" only updates `project.md`. Old-format projects are updated by hand.

## [0.9.4] — 2026-09-16

### Added

- `/forge <branch-name>` takes a git branch name as argument: forge checks it out, creating it from the current branch when it does not exist, and skips the main/master guard. The argument is never read as a ticket ID — previously forge could silently treat it as a reference and keep working on `master`.

## [0.9.3] — 2026-09-15

### Added

- The plan carries a `## Deployment` section: the manual steps that live outside the git deployment — an SQL migration to run, a configuration setting to apply, an operating procedure — each with its timing (before / after deploy) and the path of its copy under `output/`. It starts at `None` and is filled silently as soon as such a script is written, so nothing to run by hand is left to memory at release time.
- A script versioned in the repository but distributed or run apart from the git deployment is copied identically to `output/` the moment it is written; the repository stays the source of truth, `output/` holds the copy to hand over.

### Changed

- Client replies are drafted as email, not as a text file. One paragraph is one line — no hand-wrapping inside a paragraph, which breaks sentences at arbitrary points and often right before a full stop; the mail client handles the rendering. Anything already covered by an attached document is announced in one sentence rather than restated.

## [0.9.2] — 2026-09-10

### Added

- Generated content is written to `.forge/branch/<BRANCH>/output/`. Any file produced on request — a document, an SQL script, an export, a note, an explanation, a client deliverable — lands in that folder instead of the project root or a temporary folder, named `YYYYMMDD-` plus a lowercase kebab-case English label, with no exception — client deliverables included: `20260910-db-migration.sql`. What counts as generated content is settled up front: anything that is neither source code implementing a plan task, nor a file whose location the project dictates, nor one of the skill's own state files. Those — `brief.md`, `plan.md`, `log.md`, `report.txt` — stay one level up under their fixed names, which state detection reads.

### Changed

- Teacher mode writes into `output/` like every other generated file: a new explanation is created as `YYYYMMDD-explanation-<topic>.md`, and a follow-up on the same topic is looked up by topic and appended to the existing file under its original name.

## [0.9.1] — 2026-09-09

### Added

- Report published to ClickUp on task closure. Once `report.txt` is written, `forge` offers to post it as a comment on the ClickUp task whose code is the branch name: the task is read back before anything is sent, never guessed, and nothing goes out without an explicit yes. The step only exists when `.forge/clickup.json` is present — without that file, closure behaves exactly as before.

### Changed

- Confirmations are asked as selectable questions, never as free text. The rule is now part of the skill's absolute rule and covers every blocking confirmation and every closed choice: the `main`/`master` guard, architectural approach, objective and plan validation, substantial plan updates, out-of-scope requests, global rule propagation, hammering, shipping, closure, ClickUp posting and client reply. Refusal is always an explicit option, and no answer means STOP. Open questions stay free text — the goal of the task, a branch code name, a ticket ID, the email to paste, what to do next.
- `forge-clickup` can now be started by the model itself: `disable-model-invocation` is `false`, so a request matching its description opens the task-opening workflow without the user typing `/forge-clickup`. Typing the command still behaves exactly as before.

## [0.9.0] — 2026-09-08

### Added

- `forge-clickup` — task-opening extension, installed alongside `forge` by both installers into `~/.claude/skills/forge-clickup`. It creates the ClickUp task, re-reads it to obtain the `custom_id` that ClickUp only assigns after creation, branches off the repository base branch, pushes it, then hands over to `forge`. List targeting lives in `.forge/clickup.json`, written by the skill itself on first run.
- Execution mode chosen at resume. As soon as the plan still holds an open task, `forge` asks through `AskUserQuestion` rather than free text, offering three options in order: chain every open task without stopping between them, pick a single task, or hammer the plan — every open task dispatched to sub-agents, each tested then reviewed by three adversarial ones. Picking a task opens a second question listing the open tasks, four at most. Nothing starts before the answer. When no task is open — a `[!] blocked` task does not count as open — no mode is offered at all: `forge` asks in one line what comes next, and stops. READMEs cover the three modes.

### Changed

- `forge` can now be started by the model itself: `disable-model-invocation` is `false`, so a request matching its description opens the workflow without the user typing `/forge`. Typing the command still behaves exactly as before.
- Repo layout: `skill/` becomes `skills/forge/`, and every folder under `skills/` is installed to `~/.claude/skills/<name>/` under its own name. Both installers iterate over that folder and generate one permission rule per skill, so adding a skill no longer requires touching them. READMEs updated accordingly, and the documented `settings.json` keys now match what the scripts actually write.

### Removed

- Automatic file archiving. Threshold checks on `log.md` and `plan.md`, the archiving proposal and the `plan_AAAAMM.md` / `log_AAAAMM.md` files are gone: no file is ever split anymore. The bounded read of `log.md` stays — it is what keeps resume cost flat.

### Fixed

- Unix installer: `cp -r "$ROOT/skill/" "$SKILL_DIR"` copied the source directory *into* the destination, yielding `~/.claude/skills/forge/skill/SKILL.md` instead of `~/.claude/skills/forge/SKILL.md`. It now copies the contents.
- Unix installer: permission rules realigned on the Windows installer, which is the reference. The legacy `Read/Edit/Write(/.claude/**)` grants — obsolete since the `.claude/` → `.forge/` migration — and `Write(/.forge/**)` are no longer added, and they are now purged from `settings.json` on reinstall for users who ran an earlier version.

## [0.8.0] — 2026-08-12

### Added

- README badges: latest release, licence, changelog format.
- `frappe` / `hammer` — runs the plan's tasks through subagents: partition by touched files, then per task implementation, mechanical verification and three adversarial reviewers in fresh contexts, capped at two retries before `[!] blocked`. A single cross-cutting review closes the run. One confirmation for the whole thing, and the test suite stays the judge.
- Animated demo in the README, generated by VHS from two versioned sources (`docs/demo.sh`, `docs/demo.tape`) so it can be regenerated at every release without a new take. `docs/README.md` documents the prerequisites.

### Changed

- The hardcoded version line in the README is replaced by the release badge, which updates on its own.
- The bilingual README is split into `README.md` (English) and `README.fr.md` (French), with a language selector under the title. The single file had grown past 640 lines, burying the demo and the install section under the translation.
- Demo: the shipping command is shown as `engrave`, the English spelling, rather than `grave`.
- Demo: the opening now shows the resume sequence itself — branch detection, then the five ordered reads (`project.md`, `coding-standards.md`, `brief.md`, `log.md` bounded, `plan.md`) — before the progress table.

## [0.7.0] — 2026-08-12

### Added

- Root launchers `install-windows.bat` and `install-unix.sh`, delegating to the existing installers.
- `.gitattributes` — line endings pinned: `*.sh` in LF, `*.bat` and `*.ps1` in CRLF.
- `CHANGELOG.md`, in Keep a Changelog format.
- `LICENSE` — MIT. The repository had no licence until now, which left it under full copyright: public, but legally unusable.
- Automatic migration of `coding_standards.md` to `coding-standards.md`, run on first invocation.

### Changed

- Archiving thresholds are checked once per session, on resume, instead of after every write — no proposal ever interrupts development anymore.
- Archiving of `plan.md` is restricted to the `## Tasks` section, keeping the 10 most recent completed tasks; `## Summary` and `## Risks` stay intact. Threshold lowered from 30 000 to 20 000 characters.
- `log.md` is read with an explicit bound and new entries are inserted at the top — file size no longer weighs on resume cost.
- File naming convention: kebab-case throughout, with an explicit platform suffix (`-windows` / `-unix`) for terminal launchers.

## [0.6.0] — 2026-08-05

### Added

- Shipping command `grave` / `engrave` — commits, pushes, then merges the starting branch into each branch listed, after a single confirmation on a visual recap of the planned git actions.
- "Tidy the forge" normalises the structural labels of the current branch through a background agent, never blocking.

### Changed

- Structural labels of generated files are frozen in English (`## Objective`, `## Scope & rules`, `## Tasks`, `**Effort:**`) — only the written content follows the user's language.
- Teacher mode writes `explanation-<topic>.md` through a background agent, without asking for confirmation and without interrupting the task in progress.
- `rapport.txt` renamed `report.txt`, written entirely in the user's language, labels included — the single exception to the English structural labels.
- Email replies are drafted in the language of the incoming message, never the user's when they differ.

### Fixed

- `grave` command: no git action runs before confirmation, and the starting branch is merged into every listed branch rather than chained from the previous one.

## [0.5.0] — 2026-07-30

### Added

- `log.md` — per-branch decision log, with State 3 migrating pre-existing dated entries through a background agent.

### Changed

- The brief is reduced to its objective and its immutable rules; one-off decisions now go to `log.md` and never to the brief.
- On resume, only the 10 most recent log entries are read.

### Fixed

- Archiving thresholds and file naming made consistent.

## [0.4.0] — 2026-07-24

### Added

- `coding-standards.md` — project-wide coding conventions, created alongside `project.md` and read by every phase that touches code.

### Fixed

- Installation scripts: path and permission corrections.

## [0.3.0] — 2026-07-19

### Added

- Teacher mode: technical explanations written to a dedicated file for later reference.
- Task closure: internal report generated once the initial problem is confirmed solved.
- Automatic archiving of files that grow past their threshold.
- Propagation of infrastructure choices to the global `CLAUDE.md`, on confirmation.
- Automatic migration of `.claude/` to `.forge/`, including the `.gitignore` block that keeps `.forge/` tracked in git.
- No-Claude-copyright rule and git commit format (150 characters maximum).

## [0.2.0] — 2026-05-27

### Added

- Out-of-scope request detection: requests outside the current plan are flagged, and the user decides whether to add them.
- Context saved for resuming and tracking work across sessions.

### Changed

- The brief is generated by the skill itself instead of a separate template, so it follows the user's language.

### Fixed

- Redundant validation removed.
- `git branch` permission corrected.

## [0.1.0] — 2026-05-04

### Added

- `forge` skill: an explicit state machine — project init, brief, plan, active — with one absolute rule, never a line of code without explicit validation.
- Per-branch persistent context, tracked in git and re-read on every invocation.
- `PreCompact` hook injecting the forge state (branch, objective, task statuses) into the compacted context summary.
- Idempotent Unix and Windows installers, with `settings.json` merge and no duplicate entries on reinstall.
- `main` / `master` guard: on a protected branch, forge asks for a ticket ID or a branch name before continuing.

[Unreleased]: https://github.com/jeanchristoph/claude_forge/compare/v0.13.5...HEAD
[0.13.5]: https://github.com/jeanchristoph/claude_forge/compare/v0.13.4...v0.13.5
[0.13.4]: https://github.com/jeanchristoph/claude_forge/compare/v0.13.3...v0.13.4
[0.13.3]: https://github.com/jeanchristoph/claude_forge/compare/v0.13.2...v0.13.3
[0.13.2]: https://github.com/jeanchristoph/claude_forge/compare/v0.13.1...v0.13.2
[0.13.1]: https://github.com/jeanchristoph/claude_forge/compare/v0.13.0...v0.13.1
[0.13.0]: https://github.com/jeanchristoph/claude_forge/compare/v0.12.6...v0.13.0
[0.12.6]: https://github.com/jeanchristoph/claude_forge/compare/v0.12.5...v0.12.6
[0.12.5]: https://github.com/jeanchristoph/claude_forge/compare/v0.12.4...v0.12.5
[0.12.4]: https://github.com/jeanchristoph/claude_forge/compare/v0.12.3...v0.12.4
[0.12.3]: https://github.com/jeanchristoph/claude_forge/compare/v0.12.2...v0.12.3
[0.12.2]: https://github.com/jeanchristoph/claude_forge/compare/v0.12.0...v0.12.2
[0.12.0]: https://github.com/jeanchristoph/claude_forge/compare/v0.11.0...v0.12.0
[0.11.0]: https://github.com/jeanchristoph/claude_forge/compare/v0.10.2...v0.11.0
[0.10.2]: https://github.com/jeanchristoph/claude_forge/compare/v0.10.1...v0.10.2
[0.10.1]: https://github.com/jeanchristoph/claude_forge/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/jeanchristoph/claude_forge/compare/v0.9.4...v0.10.0
[0.9.4]: https://github.com/jeanchristoph/claude_forge/compare/v0.9.3...v0.9.4
[0.9.3]: https://github.com/jeanchristoph/claude_forge/compare/v0.9.2...v0.9.3
[0.9.2]: https://github.com/jeanchristoph/claude_forge/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/jeanchristoph/claude_forge/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/jeanchristoph/claude_forge/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/jeanchristoph/claude_forge/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/jeanchristoph/claude_forge/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/jeanchristoph/claude_forge/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/jeanchristoph/claude_forge/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/jeanchristoph/claude_forge/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/jeanchristoph/claude_forge/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/jeanchristoph/claude_forge/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/jeanchristoph/claude_forge/releases/tag/v0.1.0
