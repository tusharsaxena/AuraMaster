# Feedback batch 10 — design spec

- **Date:** 2026-09-25 (late)
- **Branch:** `feat/2026-09-25-feedback-batch8`, which is still unmerged
- **Source:** the owner's smoke run of batch 9 (`docs/smoke-tests.md` section AA, "Owner run" table).
  The screenshots are in the session: the setup (Text chain #13 → #14 → #15, Side Bottom, growth
  down), the unlocked state today, the owner's mockup, and the label placement while locked and
  unlocked.
- **Plan:** `docs/superpowers/plans/2026-09-25-feedback-batch10.md`
- Batch 9's spec stays binding except where this spec changes it.

## 1. Owner decisions

| # | Decision |
|---|---|
| F1 | **While unlocked, every strip sits in its own container's column, directly on the container's "before" side** (above its block when the chain grows down, below it when it grows up). The owner's mockup reads, top to bottom: strip, block, strip, block, strip, block. A follower is no longer shown with a strip beside the column (this retires batch 9 SEP-3's beside and inside placements for `after-*` followers). |
| F2 | **The chain spreads out to make room while strips show.** A follower attached on the `after` side sits past its parent's block by the room its own before-side furniture needs: the strip, plus the label when shown, plus their gaps. The seam itself (SS-1, the child's own spacing) and the `attach.x/y` nudge are added on top. When locked with no strip, only the label's room (if the label is shown) plus the seam remains. When locked with no label, it is exactly the seam, as today. Test mode shows strips, so it spreads the same way as unlocked. |
| F3 | **Order on the before side, always: strip (outermost), then label, then block.** The root and every follower follow the same order, whichever way the chain grows. When locked, the label sits directly on its block's before side. The label is justified inside its block's width per LJ-1, and X/Y apply on top. It never floats beside the column. |
| F4 | `ahead-*`/`behind-*` (side) followers keep their strip and label on their own before side as well. The chain does not need to spread for them, but they must not overlap the parent's strip or label. If they would, push the side follower along the growth axis by the parent's furniture room. |
| F5 | The join diamond (SEP-2) and the test-mode block outline (SEP-1) stay. The strip tooltip's "Joined to …" line stays. |
| F6 | **The Growth tab's inherited note** reads: "Fill and growth follow '%s' because this container is attached to it." It is drawn dim gold (the addon's muted gold used for secondary text; check `H`/`NS` color helpers), with vertical spacing below it before the Growth rows. |
| F7 | **The v10 migration** re-runs, idempotently, the two halves that joined v9 after the owner's install had already stamped v9: `attach.edge` is stamped where missing or unknown, and screen-mode 0/-4 becomes 0/0. Lesson recorded in the plan: once a branch has been pushed, a migration step is never extended again. A new step is added instead. |
| F8 | **Diagnostics:** when the addon is disabled or stood down, the header says so in plain words ("addon disabled: containers are not built; predictions only"), and the `[Plan] #N not built` lines add the reason. |

## 2. Constraints

The same as batch 9 §3. Every geometry change has headless tests for the root, an `after` follower, a
chain of three, growth down and up, label on and off, locked, unlocked and test mode, and a side
follower. The perf scenarios stay allocation-free.
