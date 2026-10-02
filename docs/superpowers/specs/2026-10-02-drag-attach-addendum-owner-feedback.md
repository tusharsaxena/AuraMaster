# Drag to attach: addendum from the owner's smoke feedback

Owner feedback on 2026-10-02 after DRAG-1..DRAG-14 ("works as expected"), four changes. It amends
`2026-10-02-drag-attach-design.md`, which stays as written. Items DD-07..DD-10 are listed in its plan's
addendum section, `docs/superpowers/plans/2026-10-02-drag-attach.md` stays frozen otherwise.

Two readings the orchestrator took (the owner can overrule at smoke time): "detach on mousedown"
means **on release** (the button is already held while dragging), and "arrows" means the **line**
drawn between the two join points (A1, A3).

## A1. A bigger join dot (feedback 1)

The parent's join marker grows from 6px to **10px** (`MARKER`).

## A2. Twelve pairs, by mirror (feedback 2)

A drop no longer picks among the nine growth-relative sides only. The candidate pairs are the
**twelve outside pairs**, absolute and independent of growth: for each of the parent's four sides, its
start, middle and end point, joined to the child's point that mirrors it across that side, so the
child sits flush outside the parent:

| Parent side | Parent points | Child points |
|---|---|---|
| bottom | BOTTOMLEFT, BOTTOM, BOTTOMRIGHT | TOPLEFT, TOP, TOPRIGHT |
| top | TOPLEFT, TOP, TOPRIGHT | BOTTOMLEFT, BOTTOM, BOTTOMRIGHT |
| right | TOPRIGHT, RIGHT, BOTTOMRIGHT | TOPLEFT, LEFT, BOTTOMLEFT |
| left | TOPLEFT, LEFT, BOTTOMLEFT | TOPRIGHT, RIGHT, BOTTOMRIGHT |

The nine sides of the original D1 are nine of these twelve under any growth; the three new ones are
the side opposite the parent's growth (`before`), which classify as a FREE pair (batch 11 G5: placed
at X/Y alone, no seam gap, no spread). Folding to Automatic (D7 as fixed in DD-05: whole pair only)
is unchanged. Ties keep the first target in id order, then the table order above.

## A3. The line and the child's dot (feedback 3)

While a pair is shown, the highlight draws: the box over the parent (unchanged), the parent's dot
(A1), a **dot of the same size on the child's join point**, and a **2px line** between the two dots.
Built once with the highlight: plain frames and textures under UIParent (a `Line` region from
`CreateLine`, its two ends set in UIParent units), no Backdrop, nothing anchored to a container.
All of them take one color (A4).

## A4. Detach leeway on an attached container (feedback 4)

New `C.DETACH_RADIUS = 64` (UIParent units). While an attached container is dragged, each tick works
out, in this order:

1. **another pair in snap range** (any candidate of A2, on any target including its own parent, that
   is not its current pair, within `C.SNAP_RADIUS`, Shift not held): green, shown on that pair; a
   release attaches there (unchanged D7/D8);
2. **hold**: the distance between its current pair's two points (its own point now, its parent's
   point now) is at most `C.DETACH_RADIUS`: green, shown on the current pair; a release **snaps it
   back** where its settings put it and writes nothing (log `drop: held (leeway)`);
3. **detach**: beyond it: the box, both dots and the line turn **red** (`C.DETACH_COLOR`), shown on
   the current pair; a release detaches at the drop point (D6, unchanged).

Shift still suppresses step 1 only; the hold and the detach still apply. When the parent's rect cannot
be read (a hidden or unreadable parent), step 2 measures nothing and holds while the cursor has moved
less than `C.DETACH_RADIUS` from where the drag started. A screen container's drag is unchanged (no
hold, no red). Combat (D11) is unchanged: the marks hide and nothing is written.

The strip tooltip's line for a container-attached one becomes: "Attached to '%s'. Drag it away and
let go once the marks turn red to detach it; let go sooner and it snaps back. Drop it on another
container to attach it there; hold Shift to drop it without attaching. Right-click for settings."

## Tests and docs

Headless cases: the twelve pairs and their mirror (one per side under two growths); a before-side drop
stores the absolute pair; the dot size; the line and the child dot shown and placed; hold, snap-back
writes nothing; past the radius, red, release detaches; another pair beats hold; Shift with hold; the
unreadable-parent fallback; the tooltip line. Docs: ARCHITECTURE, known-limitations if touched,
smoke-tests (DRAG-2 and DRAG-5 updated to the new rules, new DRAG-15 for the leeway and red, DRAG-16
for a before-side drop and the line), test-cases, README badge.

## A5. The highlight is the target's strip, not a box over its placeholder (owner, later the same day)

The owner, with a screenshot of the green box framing the target's placeholder: "do the highlight on
the actual anchor itself (change color, etc), not on the placeholder; if needed change the border
width of the anchor when highlighting (red and/or green)", and confirmed "the strip is what I meant":
the target's drag-handle strip. Where a drop attaches stays as it is.

- The box over the target's rect is no longer drawn. Instead the TARGET's strip (for a hold or a
  detach, the current parent's strip) shows a **2px edge in the mark's color** (green, or red past the
  leeway) over its own 1px gold edge: an overlay of ours, a plain frame `SetAllPoints` on the strip at a
  level above it, drawn with `Style.DrawEdge` (no Backdrop, nothing read off the strip, so a strip whose
  geometry reads secret is fine). Removed from the old target when the mark moves or hides; the
  strip's own edge is never changed.
- The two dots and the line (A1, A3) stay, measured as before.
- A target with no strip (LibKa0s-Widgets absent, or its strip hidden) falls back to the old box over
  its rect, so a mark is never lost.
- A hold or a detach whose parent rect is unknown keeps A4's single-dot mark; its parent's strip is
  still colored when it has one.
