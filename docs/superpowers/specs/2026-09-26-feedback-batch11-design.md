# Feedback batch 11 — design spec

- **Date:** 2026-09-26
- **Branch:** `feat/2026-09-25-feedback-batch8`, which is still unmerged
- **Source:** two owner requests made in the session on 2026-09-26, one with a screenshot of
  Anchor > Another container (the Container and Side rows).
- **Plan:** `docs/superpowers/plans/2026-09-26-feedback-batch11.md`
- Batches 9 and 10 stay binding except where this spec changes them.

## 1. Owner decisions (verbatim first, then what they mean)

> "Lets add a parent and this container anchor point. 'Parent container anchor point', 'This container
> anchor point'. If it looks weird, its on the user. Make defaults sensible depending on the parent and
> child container types and growth directions."

> "In the anchors UX, remove the dot which shows the anchor points."

| # | Decision |
|---|---|
| G1 | **The Side row is replaced by two dropdowns** under Anchor > Another container: **"Parent container anchor point"** and **"This container anchor point"**. Each offers all nine WoW points (Top left, Top, Top right, Left, Center, Right, Bottom left, Bottom, Bottom right). Any pair is allowed. There is no validation and no fallback, and nothing is refused because it looks odd: "if it looks weird, it's on the user". The attachment sentence beside the Container row ("Its Top left joins the Bottom left of 'X'") stays and is built from the two points. |
| G2 | **Stored as absolute points**, `attach.point` (this container) and `attach.relPoint` (the parent). Each is independent: **nil means Automatic**, the sensible default of G3. Each dropdown's first entry is "Automatic (<point in effect>)", which stores nil, like Label Justify (LJ-1); an explicit choice stores the WoW point token. When only one of the two is set, the other stays automatic, computed as the matching half of the default pair. |
| G3 | **Sensible defaults** (both nil): the pair `Anchors.EdgePoints(parentLayout, token)` for the old after side, with an align picked from the two containers' styles, so the default follows the parent's growth (below growing down, above growing up, and so on) and flips with it: **a Text child** lines up with its justify, as `DefaultEdge` already does (CENTER → center, and the start or end side for LEFT/RIGHT under the chain's growH); **an Icons or Bars child under a Text parent justified CENTER** is centered; **every other pair** starts on the side the parent's lines start from (LEFT growing right, RIGHT growing left). |
| G4 | **Migration v11 (a new step; v9 and v10 are never touched again).** A stored `attach.edge` equal to the old default `after-start` is dropped, so the container becomes Automatic and takes G3's defaults. **Any other stored edge** is converted to the absolute points it resolved to under the profile's current layout, exactly as `ResolvedEdge` + `EdgePoints` place it today, so a side the owner picked never moves. `attach.edge` is removed afterwards. Idempotent; ladder tests from v1, v8, v9 and v10. Consequence, accepted: an Automatic Text-under-Text chain may re-center under G3. |
| G5 | **Furniture with free points.** Classify the effective pair: when it equals `EdgePoints(L, token)` for one of the nine batch 9 tokens under the parent's layout, batch 10's behaviour for that token applies unchanged (in-column strips and labels, the chain spreading by `furnitureRoom`, a side follower pushed clear of its parent's furniture). **Any other pair is "free":** no spread and no push; the strip and label still sit on the container's own before side; overlaps are the user's to arrange. The seam (SS-1) applies only to classified pairs; a free pair is placed at X/Y alone. The `behind` one-aura-wide restriction (EdgeAllowed) no longer refuses anything. |
| G6 | **The join dot is removed**: the gold diamond join pin (batch 9 SEP-2, batch 10 F5) is deleted, code and tests, along with its smoke checks. The test-mode block outline (SEP-1) and the strip tooltip's "Joined to …" line stay. |
| G7 | The growth-conflict popup (GC-1), growth inheritance and the Growth tab's inherited note are unchanged. `/am set` accepts the two new paths with the nine point names (any case) or `auto`; `container.attach.edge` is no longer a settable path. Diagnostics prints the two points in effect and whether each is automatic, and the classification (the token, or "free"). |

## 2. Constraints

The same as batch 9 §3 and batch 10 §2. Headless tests cover: the defaults for every style pair under
growth down, up, left and right; one explicit point with the other automatic; a free pair (no spread, no
push, no seam); a classified explicit pair behaving as batch 10; the v11 migration (default edge dropped,
non-default edge converted, idempotent, ladders); the dot's absence. Perf scenarios stay allocation-free.
