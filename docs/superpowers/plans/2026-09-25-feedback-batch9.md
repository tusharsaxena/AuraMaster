# Feedback batch 9 Implementation Plan

> Run as Workflow orchestration (ultracode): one implementer and one independent reviewer per task.

**Goal:** fix what the owner's batch 8 smoke run failed, and rework container attachment so its points
can be chosen. **Spec:** `docs/superpowers/specs/2026-09-25-feedback-batch9-design.md` (binding).
**Evidence:** `docs/superpowers/research/2026-09-25-feedback-batch9-findings.md`.

## Global constraints

Batch 8's constraints apply unchanged (`docs/superpowers/plans/2026-09-25-feedback-batch8.md`, "Global
constraints"): the green gate runs before EVERY commit through the bounded runner; commits and branch
pushes are authorized; merging, tags and version bumps are not. The branch is still
`feat/2026-09-25-feedback-batch8`. Commit subjects start `B9-<task>: `. Never evade a hook or the
auto-mode classifier: if a hook blocks a command because of a tool name in its text, write the message
to a file and run `git commit -F`.

## Resume

Git is the state. A task is done when a `B9-<task>: ` commit exists on the branch:
`git log --format=%s master..HEAD | grep -o '^B9-Q[0-9]*' | sort -u`. Trust git over the ledger.
Resume at the first task, in order, that has no commit. A dirty tree is that task's partial work.

## Status ledger (update in each task's own commit)

| Task | Req | Depends | Status | Commit | Notes |
|---|---|---|---|---|---|
| P0 tab rename, smoke record | E7 | — | done | 73e44b5 515474b 73c72e4 | |
| Q1 diagnostics secret-safe + inert rows | DX-1 DX-2 | — | done | this commit (subject `B9-Q1: `; a commit cannot hold its own hash) | frameShown tri-state via CanAccess, shown=?/n+k?, per-group/per-listing/predictions pcall, probe pcall; [Cfg] `#N inert:` line from shownWhen + page disabledFor (NS.ContainerPageDisabledFor); attach.edge needs only CONTAINER_ONLY in Q6; quirks + debug.md + KL updated |
| Q2 Size to fit Text-only; creates v9 | E6 MG-1 (autoSize half) | Q1 | done | this commit (subject `B9-Q2: `) | v8 stamps autoSize off only on style=="text"; new MigrateV9 + ladder row {to=9} removes text.autoSize from non-text containers (no stored style = bars), idempotent; ladder tests from v1, v7, v8; schema.md v9 entry, KL, debug.md, test-cases regen + badge 1482 |
| Q3 live Size to fit never clips | TX-1 E8 | Q2 | done | 9227ffc, review fix (subject `B9-Q3R: `) | the bound was SetClipsChildren(true) on the clip and text-area frames (pieces are single-anchored, no width, no wrap); applyClip turns both off while Size to fit is on, on while off; tests with "Guardian of Ancient Kings" live L/C/R, stacked, preview, toggle; setting desc, KL, smoke 99/202, module-map, test-cases + badge 1486; optional budget widening not done; review: smoke 201/105 and KL now say a Top bounce rises uncut under Size to fit |
| Q4 label Justify | LJ-1 E7 | Q3 | done | this commit (subject `B9-Q4: `) | `label.justifyH` stored `"AUTO"` (C.LABEL_JUSTIFY_AUTO) for no pick, not nil: architecture-5 needs every row path to resolve against the template; Anchors.LabelJustify resolves bars/text CENTER, icons LEFT/RIGHT by growH (mirrored beside a follower, kept from NL-2); Justify row with panelGet + validate, reset writes AUTO; schema.md, settings-panel, smoke 203, KL, module-map, test-cases + badge 1492 |
| Q5 empty-only placeholder (was: drop the slot hang) | HG-1 E1 | Q4 | done | 6ae22a7 (spec amendment), a85546c, review fix (subject `B9-Q5R: `) | owner amendment 2026-09-25: `slot` kept, gated on `Container:PredictEmpty() == true` (nil/false hang from the engine), design appended to the findings; new modules/EmptyWatch.lua (secret-safe EW.Predict over C_UnitAuras + GetWeaponEnchantInfo, two RegisterUnitEvent frames, 0.2 s coalesced pass, enchant-expiry timer, REGEN_DISABLED forces engine via EW.SetCombat), ApplyHang gates hang + outline, bucket emptyPass, perf scenario emptyWatchAura 0 B/iter; watches every shown unlocked container, not only followed parents, so an unfollowed container's placeholder also tracks its auras; KL, smoke 191-196, data-flow, performance, module-map, midnight-quirks, test-cases + badge 1514; review: the player unit-filter frame filters UNIT_AURA alone (events-frames-taint-§1 carve-out), UNIT_PET and UNIT_INVENTORY_CHANGED moved to AceEvent with a player-only check, badge 1515 |
| Q6 attach edge model + Side dropdown + v9 edge/seam | AP-1..AP-4 E2 E5 MG-1 | Q5 | done | ddf13d6; review fix in this commit (subject `B9-Q6R: `) | `attach.edge` token relative to the flow (C.ATTACH_EDGES); Anchors EDGES/ParseEdge/IsEdge/EdgePoints/EdgeAllowed/ResolvedEdge/DefaultEdge/EdgeLabel, DerivedPoints = EdgePoints(L,"after-start") pinned for all 8 combos; SeamOffset(L, side), clearStrip after-only; Side row (filtered, absolute labels, " (unavailable)", validate with reason), "Its %s joins the %s of '%s'", edgeFallbackNote; E5 default on a new attachment (mode or target onChange; a pick made before the target is kept for the session; E5 made growth-aware: LEFT/RIGHT map to start/end under growH); FLOW_PATHS + attach.edge, layout.perLine; requestParents + old parent from the target onChange; v9 stamps edge and resets screen 0/-4; normalizeAttach on load; schema, settings-panel, data-flow, ARCHITECTURE, module-map, KL, smoke 67, test-cases + badge 1542. Review (B9-Q6R): the Container row's help no longer says the points are set for you (it names Side); badge 1543 |
| Q7 growth-conflict popup | GC-1 E3 | Q6 | done | 385d1e0, review commit (subject `B9-Q7R: `) | option i: inheritance kept, nothing written; Anchors.FlowChangeOnAttach(child, targetId) compares the child's stored axis/growH/growV (over the template) with the target's chain root, nil when unusable (none, self, missing, loop), else { root, keys, followers }; OptionsSetup `confirmFirst` in the descriptor's set: a row's `confirmWrite(value, id)` returning a popup key and text hands the write to the popup (data {path,value,id}) and requests a refresh; confirmWrite on attach.container (container mode, new target) and on the mode row (to container with a target stored); AURAMASTER_ATTACH_FLOW in settings/Layout.lua (text "%s" so a % in a name is safe), OnAccept refused in combat, writes through SetByPath, OnCancel/OnHide refresh; /am set chat line from the onChange (suppressed for a popup-confirmed write); a detach whose flow differs prints a line for any container, not only mid-chain (superset of GC-1); root's Growth tab counts its followers (design §3); settings-panel, module-map, smoke 41, test-cases + badge 1554; two existing layout tests now pick a same-flow target; review (subject `B9-Q7R: `): schema.md lists the new `confirmWrite` row field |
| Q8 strip side, join pin, test outline, enchant preview | SEP-1..SEP-4 E4 | Q7 | done | this commit (subject `B9-Q8: `) | `Anchors.StripSide` replaces besideSeam (root/side follower before; after follower behind, ahead when one wide and free, else inside; direct followers found by an allocation-free walk of the stored containers); StripPoints per side, a behind follower's before strip lined up with H1, an ahead follower pushed past its parent's strip and label rows (static, so the Apply-placed label clears them locked too); labelPush, clamp, stripRoom and LabelJustify read the side; join pin (10x10 gold diamond, built once out of combat, CENTER on the child point, shown unlocked and placedAs container) and `Anchors.JoinText` tooltip line; ApplyOutline draws around previewExtent while previewing, locked or not; C.PREVIEW_AURAS.ENCHANT picked by AurasFor from the compiled plan, and Size to fit measures it for buff containers; new suite test_anchors_strip; KL, data-flow, settings-panel, module-map, schema/data-flow citations, test-cases + badge 1573 |
| Q9 docs sync, smoke section AA, full battery | all | Q8 | todo | | |

Tasks run one at a time: they share `Anchors.lua`, `Container.lua` and the migration ladder.

## Milestones (checkpoint and branch push after each)

| M | After | Checkpoint |
|---|---|---|
| N1 | Q1–Q4 | green gate; push |
| N2 | Q5–Q7 | green gate; the v9 migration tests pass; push |
| N3 | Q8–Q9 | full battery; smoke section AA written for the owner; push; stop, since the merge waits for the owner |

## Checkpoint log

| When | Milestone | Evidence |
|---|---|---|
| 2026-09-25 | N1 | tests 1492 passed / 0 failed / 0 skipped (16 shards); luacheck 0 warnings / 0 errors in 130 files; lizard 0 over CCN 15 (3917 functions); head ba1219e |
| 2026-09-25 | N2 | tests 1554 passed / 0 failed / 0 skipped (16 shards), v9 migration tests included; luacheck 0 warnings / 0 errors in 133 files; lizard 0 over CCN 15 (4100 functions); head 34b902b |
