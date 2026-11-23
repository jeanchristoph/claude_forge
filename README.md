# Claude_forge

[![English](https://img.shields.io/badge/lang-English-1f6feb?style=for-the-badge)](README.md)
[![Français](https://img.shields.io/badge/lang-Fran%C3%A7ais-6e7681?style=for-the-badge)](README.fr.md)

[![Release](https://img.shields.io/github/v/release/jeanchristoph/claude_forge?sort=semver)](https://github.com/jeanchristoph/claude_forge/releases)
[![License](https://img.shields.io/github/license/jeanchristoph/claude_forge)](LICENSE)
[![Changelog](https://img.shields.io/badge/changelog-keep%20a%20changelog-orange)](CHANGELOG.md)


**Claude_forge** is a Claude Code system made of the **forge** skill (invoked via `/forge`), its `forge-clickup` companion and a `PreCompact` hook. Together they orchestrate the whole life of a development branch — from the validated brief to the delivered release — across one or several repositories.

![Forge in action](docs/demo.gif)

<sub>Reconstructed session — the output is reproduced verbatim from the skill. Regenerate with `vhs docs/demo.tape`, see [docs/README.md](docs/README.md).</sub>


Where Claude Code jumps straight into code as soon as you describe a problem, the forge skill inserts three mandatory steps before a single line is written:

1. **Brief** — clarify the goal and the frame: rules, constraints, scope
2. **Plan** — break down into estimated tasks, wait for explicit validation
3. **Active** — execute with real-time progress tracking

Once active, forge does not stop at the code: it delegates tasks to sealed subagents — a linked project or a branch of the same repository — with every question relayed to you, engraves the branch (commit, push, merges, relayed shipping, release) in a single command, and closes it with a report posted to ClickUp and a client reply.

The result: fewer surprises, implementations that stay within the defined scope, and a per-branch history that survives context compaction. It also makes working as a team of several developers much easier: each one works on their own branch, and taking over a branch started by someone else means inheriting everything needed to carry the development on — the actions already done, the context and the documentation — since everything forge generates (brief, plan, log, deliverables) lives with the branch and travels with it in git.

### What Claude_forge brings concretely

- **Zero code without validation** — the absolute rule: silence ≠ agreement. The skill waits for an explicit go-ahead before writing anything, asked as a choice and never as free text.
- **Persistent per-branch context** — `brief.md` and `plan.md` are stored in `.forge/branch/<BRANCH>/`, tracked in git, and re-read on every `/forge`.
- **Built for teams** — developers work on different branches, yet any of them can pick up a branch started by another one with the actions already done, the context and the documentation needed to continue: brief, plan, log and generated deliverables are shared through git, with no separate hand-over to write.
- **Generated content stays with the branch** — any doc, SQL script, export, explanation or client deliverable you ask for is written to `.forge/branch/<BRANCH>/output/`, never at the project root, named `YYYYMMDD-` plus a lowercase kebab-case English label, with no exception: `20260910-db-migration.sql`. Forge's own files — `brief.md`, `plan.md`, `log.md` — stay one level up, untouched.
- **Living brief & log** — rules, constraints and scope go silently into the brief's `## Scope & rules` section; decisions and user choices are logged silently into `log.md`, without interrupting the workflow.
- **Last session summary** — on resume, if `log.md` has entries, a one-line recap of the last 10 is displayed before the progress table.
- **L/XL task decomposition** — large tasks are broken into micro-steps in `plan.md` before implementation starts.
- **Deployment steps in the plan** — anything to run by hand outside the git deployment — an SQL migration, a configuration setting, an operating procedure — is listed in the `## Deployment` section of `plan.md` with its timing, the tasks it comes from and its copy under `output/`, filled in as soon as the script is written.
- **Generated SQL deployment script** — every SQL step of `## Deployment` is listed, with no question asked, in a single `output/YYYYMMDD-deployment-script.sql` per branch, rewritten in place, to run in order: one `-- STEP` section per step — the path of the script to run with its timing, check and rollback, or a short standalone query written in full with its check query — never the content of a script copied in.
- **Out-of-scope detection** — a request outside the current plan becomes a plan task: forge writes it up and you validate the wording, nothing more.
- **Branch, goal or ClickUp code as argument** — `/forge <branch-name>` checks out that branch, creating it from the up-to-date default branch (`master`, else `main`) if it does not exist — never from the current branch. A goal in words skips the goal question; with `.forge/clickup.json`, a task code (`PRJ-1133` or raw id) opens the existing task.
- **Question instead of a goal** — on any branch, a question about the project that calls for no action ("where does the user set X?"), given as argument or in answer to the goal question, gets a read-only answer: no branch, no brief, nothing written.
- **main/master guard** — without a branch as argument, on protected branches, forge offers to resume a branch with open tasks, asks the goal, then creates a branch named after it — after `project.md` and `coding-standards.md`, which are shared by every branch. `/forge master` works directly on `master`.
- **Shipping shortcut** — `"grave master"` / `"engrave master"` (or with `"dev"`) commit, push, and merge straight away: the command is the go-ahead, no confirmation asked.
- **Compaction survival** — the `PreCompact` hook injects the forge state (branch, goal, task statuses) into the compacted context summary.
- **Cross-platform** — automatic Unix/Windows detection, separate installers.

---

## Installation

**Windows:**
```
install-windows.bat
```

**Unix (bash):**
```bash
./install-unix.sh
```

Both launchers sit at the repository root and delegate to `install/install.ps1` / `install/install.sh` — call those directly if you prefer.

Scripts are idempotent — re-running after an update overwrites cleanly without duplicates.

The skill scripts need bash 5 (Git Bash on Windows, a recent bash from Homebrew on macOS, whose `/bin/bash` is 3.2). With an older bash, the time measurement hook and task marks write nothing and `log-entry.sh` stops with an error: no time is ever recorded wrong.

The release archives ("Source code" zip / tar.gz on the [releases page](https://github.com/jeanchristoph/claude_forge/releases)) carry only what the installers need: `.forge/`, `docs/` and the `.git*` files are left out.

The installers write `~/.claude/skills/forge/install.json` (installed version, repository URL, last update check), read by the skill update below.

The `/forge-clickup` extension additionally requires the ClickUp MCP connector to be authenticated (`/mcp` in Claude Code). No script can do this step for you: it is a browser OAuth flow.

---

## Usage

```
/forge                  # works on the current branch (main/master guard applies)
/forge help             # help: cycle, natural-language commands, .forge/ files
/forge <branch-name>    # checks out <branch-name>, creating it from master/main if missing
/forge <goal in words>  # takes the text as the goal, no goal question asked
/forge <clickup-code>   # with .forge/clickup.json: reads the existing task (PRJ-1133 or raw id), then hands over to forge-clickup
/forge-clickup          # extension: asks the goal, opens the ClickUp task (title and description derived from it), creates the branch, hands over to forge
/forge-clickup <goal>   # same, with the goal given as text
/forge-clickup <code>   # reads the existing task (PRJ-1133 or raw id), creates or resumes its branch, hands over to forge
```

---

## Repo structure

```
forge/
├── skills/                   → each subfolder is copied to ~/.claude/skills/<name>/
│   ├── forge/
│   │   ├── SKILL.md
│   │   ├── commands/          (commands loaded on demand)
│   │   │   ├── branch-rename.md       (branch rename)
│   │   │   ├── closure.md             (task closure)
│   │   │   ├── delegated-mode.md      (delegated mode rules)
│   │   │   ├── delegation.md          (linked project, same-repo branch)
│   │   │   ├── deployment-sql.md      (SQL deployment script)
│   │   │   ├── email.md               (drafted email)
│   │   │   ├── engrave.md             (shipping, metrics.json summary)
│   │   │   ├── help.md                (help, /forge help)
│   │   │   ├── rule-propagation.md    (rule propagation to CLAUDE.md)
│   │   │   ├── swarm.md               (swarm of child branches: launch, relay, merge, resume)
│   │   │   ├── teacher.md             (teacher mode)
│   │   │   └── update.md              (skill update: manual check)
│   │   ├── phases/
│   │   │   ├── p0-project.md          (State 0 — Project Init)
│   │   │   ├── p1-coding-standards.md (State 1 — Coding Standards Init)
│   │   │   ├── p2-brief.md            (State 2 — Brief)
│   │   │   ├── p4-plan.md             (State 4 — Plan)
│   │   │   └── p5-resume.md           (State 5 — Active)
│   │   ├── references/
│   │   │   └── estimation.json        (minutes per file until a project has its own measures, estimate range, fixed costs of a branch, branch threshold)
│   │   ├── hooks/                (declared in settings.json by both installers, copied with the skill)
│   │   │   ├── forge-precompact.sh   (state hook: PreCompact, SessionStart after compaction or resume)
│   │   │   ├── linked-write-guard.sh  (write guard, PreToolUse: the parent session never writes into a linked project, except the mandate's brief.md and log.md)
│   │   │   ├── time-hook.sh           (time measurement hook: one line per event in the branch time-log.jsonl)
│   │   │   └── plan-hook.sh           (tick hook: task marks, actual time, estimates and summary table of plan.md)
│   │   └── scripts/              (called by the model and by the hooks)
│   │       ├── checks.sh              (startup checks, run detached, and again at engrave: input/ and time-log.jsonl lines in .gitignore)
│   │       ├── engrave.sh             (shipping sequence: preview / run; run --model writes metrics.json first)
│   │       ├── metrics.sh             (branch measure summary: writes metrics.json and the plan's **Actual:** line, reports the estimated vs actual line as JSON)
│   │       ├── json.sh                (JSON rendering and hook JSON field reading, shared by the scripts)
│   │       ├── linked-worktree-cleanup.sh (removes a linked worktree once its branch is merged, clean tree only, as JSON)
│   │       ├── log-entry.sh           (log entry: timestamp read from the local clock, entry written at the top of log.md)
│   │       ├── status.sh              (startup status: state, progress, resumable branches, as JSON)
│   │       ├── swarm-status.sh        (swarm status: running, launchable, waiting branches, simulated merge, as JSON)
│   │       ├── time-aggregate.sh      (one branch's measure: agent, human and check minutes, files and lines, as JSON)
│   │       ├── time-calibrate.sh      (project ratios from metrics.json, estimate for a number of files, as JSON)
│   │       ├── time-mark.sh           (delegate, token and merge marks in the time-log.jsonl)
│   │       ├── task-marks.sh          (shared bash: clock, folder fingerprint, task mark line)
│   │       ├── task-files.sh          (shared awk: task status, planned files of a task, files changed between two fingerprints)
│   │       └── update.sh              (skill update: check / run, as JSON)
│   └── forge-clickup/        → extension: ClickUp task kickoff
│       └── SKILL.md
├── install/
│   ├── install.sh
│   └── install.ps1
├── install-unix.sh           → root launcher, delegates to install/install.sh
├── install-windows.bat       → root launcher, delegates to install/install.ps1
├── CHANGELOG.md              (Keep a Changelog format, one section per version)
├── README.fr.md              (French version)
├── LICENSE                   (MIT)
├── docs/
│   ├── demo.gif              → README demo, generated by vhs
│   ├── demo.sh
│   ├── demo.tape
│   └── README.md             (how to regenerate)
├── tests/
│   ├── engrave.test.sh       → bash tests/engrave.test.sh, throwaway repositories only
│   ├── forge-precompact.test.sh → bash tests/forge-precompact.test.sh, throwaway repositories only
│   ├── install.test.sh       → bash tests/install.test.sh, throwaway home only
│   ├── checks.test.sh        → bash tests/checks.test.sh, throwaway repositories only
│   ├── linked-worktree-cleanup.test.sh → bash tests/linked-worktree-cleanup.test.sh, throwaway repositories only
│   ├── linked-write-guard.test.sh → bash tests/linked-write-guard.test.sh, throwaway folders only
│   ├── log-entry.test.sh     → bash tests/log-entry.test.sh, throwaway folders only
│   ├── status.test.sh        → bash tests/status.test.sh, throwaway repositories only
│   ├── swarm-status.test.sh  → bash tests/swarm-status.test.sh, throwaway repositories only
│   ├── time-aggregate.test.sh → bash tests/time-aggregate.test.sh, throwaway repositories only
│   ├── time-calibrate.test.sh → bash tests/time-calibrate.test.sh, throwaway folders only
│   ├── time-hook.test.sh     → bash tests/time-hook.test.sh, throwaway repositories only
│   ├── time-mark.test.sh     → bash tests/time-mark.test.sh, throwaway folders only
│   ├── metrics.test.sh       → bash tests/metrics.test.sh, throwaway repositories only
│   ├── plan-hook.test.sh     → bash tests/plan-hook.test.sh, throwaway repositories only
│   └── update.test.sh        → bash tests/update.test.sh, throwaway repositories only
├── .gitattributes
└── .gitignore
```

Files generated in each project:

```
.forge/                  ← tracked in git, added automatically on first run
├── project.md
├── coding-standards.md  ← coding conventions (structure, naming, principles), completed over time
├── clickup.json         ← written by `/forge-clickup`: target list, base branch, branch code
├── input/               ← reference files (exports, SQL dumps, database structures), one subfolder per source
└── branch/<BRANCH>/
    ├── brief.md         ← `## Objective` + `## Scope & rules`
    ├── log.md           ← Decisions log (living log, last 10 entries read on resume)
    ├── plan.md
    ├── metrics.json     ← branch measure, rewritten at each engrave and at closure: planned/actual files, lines, agent and human minutes, tokens
    ├── time-log.jsonl   ← raw events of the time measurement hook, local, not tracked in git
    ├── swarm.md         ← swarm state of a parent branch: N, child branches, choices sent, coordination notes
    ├── input/           ← files brought for this branch's task (CSV/XLSX exports, SQL dumps or extracts, data received as files), read instead of a database access, created empty with the brief, not tracked in git
    ├── ticket.json      ← written by `/forge-clickup`: tracker, code, url; link shown on resume and at closure
    └── output/          ← every generated file, named `YYYYMMDD-`
        ├── 20260910-explanation-*.md ← written in the background when a technical concept is explained
        ├── 20260910-db-migration.sql ← docs, SQL scripts, exports, notes
        └── 20260910-user-documentation-map.md ← client deliverable, named like every other file
```

Keep `.forge/` tracked in git, except the branch `input/` folders and the hook's `time-log.jsonl` — the `.gitignore` block below does it; forge adds each missing line on its own, from a startup check run in the background, and checks again at every engrave before committing: a missing rule is added and the `.gitignore` ships with the commit, a journal or `input/` file already tracked is removed from the index (`git rm --cached`, kept on disk). Files already pushed stay in the history, never rewritten:

```
###> claude/forge ###
!/.forge/
/.forge/branch/*/input/
/.forge/branch/**/time-log.jsonl
###< claude/forge ###
```

---

## State behaviour

### State 0 — Project Init
**Condition:** `.forge/project.md` absent

- Empty project (excluding dotfiles/dotfolders) → `project.md` placeholder created, continues.
- Otherwise → explores stack, structure, conventions, writes `project.md` with no question, then continues; "clean the forge" adjusts it later.
- `coding-standards.md` is written at the same time (only if it doesn't already exist) — see below.

### State 1 — Coding Standards Init
**Condition:** `.forge/coding-standards.md` absent

Writes `coding-standards.md` in the user's language, then continues to brief.

### State 2 — Brief
**Condition:** brief absent

Reads `coding-standards.md`. Creates `.forge/branch/<BRANCH>/brief.md` with an `## Objective` section and an empty `## Scope & rules` section, clarifies the goal, continues to plan.

### State 4 — Plan
**Condition:** brief present, plan absent

Reads `coding-standards.md`, generates `plan.md`, waits for validation before any implementation. The validation offers three options: validate and chain — the plan is written and every open task runs in order, with no further question —, validate — the execution mode is asked next —, or cancel.  
L/XL tasks include a commented decomposition block (`T1.1`, `T1.2`, …) to fill in before starting.

### State 5 — Active
**Condition:** brief + plan present

Reads the brief and the plan silently; `project.md` and `coding-standards.md` are read only when the first task of the turn starts, or a direct code change — a resume to ship, review or close does not load them. If `log.md` has entries, displays a one-line "**Last session:**" recap of the last 10 first, then the progress table — `## Summary` of the plan, as the hook keeps it. Then offers the two modes — chaining the open tasks or picking one yourself — and waits. No open task: no mode is offered, the question is left open.

---

## coding-standards.md

Created alongside `project.md` (State 0), in the user's language: a title (project name) and a short explanation stating that the file holds the coding conventions (structure, naming, principles) to apply while writing code — an ongoing standard, not a one-off audit — meant to be filled in as the project evolves.

It's read at every phase that touches code — Bootstrap, Plan, and in State Active when the first task of the turn starts — so conventions stay applied throughout the workflow.

---

## Branch detection

Via `scripts/status.sh`, which reads the current git branch and, for `/forge <argument>`, also checks that the target branch exists (`--target`) — works on both Unix and Windows.  
Error or empty result (no git repo): asks for a code name used as `<BRANCH>`. No answer → STOP.

---

## Confirmations

Every blocking confirmation and every closed choice is asked as a selectable question, never as free
text: execution mode, architectural approach, plan validation, substantial plan updates, out-of-scope
requests, `CLAUDE.md` rule propagation, shipping, linked-project shipping, closure, ClickUp posting, client reply.
Refusal is always an explicit option, and no answer means STOP — never consent. The question, its
options and their descriptions are written in your language — the English labels quoted in this
document are the skill's internal references, not what you see on screen.

Open questions stay free text, where a fixed list would only get in the way: the goal of the task, a
branch code name, the email to paste, what to do next.

Validating a piece of content — the brief's objective, the plan, the closing report — never offers a
"rework" or "edit" option: a change request goes through the question's
free-text field, with its explanation, and the content comes back reworked under the same question. A
bare "no" is not a change request — forge asks in one line what should change, and never shows the same
content again unchanged.

---

## Safety guard — main / master

Without a branch as argument, on `main` or `master`, forge first offers to resume any local branch with open tasks. It then asks the goal, unless it was given as an argument, and creates a branch named after it, with no question: short kebab-case name, suffixed `-2`, `-3`… if it already exists. Ask to rename the branch at any time: forge runs `git branch -m` and moves `.forge/branch/<name>/`. To work directly on `master`, run `/forge master`.

The guard runs before State 2 — Brief, never before States 0 and 1: `project.md` and `coding-standards.md` are shared by every branch and never resolve `<BRANCH>`. In a fresh project, forge learns what the project is before asking which branch to work under.

With a branch as argument (`/forge <branch-name>`) the guard does not apply: forge is already positioned on `<branch-name>`.

---

## Keys added to settings.json

**Unix (`install.sh`):**
```json
{
  "permissions": {
    "allow": [
      "Read(~/.claude/skills/forge/**)",
      "Read(~/.claude/skills/forge-clickup/**)",
      "Read(/.forge/**)", "Edit(/.forge/**)",
      "Bash(bash \"/home/{USER}/.claude/skills/forge/scripts/*)",
      "Bash(bash /home/{USER}/.claude/skills/forge/scripts/*)"
    ]
  },
  "hooks": {
    "PreCompact": [{
      "hooks": [{ "type": "command", "command": "bash ~/.claude/skills/forge/hooks/forge-precompact.sh", "shell": "bash" }]
    }],
    "SessionStart": [{
      "matcher": "compact|resume",
      "hooks": [{ "type": "command", "command": "bash ~/.claude/skills/forge/hooks/forge-precompact.sh", "shell": "bash" }]
    }]
  }
}
```

**Windows (`install.ps1`):** same hooks, run by Git Bash; read rules as POSIX paths, script rules as Windows paths with forward slashes.
```json
{
  "permissions": {
    "allow": [
      "Read(//c/Users/{USER}/.claude/skills/forge/**)",
      "Read(//c/Users/{USER}/.claude/skills/forge-clickup/**)",
      "Read(/.forge/**)", "Edit(/.forge/**)",
      "Bash(bash \"C:/Users/{USER}/.claude/skills/forge/scripts/*)",
      "Bash(bash C:/Users/{USER}/.claude/skills/forge/scripts/*)"
    ]
  }
}
```

The six time measurement hooks are added as well (see "Time measurement and estimate" below). Each install first removes the forge rules and hooks already present, abandoned forms included (`Bash(bash -c "git branch --show-current*)`, former PowerShell hook): never a duplicate.

**Script permissions:** the skill calls its scripts in a single form, `bash "<skill folder>/scripts/<script>.sh" …`, covered by the two `Bash(…)` rules above and, for the turn that invokes `/forge`, by the `allowed-tools` of `SKILL.md`. Outside auto mode, no permission prompt ever interrupts a LOG entry, a task mark or an estimate.

---

## State hook — PreCompact and SessionStart

Injects the forge state — brief objective, plan, last three LOG entries — before each context compaction (`PreCompact`), then again after a compaction or when a session is resumed (`SessionStart`, `compact|resume`). The hook reads the project folder from Claude Code's JSON input; outside a git repository or without a plan, it writes nothing.

A single hook, in bash, for both platforms: Git Bash is already required on Windows by the skill's scripts. The Windows installer replaces the former `forge-precompact.ps1`, file and `settings.json` entry included.

---

## Time measurement and estimate

Both installers also add `bash ~/.claude/skills/forge/hooks/time-hook.sh` (shell `bash`, Git Bash on Windows, `async`: Claude Code never waits for it) to six events: `UserPromptSubmit`, `Stop`, `SubagentStart`, `SubagentStop`, `PreToolUse` on `AskUserQuestion`, `PostToolUse` on `AskUserQuestion|Bash`. Outside a forge project (no `.forge` folder in the session folder or its parents), it exits at once, without any git process. They also add `bash ~/.claude/skills/forge/hooks/plan-hook.sh` on `PostToolUse` for `Edit|Write|MultiEdit`, synchronous: it acts only on a `.forge/branch/<branch>/plan.md` and exits at once for any other file. Hooks declared in a skill's frontmatter are not used: they miss subagents and are lost when a session is resumed.

- **Measure:** the hook adds one line per event to `.forge/branch/<branch>/time-log.jsonl` of the branch checked out in the session folder — timestamps, ids, durations, never a prompt, command or tool output. Outside a forged project it writes nothing. A delegate's events carry the parent's folder: the parent maps each delegate to its child branch.
- **Summary:** at each engrave (`engrave.sh run --model <id>`, before `git add`) and at closure, `metrics.sh` — never the model — has `time-aggregate.sh` sum the log and git and writes `metrics.json`: agent minutes (main session + delegates, ordinary subagents included: any agent started by the session and not delegated to another branch counts for its duration, parallel agents added up), human minutes (a wait of more than 60 min before a prompt or an answer counts 3 min, placed just before it; more than 6 h counts zero), a `partial` flag when the log misses the start of the branch (hook installed late: such a branch is left out of calibration), questions, check minutes, tokens of delegates, files and lines changed.
- **Files per task:** each task mark carries a fingerprint of the working folder (path and content hash of every changed or new file, outside `.forge`, nothing written to the repository); a task's actual files are those that appear, change or disappear between its two marks — a file changed by three tasks counts in each — written as `**Actual time:** ≈ <min> min agent … · <n> files …`. From twenty such tasks, minutes per file and the file forecast correction come from the last forty tasks rather than from whole branches, both sides counted per task.
- **Estimate:** each plan task counts the paths listed in its `**Files:**` (an explicit `(≈ n)` at the end of the line for a glob or files still unknown); one `time-calibrate.sh --files 3,5,8` call turns every task and the total into agent minutes with a range (`≈ 120 files · ≈ 60 min (45-78)`), from the project's last forty measured tasks once twenty are measured with their files, otherwise from `references/estimation.json` (0.5 min per file) — never from whole branches. The range comes from the 20th and 80th percentiles of actual ÷ estimated time over the last forty measured tasks, read from the branch plans (child branches of a swarm included), once twenty are measured (0.75–1.3 before); every estimate is recomputed from the latest measures. Marked *indicative* while rates or range still come from the reference values. Effort letters stay as relative size, without any duration.
- **Written by the hook:** on every write of `plan.md`, `plan-hook.sh` estimates each task that has `**Files:**` but no `**Estimated time:**` (one `time-calibrate.sh` call), recomputes the `**Estimate:**` header (files of every task, sum of their frozen estimates), and rebuilds `## Summary` from the tasks: `Task | Effort | Files | Estimated | Actual | Status`, short titles kept, `**Total**` over the measured tasks only — estimated and actual of the same tasks —, and `**Remaining**` for the open tasks. A measured actual time is never replaced by `—`. On resume, this table is the progress table, shown as is, with no script call.
- **Check cost per task:** every task pays its checks whatever its size — under Git Bash a full test run can cost several minutes for a one-file change. A task's estimate is `check_minutes + files × minutes per file`: `check_minutes` is the median of the `· <c> min checks` part of the actual times once twenty tasks carry it, `2` from `references/estimation.json` before; minutes per file are then taken from the actual time minus its checks. A list of tasks gets one check cost per task. Actual times written before this part existed are still read.
- **Unplanned time:** `metrics.sh` also writes an `**Unplanned**` row under `**Total**` — the branch's agent time minus the measured tasks (work never planned, conflicts, engraving, a task in progress or unmeasured), never negative, `—` without a measure. A successful engrave moves the measure checkpoint after its commit, so engraving and the full suite no longer enter the next task; a task in progress (code changed since the last tick) keeps its start time.
- **Linked task estimate:** marked `· indicative` until its delegate has a plan; the hook then takes that plan's planned files (`**Estimated files:**`) at the next write of the parent plan and re-estimates once, frozen.
- **Whole branch:** under `**Estimate:**` (else under `**Date:**`), `metrics.sh` writes the branch measure from `time-aggregate.sh` at engrave time — before the `git add`, so the line ships with the commit — and at closure, not on every write of the plan; between two engraves the line keeps the last value. Same shape as the task line, total last: `**Actual:** ≈ 14.0 min agent (incl. 3.0 min checks) · human 7.0 min (4 questions, 2.5 min) · fixed 2.0 min (delegate setup, merge) · delegates 0.0 min in parallel · total ≈ 21.0 min`. Total = agent + human: checks and merge are shares of agent time, delegate setup a share of delegate time; delegates run at the same time and are shown apart, outside the total. An item without a measure shows `—`, never an estimate; ` · partial (log started after the branch, 3 unmeasured tasks)` flags an incomplete measure. No measure log → no line. With no measured task, the `**Total**` row points to it (`see **Actual:**`).
- **Per task:** each task also states `**Estimated time:**`, frozen when the hook first writes it. The model sets no mark: `plan-hook.sh` sees the tick in `plan.md`, writes the task's start (last checkpoint: previous tick or first write of the plan, a `plan_checkpoint` line of the log) and its end, measures the agent minutes between both with `time-aggregate.sh --task` (question waits removed, same absence rule) and writes `**Actual time:**` broken down by item (`≈ 10.2 min agent (incl. 2.3 min checks) · human 1.5 min (2 questions) · 9 files · total ≈ 11.7 min`: the first figure is agent time, checks included, compared with the estimate; total = agent + human, checks never added), or `—` when there is no measure (no log, hook installed late, first pass). A task picked out of order is measured from the previous tick; two tasks ticked in one edit are simultaneous. For every delegate, same repository or linked project, the hook writes the marks to the parent's log (`TIME_LOG:` line of its prompt), where its events already land; the delegate and reports each task's actual time in `FORGE_DONE`; the same hook ties each delegate to its branch and linked project (`delegate` line, first write of its `plan.md`), so two repositories on one branch name never mix; a parent task delegated to a linked project gets, at its tick, the time of that project's delegates only (its child tasks when several parent tasks share the branch), human time `—`, and `—` without a measure — never the parent session's time; a swarm branch task takes `agent_minutes` from the merged branch `metrics.json`, also written by the hook. The progress table shows Estimated and Actual side by side. An ordinary subagent counts in the task for its share inside the window; two tasks open at the same time are not measured (`—`, reason `overlapping_tasks`): no share can be attributed to either without inventing it, and their time still counts in the branch measure.
- **Check commands:** the `**Check pattern:**` line of `project.md` (regular expression) marks the Bash commands counted as checks.
- **Tests:** after each task, only the tests covering the files it changed (same-named test, then tests of the files calling them); the full suite runs once, before engraving — `**Full check:**` line of `project.md`, asked once when missing — unless a CI pipeline already runs the tests on every push (value `ci`, detected: nothing runs locally, the report says `Full check: left to CI` and warns when `master` / `main` was pushed before the CI result) — and a red suite stops the engrave before any git command. In a linked project the delegate runs it once, after its last task (see « Delegating to a linked project »).

---

## Plan updates

**Silent** (automatic): check `[x]`, short note, `[!]` if blocked.  
**Substantial** (confirmation required): add/remove task, order, effort, description.

---

## Brief updates

The brief is a living document. Changes of scope go through **Out-of-scope detection** (see below).

**Frame element** (holds for as long as the branch exists) → written silently into the brief's `## Scope & rules` section:
- Technical constraint discovered mid-task
- Standing rule set by the user
- User remark durably narrowing the scope

**One-off decision** (settled and closed at a point in time) → written silently into `log.md` (`- [YYYY-MM-DD HH:MM] [1 line]`, written by `log-entry.sh` from the local clock — the model never writes a date or time):
- Minor implementation choice made without discussion
- User's choice when Claude presented several options (e.g. "Option B chosen — reason")

---

## Rule propagation to CLAUDE.md

When you ask for a correction of syntax, structure or code convention (naming, format, organisation) on content Claude produced, forge applies it, logs it, then drafts a general rule in the form `When [case] → [behaviour]`, so that Claude acts that way from the start next time. The same applies to infrastructure choices and to choices of Claude's that you overturn. A functional bug or a change of need triggers nothing.

The rule is shown in full, then forge asks where it goes: the global `~/.claude/CLAUDE.md`, the `CLAUDE.md` at the project root (created if absent), or nowhere. **No `CLAUDE.md` is ever written without your answer.** Nothing is proposed for a one-off case or one already covered by either file, and a rule kept local is never proposed again. A delegated run proposes nothing.

---

## Out-of-scope detection

After each user input, forge checks whether the request falls inside the current plan or not.

A **direct action** never becomes a task: a precise order — what, where — that fits in one command or one local edit and calls for no design decision (delete or rename a file, fix a wording, add a word, run a command) is carried out at once, the order itself being the confirmation, and logged in one line when the repository changes. The same goes for any request whose result is generated content — documentation, an export, a SQL script, a checking workbook, an analysis, a client deliverable — whatever its size: it is produced in `output/` and logged, never planned, because the plan only tracks the tasks that implement the brief's objective. When in doubt — direct action or extra request, deliverable or feature — forge treats the request as a direct action: one action too many costs nothing, one question too many costs a round-trip.

A **check request** — run tests, verify a behaviour, reproduce a case — comes first. A quick check (one command or one read, no test to write, no multi-step scenario) is a direct action, with no question. Anything heavier, or when in doubt, forge writes up the check as a plan task and asks one question: add it to the plan and run it, run the check without a task (logged in one line), or cancel.

**Detected when the request:**
- Concerns a feature not in the plan
- Introduces a new use case, module, or behaviour
- Changes an implicitly accepted technical or functional constraint

**Reaction:** a new request is always a new plan task — forge never asks whether to add it or handle it off-plan.
1. Flag it: `"This request isn't in the current plan."`, then write the task up as it would enter the plan — title, effort, files, description — together with the `## Scope & rules` entry it implies, if the scope changes durably.
2. Ask one question only, with the options of a new plan's validation: validate and chain, validate, or cancel. The task is copied as plain text at the top of the question itself, on a fixed template — title, effort, and the full description as bullets, numbered when order matters; files and scope entry stay in the reply — so it stays on screen even when the text above the dialog is hidden. A change to the wording goes through the free-text field, as for any content validation.
3. Validated → the task enters the plan (and the brief, if its scope changed). Validate and chain runs it at once, along with the other open tasks, with no further question; validate only writes it, then asks how to run the tasks, as for a new plan. Cancelled → nothing enters the plan and the request is not handled.

---

## Teacher mode

```
"what is X" / "explain Y" / "I don't understand Z"
```

A question about a technical concept — not a scope or decision question — switches forge to teaching: a clear explanation, with a concrete example taken from the project when it helps. A background agent writes it down in `output/YYYYMMDD-explanation-<topic>.md`, adding a dated section if the topic already has a file, while the current task resumes right away. One line reports the file once written; no confirmation is asked. On `main` or `master`, nothing is written: the explanation stays in the answer.

---

## Updating project.md

```
"ranger la forge" / "clean the forge"
```

Updates `project.md` — only what changed, after validation.

---

## Updating the skill

```
"mettre à jour la forge" / "update the forge"
```

At most once every 24 hours, `/forge` asks the repository for its latest `vX.Y.Z` tag in the background, without waiting: startup costs a few milliseconds, offline stays silent. A newer version found this way is announced at the next `/forge`, at the end of the status line, with no question: work starts straight away.

The phrase above checks right away, whatever the delay, and offers the install: on `Update now`, forge clones the tag in a temporary folder, runs the platform installer and asks you to relaunch `/forge`; `Later` skips that version, which is no longer announced at startup — only a newer one is. It also says when you are up to date or when the repository is unreachable.

An install without `install.json` (older than this feature, or from an archive outside git) is checked at once and offered the latest version. Delegated runs never check.

---

## Delegating to a linked project

```
"do T3 and T5 in ../other-project"    → those tasks only
"do this in ../other-project"         → forge asks which open tasks to delegate
```

A request that targets a folder outside the current project opens a **linked project**. A repository not yet
forged (`.forge/project.md` missing from its default branch) is forged without a question by the delegate, in the
linked branch's worktree: `project.md` and `coding-standards.md` ship with that branch and reach the default branch
when it is merged; one delegation at a time to the same unforged repository. It needs a real branch on the parent
side: a code name used outside git cannot delegate.

The parent prepares the ground, and nothing else: it opens a **linked branch** of the linked repository in a
git worktree, named with the same rule as a regular forge branch — a short kebab-case slug of the delegated task
(or of the common subject of the delegated tasks), `-2`, `-3` on collision in the linked repository — created
from its up-to-date `master`/`main` when missing. The link lives in the parent plan only: a task aimed at a linked
project carries `**Linked branch:** <path relative to the parent root> @ <branch>` (e.g. `../my-api @ export-csv`)
from the moment it enters the plan, shown in the `Plan` question; tasks sharing that field share the branch and
its worktree. The parent then writes the linked brief — an `## Origin` block holding the **mandate** only (the
delegated tasks copied in full), and an objective written from those tasks — and opens the linked `log.md`
(`Opened by delegation · T3, T5`). The parent's own plan is annotated (`delegated to ../my-api @ export-csv`)
and its log records the hand-over. A recap table lists these actions; nothing runs before you confirm once.

**The linked project never names the parent.** It may be public while the parent is private: no parent folder,
branch, ticket, client or data ends up in the linked branch — name, brief, plan, log, code, CHANGELOG, commits.
Tasks aimed at a linked project are written that way in the parent plan, since they are copied as is. The only
exception is a reference the task cannot be carried out without, kept to the strict minimum inside the task —
never the parent brief.

The worktree sits next to the linked repository, in `<linked-folder>.worktrees/<branch>` — e.g.
`my-api.worktrees/export-csv` — and is reused when it already exists. The linked repository's own folder is never touched — no checkout,
no write — so you can keep working in it by hand while the subagent runs. A worktree only holds versioned
files: no installed dependencies, no `.env`, no local config — a delegated task that needs them comes back
blocked, and the linked `.forge/` must be committed. The worktree is removed automatically once the linked
branch is merged into the linked project's default branch (`master`, then `main`, local or `origin/` after a
fetch): after a relayed engrave that merges it, or at the parent's closure for a merge done outside forge — a
pull request, for instance. `linked-worktree-cleanup.sh` decides alone and never forces: a worktree with
uncommitted changes, an unmerged branch (a squash merge included) or the linked repository's own folder is kept,
and the report says why. The linked branch itself is never deleted. A merge into one of the engrave's target
branches counts too (`--merged-into`: an engrave limited to `dev` removes the worktree once the branch is in `dev`),
and a kept worktree always gets a report line with its ready-to-copy removal command
(`worktree: kept — <reason> · remove: git -C "<linked>" worktree remove "<worktree>"`).

Execution then happens in a **sealed forge context**: a subagent that receives only the worktree path,
the linked branch, your language and the order to run the forge skill there. No `project.md`, no coding standards,
no plan, no log cross the wall in either direction. The linked plan is derived from the mandate alone —
every task carries its lineage (`T1 — … ← parent T3`), and a need outside the mandate is never turned into
a task: it is reported back. Once the plan is validated the subagent chains every task without asking
for an execution mode — validating the plan is the go-ahead. Every blocking question it meets (plan
validation, an approach to choose) is relayed to you verbatim as a `FORGE_QUESTION` and answered through the same
`AskUserQuestion` you know; the answer goes back to the subagent, whose context stays intact. A relayed
question carries the **full content** you are deciding on — the whole plan, the whole task description,
the brief entry — never a one-line summary: the parent shows it to you as is, then asks.

Once its last task is done, the delegate runs the linked project's full suite once (`**Full check:**` line of its
`project.md`, detected when missing; nothing runs for `ci` or when there is none). It fixes a failure its tasks
caused and reports any other without touching it: the result is kept in the parent task's note, and a failure is
shown again in the question asked before shipping the linked project.

The run ends with a single `FORGE_DONE` report: tasks done, tasks blocked with their reason, needs outside
the mandate, full suite result, files touched. The parent then — and only then — checks each delegated task `[x]` or marks it
`[!] blocked` with the reason, one log entry per task. Nothing is committed in the linked repository at that
point: shipping it is offered when you engrave the parent (see below).

---

## Delegating to a branch of the same repository

```
"run a forge agent on branch X"       → X opened in a sibling worktree, forge runs there
"open branch X in an agent"           → same thing
```

A request to run an agent — or a delegated forge — on a branch of the current repository opens that branch
in a **worktree**: an existing worktree for `X` is reused, otherwise forge creates `<repo-folder>.worktrees/X`
next to the repository — the branch becomes the path, e.g. `forge.worktrees/feature/x` (`git worktree add`). Two refusals, never worked around: `X` is the current branch ("already
on it"), or `X` does not exist — forge never creates a branch on your behalf. A recap table lists the
branch, the worktree path and the agent; nothing runs before you confirm once.

There is no mandate here: the parent writes nothing in the worktree, neither brief, nor log, nor plan, and
never reads its code. The subagent gets the worktree path, the branch, your language and `SCOPE: branch`,
and runs the forge skill there exactly as you would on that branch — project, brief, log and plan read as
the phases prescribe. The difference with a linked project is that **every choice is relayed to you**:
the brief objective, the plan validation, the execution mode, the go-ahead before each task. "A validated plan is the go-ahead" does not apply in this scope, unless you pick validate
and chain when validating the plan.

The run ends with a one-line `FORGE_DONE`: nothing is written into the parent plan or log, since nothing
was delegated. The worktree is left in place — forge reminds you of `git worktree remove <path>` for once
the branch is engraved.

---

## Swarm of child branches

```
plan with ≥ 1 branch task → "Validate and launch the swarm" → child branches run in parallel with the parent
plan with ≥ 1 linked branch    → "Validate and launch the swarm" → linked delegates run in parallel with the parent
```

The swarm is not limited to the current repository. Its delegates are **units** of two types, read by
`swarm-status.sh`: `child` (a branch task of this repository, merged into the parent by the parent) and `linked`
(the open tasks sharing one `**Linked branch:**`, in another repository, never merged by the parent and shipped by
the relayed engrave). Both share the N slots, the grouped relay, `swarm.md` (new `Type` column) and the resume.
As soon as the drafted plan holds one launchable unit — counted by the script on the draft (`--plan`), never by
the model — "Validate and launch the swarm" comes first and "Validate and chain" is labelled as in series; linked
tasks never go through the branch rule (they are delegated whatever their size) and never land in the parent's own
tasks. A finished linked delegate frees its slot and the next launchable unit starts without a question.

When at least one group of tasks deserves its own branch — tasks of one module or one feature slice, together
≥ 15 min of agent time, delivered and tested on their own without sharing files with another group — the plan
becomes a **plan of branches**: each such group is one `### Tn — Branch <parent>-<slug>` with a
`**Depends on:**` line, a shared-extension-points task comes first and an overall check task last. Under the
groups table, `time-calibrate.sh --groups` shows the gain: swarm time (each branch plus about 8 min of delegate
set-up, spread over N delegates, then about 5 min per merge, one after another) against serial time; with `--parent`, the
parent's ordinary tasks count as one more lane, so a single branch running alongside the parent's work can pay off;
dependencies are ignored, so it is an optimistic figure.

- **Visible choice:** `time-calibrate.sh` turns the threshold into files (`branch_files`, 30 with the reference
  values). Once the plan counts that many files, the groups table is always shown, with a `branch` or `task`
  verdict for each, even when no group is kept.
- **Additions and promotion:** tasks added during the branch that meet the rule are offered as a branch task, with
  "Validate and launch the swarm". A task whose real size shows up while exploring is offered as a branch
  (`Promotion`), before any file is written — in the parent as in a delegate.
- **Ordinary subagents:** reading only (exploration, search, review, checks). Never parallel writing in the same
  working tree: writing stays in the session, one task after another, or goes through the swarm.
- **Launch:** `swarm-status.sh` lists running, launchable and waiting branches and simulates the merge of the
  parent. Up to N (3 by default, changed only on request) launchable branches get a worktree, the parent merged in,
  a brief, their own dependency install and port, and a delegated forge each — all in the same turn. On resume,
  launchable branches are offered in a `Swarm` question (launch, work on parent tasks, later): reopening a session
  never launches delegates by itself.
- **Relay:** questions are prefixed with their branch, grouped in one dialog when several wait, sent back to the
  delegate when they lack decision context; coordination notes warn when two branches touch the same module.
- **End of a branch:** one question — merge and launch the next branch, merge, check before merging (the app runs
  from the worktree) or do nothing; a merge option commits the branch work, and the parent's task in progress first. The parent alone merges into the parent branch: fast-forward, or reverse merge
  with conflict rules, full check, then fast-forward; never a push, never a merge into the default branch.
- **Parent at work:** while delegates run, the parent chains the ordinary tasks it can take — `Mode` asked once for
  the whole swarm, kept in `swarm.md` — and hands back only when none is left. A delegate's notification arrives
  between two tool calls, even in the middle of a parent task: the parent ends the current action, relays at once,
  then resumes its task.
- **Limits:** worktrees live next to the repository, outside the session folder: allow that
  folder (`/add-dir ../<repository>.worktrees` or `additionalDirectories`) or background delegates stop on permission
  prompts. Ignored files (`.env`, local configuration) are not copied into a worktree and the development database
  stays shared between delegates: keep database checks for the final overall check. On Windows, deep
  `node_modules` trees may need `git config core.longpaths true`.
- **State:** `swarm.md` keeps N, branches with their delegate id and port, choices sent and coordination notes;
  on resume, a `Resume` question relaunches stopped delegates with a `RESUME:` line and the same port — never
  without an answer, since a delegate still running elsewhere would share its worktree with the new one.

---

## Shipping — commit, push, merge

```
"grave <branch(es)>" / "engrave <branch(es)>"
```

One or more existing branches, named in the desired order (e.g. `"grave dev"`, `"grave master"`, `"grave dev master"`). `<BRANCH>` is merged into each named branch in turn, always from the starting branch — never chaining one named branch into the next.

The sequence is run by `skills/forge/scripts/engrave.sh`, never rebuilt by hand: `run` executes `add`, `commit`, `push`,
then for each named branch `checkout`, `merge` and `push` of that branch, and a final `checkout` back to `<BRANCH>`,
whatever the number of branches — one git operation per step — and returns JSON that Forge lays out as the report,
even when a step fails (`preview` lists the same actions without running anything; the
delivery does not call it). The script does the work, the model does the layout. A
branch equal to `<BRANCH>` is left out; a missing branch, or one checked out in another worktree, is marked
`skipped`; a clean working tree skips `add` and `commit` and still pushes. On a merge conflict or a rejected push the
script stops: the failed step is `failed` with its reason (the conflicted files for a conflict), every later step
`not_run` — never executed because the sequence stopped before it — and the conflict is left in place, resolved
only when you ask. Run `bash tests/engrave.test.sh`
to check it.

**No confirmation:** `grave` / `engrave` at the start of the message, alone or followed only by existing
branches (`grave`, `grave dev master`) — the sequence runs at once, with no recap beforehand; any other
text in the message means it is not a shipping request. The command authorizes that sequence only. The linked-project questions are still
asked — they set the scope, they confirm nothing. A merge conflict or a rejected push stops the sequence
with the error as is; nothing is ever forced.

**INVARIANT:** git operates only on the current repo — never on another repo open in parallel. The one
exception is a linked project: worktree creation when delegating, the relayed shipping below, and removing
its worktree once its branch is merged.

When the plan carries delegated tasks, engraving the parent also offers to ship each linked project that
has uncommitted changes: first whether to ship it at all, then onto which branches — the same branches as
the parent, the linked branch only (commit and push, no merge), or a list of your own. Its commit message is
generated from the delegated tasks marked done, never from its code, which the parent does not read, and never
names the parent. The
linked project gets its own report table under the parent's, and the same command ships
everything; a target branch missing from the linked repository is skipped, never created. Shipping runs in the
worktree; a target branch checked out in another folder — the linked repository's own folder included — is
skipped, the merge being done from there. The delegated
subagent is never involved: relayed shipping is plain git, run by the parent. When a linked run merged its
branch, its worktree is then removed if the branch reached the default branch and the tree is clean; a
`worktree` line under its table says `removed` or `kept` with the reason.

Anything published on the remote forge after a delivery — release title and notes, tag or PR description — is written in **English**, whatever your language. The commit message follows the language of the repository's commits.

The commit message is generated automatically — no separate confirmation on the message itself. No recap is shown beforehand: the whole sequence runs at once — add, commit, push, then every merge, with no prompt in between. Once the sequence has run, Forge writes nothing more — no log entry, no plan note: the report is plain text, on a fixed template — one table per project, one row per git operation, columns `#`, branch, operation, result in every language `DONE`, `SKIPPED`, `FAILED` or `HALTED` (`done`, `skipped`, `failed`, `not_run` in the JSON), detail: commit hash and message, pushed range or `up to date`, `fast-forward` / merge commit / `already up to date`, skip or failure reason, the git error under the table on failure — and the working tree stays exactly as the delivery left it.

---

## Task closure — report & client reply

Triggered once every task is `[x]` and you've validated the tests, or as soon as you say it's done.

Forge first confirms the original goal is actually solved, listing the tasks still open. Any left are
settled one by one: done (`[x]`), dropped (`[-]`) or kept open. A blocked `[!]` task is never touched, and
`Solved` alone checks nothing.

When the plan carries tasks delegated to a linked project, each linked worktree whose branch is now merged —
by a relayed engrave or outside forge, through a pull request — is removed, with no question; the ones kept
are listed with their reason (`not merged`, `uncommitted changes`).

If the branch has an open ClickUp task, Forge then writes a closing report for the task named by its
`ticket.json` marker, written by `/forge-clickup`: plain text, structured and schematic, in your language — labels included, the only
generated content exempt from the English structural labels. Like any generated content, it is saved
in `.forge/branch/<BRANCH>/output/YYYYMMDD-clickup-report.txt`, rewritten in place when you ask for a
change. The task is fetched before anything is sent, never guessed, and the report is posted as a
comment only on an explicit yes. Without a marker, Forge still looks for a task named after the branch, for
branches opened before the marker; if none matches, no report is written and the step stays entirely silent: closure never creates a ClickUp task, nor offers to.

Last, it offers to draft a reply to a client email — written in the language of the email received,
never yours if they differ, in the voice of a technical support team: short, fluent, professional, direct
and natural, empathetic without being overly warm, focused on solving the problem. It never repeats what
the client just wrote nor restates their whole request when not needed, and it leaves out needless
technical explanations, long sentences and heavy administrative wording. The draft is shown in the conversation and always saved as well, as an exact
plain-text copy in `.forge/branch/<BRANCH>/output/YYYYMMDD-email-client-reply.txt`, plus an `.html` twin
with real tables, opened in the browser to paste into Outlook — ready to send or attach to the ticket the
email came from — ClickUp, Jira or any other tracker. Every other email drafted for a third party is saved
the same way, as `YYYYMMDD-email-<topic>.txt` and `.html`.

---

## Plan format

```markdown
# Plan — <BRANCH>
**Objective:** ...
**Date:** ...
**Estimate:** ≈ 3 files · ≈ 2 min (1-2)

## Tasks

### T1 — Title
**Effort:** S
**Estimated time:** ≈ 2 min (1-2)
**Files:** `src/a.ts`, `src/b.ts`, `tests/a.test.ts`
**Description:** ...
[ ]

<!-- L or XL task: decompose into micro-steps before starting
[ ] T1.1 — ...
[ ] T1.2 — ...
-->

## Summary
| Task | Effort | Files | Estimated | Actual | Status |
|---|---|---|---|---|---|
| T1 — Title | S | 3 | ≈ 2 min | — | [ ] |
| **Total** (0/1 measured) | | | — | — | |
| **Remaining** | | **3** | **≈ 2 min (1-2)** | | |
```

**Written by the hook:** `**Estimate:**`, every `**Estimated time:**`, `**Actual time:**` and the whole `## Summary` (cells copied from the tasks, blocked reason included, `**Total**` over the measured tasks, `**Remaining**` for the open tasks) are kept by `plan-hook.sh` on every write of `plan.md`; the model writes the tasks and the short title of each summary row. `**Actual:**` (actual time of the branch by item, under `**Estimate:**`, when a measure log exists) is written by `metrics.sh` at engrave and closure time only; the hook leaves it as is.

**Statuses:** `[ ]` to do · `[x]` done · `[!]` blocked · `[-]` dropped  
**Effort:** XS · S · M · L · XL — relative size, no duration attached; XL → split into sub-tasks, or into a branch  
**Estimate:** order of magnitude of agent time, never a commitment; the user's answer time is never counted

---

## License

MIT — see [LICENSE](LICENSE).

