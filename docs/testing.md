# Testing

How to verify Ka0s Aura Master (testing-§6). What to install first is root `DEPENDENCIES.md`; this
page is how to run it. Every command runs from the repo root.

## The green commit gate

Both must pass before **every** commit (testing-§4):

| Check | Command | Expected |
|---|---|---|
| Headless suite | `lua tests/run.lua` | every suite green; exits non-zero on any failure |
| Lint | `luacheck .` | `0 warnings / 0 errors` |
| Syntax-check one file | `luac -p path/to/file.lua` | no output |

`tests/_kit/run-automated-tests.sh --suite lint --suite tests --no-bundle` runs exactly that pair and
writes nothing, so it may stand in for the two commands. If the serial suite ever passes about ten
seconds, `lua tests/run.lua -j auto` fans it across CPUs (testing-§14); check it agrees with the
serial run before relying on it.

## The four out-of-game suites and their checkpoints

There are two checkpoints — the run and the commit it gates, and the release tag — and a suite's
answer differs between them (automated-tests-§3):

| Suite | Command | Run + commit | Release tag |
|---|---|---|---|
| `lint` | `luacheck .` | **gates** | **gates** |
| `tests` | `lua tests/run.lua` | **gates** | **gates** |
| `perf` | `lua tests/perf.lua` | does not gate — recorded | **gates** — must be `pass` |
| `complexity` | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | does not gate — recorded | **gates** — `pass` with zero functions above CCN 15 |

`perf` and `complexity` never fail a run and never block a commit (performance-§9, performance-§10);
a threshold that fails a run teaches everyone to reach for `--no-verify`. The **tag** is a separate
checkpoint: the release is cut only when the release run's `manifest.json` shows all four suites at
`pass` and `suites.complexity.warnings` at `0`. A **skip** there is **not evaluated**, never a pass —
install the missing tool and run again. The release command reads the manifest; the runner's own exit
code is unchanged. Recording those runs is `docs/automated-tests/README.md`.

**lizard and the length operator.** lizard's shared tokenizer takes a `#` outside a string as the
start of a C preprocessor line and drops everything after it up to the newline. In Lua `#` is the
length operator. A block keyword or an unbalanced brace after it on the same line throws off lizard's
block count, so every later function in that file goes unmeasured and the gate stays silent without
having looked. An `and` or `or` after it is left out of the CCN. The last case in
`tests/test_lintconfig.lua` fails any line where a keyword or an unbalanced brace follows a `#`. Move
what follows onto its own line, or take the length into a local first.

## What the headless suite is

`tests/run.lua` loads the vendored LibKa0s files in `LibKa0s.xml` order, then the addon's own files
straight from `AuraMaster.toc` (testing-§9), on the mock from `tests/wow_mock.lua` — a thin extender
over the kit's `mock_base.lua` whose aura engine is an ordered call recorder. It then mirrors the
in-game lifecycle (`OnInitialize`, `OnEnable`, the first coalesced apply) and runs the declared suite
list through `Kit.run`, which fails the run on a suite on disk but not declared, or declared but
missing.

The harness proves what can be proved without a client: the filter compiler's plans, the registry and
its migrations, the schema and its write seam, the engine call order, the slash surface, the setup
files' descriptors, and the documentation gates. It cannot see real aura data, secrecy, taint or
drawn frames — that is the smoke suite.

Suites worth knowing by name:

- **`tests/test_bulklog.lua`**: debug-logging-§10, act by act. A page's Defaults, Reset all (live
  and degraded), `CliResetAll`, `CopyFrom` and `ResetPositions` each log one `[Set]` line whose N
  counts only the rows that changed (a `-0` over a `0` is no change), and no per-row line. A profile
  reset or copy logs one line, from its handler; the reset's carries no count. A nested bracket logs
  once. An act an error stops logs its line once, marked ` (stopped by an error)`, counting the writes
  it stored.
- **`tests/test_disabled.lua`**: the stand-down conformance suite slash-commands-§7 requires. Every
  negative assertion reads the kit's recording mock (`__registrations`, `__timers()`,
  `__shownFrames()`, `__svWrites()`, the printed lines), never a handler's return value, because an
  early return is exactly what a draw gate does. Disabling through the write seam unregisters the
  addon's events, messages and timers and hides its frames at the source; re-enabling rebuilds from
  the settings as they are then; the `disabled` and `perf` holds release independently. The slash
  step walks every entry in `NS.COMMANDS`: the reserved verbs, the schema CLI, `containers`,
  `select` and the bare `/am` (which opens the panel) answer normally, and only the feature verbs
  refuse on the collection's one line with no SavedVariables write. The launcher's left-click is
  refused the same way; its right-click still opens the panel. The negative steps carry testing-§12
  falsification comments.
- **`tests/test_docs.lua`** — no angle-bracket placeholder in `README.md` (CurseForge strips them),
  US spelling in every authored file against localization-§5's published lists, and the
  `## Documentation map` agreeing with `docs/` in both directions, and every `file:line` citation in
  `docs/*.md`, `DEPENDENCIES.md` and `README.md` naming an existing file and a non-blank line. Each
  citation must also still point at what its sentence names: the sentence gives at least one name in
  backticks (a table row is one sentence; a line in a fenced block names everything on it), and one
  of those names sits within 3 lines of the cited range. A line that moved under a citation fails
  this, where existence alone passes. It is a heuristic, not a proof: whether the cited code still
  does what the prose says is still for review to decide.
- **`tests/test_lintconfig.lua`** — `.luacheckrc` carries no blanket suppression, so `0/0` is a
  statement about the code, and every `read_globals` name is one some authored file reads as a
  global, so a retired API (anti-pattern #10) cannot be declared back into lint-clean.
- **`tests/test_vendor_sync.lua`** — `libs/LibKa0s/` and `tests/_kit/` are byte-identical to the
  LibKa0s tag named in `CLAUDE.md`. With no `../LibKa0s` checkout beside this repo it records a
  **skip with its reason**, not a pass (testing-§11).
- **`tests/_kit/test_eol.lua`** — the working tree agrees with `.gitattributes`, and `.gitattributes`
  is line-endings-§5's canonical body.
- **`tests/_kit/test_layout_cap.lua`** — every authored `.lua` over layout-§1's 1500-line cap is in
  the `### Files over the 1500-line cap` census in `docs/ARCHITECTURE.md`, with a terminal state,
  and no census row outlives its breach.

## The degraded environment

`tests/degraded_env.lua` builds a second, complete environment from the TOC with **LibKa0s left
out**, so every setup file takes its real degradation stub — the options stub has to complete the
load, the slash stub has to answer, the perf stub has to carry every member the addon calls
(testing-§8). Suites compare that environment against the live one; nothing hand-stubs a namespace
member to test it. `tests/fresh_env.lua` builds an isolated, fully loaded environment for any suite
that mutates state, so suite order cannot change a result.

## The case inventory and the badge

`docs/test-cases.md` is the authoritative list and pass count, **generated**, never hand-written
(testing-§5):

```sh
lua tests/run.lua --list > docs/test-cases.md
```

Whenever a case is added, removed or renamed, or the pass count moves, regenerate it and update the
README's `Tests` badge (`Tests-X%2FY_passing`) in the same change. A skip is shown as a skip, never
folded into either figure. This page quotes no count, so there is nothing here to drift.

## In-game

`docs/smoke-tests.md` is the in-game suite, run before a release, after an `## Interface:` bump and
after a re-vendor. It covers what only a live client can: the engine drawing real auras, secrecy and
the deferral path, taint, dragging, the frame picker and the settings panel.
