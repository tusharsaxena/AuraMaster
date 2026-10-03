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

## A6-A9. Second smoke round (owner, the same evening)

Owner: "1. There is no highlight around the anchor (the strip with gold border). 2. It's still not
possible to anchor top of parent to bottom of child; it always picks top-left, bottom-right etc. 3. The
64px distance is way too little, make it 128px. 4. Anchor point indicators still anchor around the
placeholder area rather than the anchor (the strip) area." Screenshots: the parent's strip unedged;
the dots on the one-element placeholder's corners, the strip below them unmarked.

### A6. The strip's OWN edge is repainted (fixes 1; replaces A5's overlay)

Most likely cause, not provable headless: A5's overlay was a frame of ours under UIParent anchored
with SetAllPoints to the strip, which hangs under the container's anchor; the client refuses or voids
anchors from outside into that restricted tree (the same rule that makes GameTooltip refuse SetOwner on
the strip, `tooltipSpec`). So no frame of ours is anchored to a strip any more. Instead the mark
repaints the strip's own edge through the painter that drew it (`NS.Style.DrawEdge(strip, 2, r, g,
b, 1)`, the same four textures, which live on the strip), and restores the widget's own gold
(`DrawEdge(strip, 1, 1, 0.82, 0, 0.6)`, named once as constants beside the other strip numbers) when the
mark leaves that strip or hides, on every end path (drop, cancel, combat, a strip hidden mid-drag,
Destroy of either container, profile switch). A target with no visible strip keeps the box fallback.

### A7. Side first, then align by thirds (fixes 2)

Equal-width containers made the three pairs of a side exactly equidistant, and ties kept the start
pair, so the middle pair could never win. The pick is now:
1. **side**: for each of the parent's four sides, the gap between the child's facing edge and that
   side (bottom: parent.bottom - child.top; top: child.bottom - parent.top; right: child.left -
   parent.right; left: parent.left - child.right), eligible when `|gap| <= C.SNAP_RADIUS` and the
   child's span along that side overlaps the parent's span widened by `C.SNAP_RADIUS`;
2. **align**: the child's center along that side, over the parent's edge cut in thirds: first third
   the start pair (LEFT, or TOP for a left or right side), middle third the middle pair, last third the
   end pair; then the mirrored child point (A2's table);
3. **rank** across sides and targets by `|gap|`, ties by target id then A2's table order; the answer's
   `dist` is `|gap|` (what A4's "strictly nearer" compares).

### A8. Measured and drawn on what you see (fixes 4)

Every rect the snap reads, for the target and for the dragged child, is the container's VISIBLE
FOOTPRINT: the union of its block rect (the hang rect as before, with its fallbacks) and, while each is
shown, its strip and its name label, each read through the secret guards and simply left out when it
does not read. Dots, line, box fallback, the side and align pick and the A4 leeway all use footprints.
Where a drop attaches is unchanged (the twelve pairs, Place's seam and rooms), and the footprint is what
those rooms already push past, so the dots land where the containers will touch.

### A9. `C.DETACH_RADIUS = 128` (fixes 3)

## A10. The strip is the rect (third smoke round)

Owner, with a screenshot (strip edge green as A6 meant; the parent's dot on the top-left corner of the
white placeholder above its strip): "The drag handle (arrows and dots) shows on the placeholder (white
border) rather than the anchor area (strip with gold border); make them attached to the anchor."

Every rect the snap measures and draws on (A8's footprint, for the target and the dragged container)
is now the container's **strip rect** while its strip is visible and reads; otherwise A8's footprint
as before (block, plus the label while it shows). The side, the align third, the dots, the line and the
A4 leeway all follow. Where a drop attaches is unchanged (Place joins the blocks and pushes past the
strips and labels); `docs/known-limitations.md` says the dots mark the strips, not the exact join.

## A11. The parent's growth sides reach its block (owner's pick, option 1)

After A10, the final review showed the dots and the landing disagree on the parent's growth side: a
parent growing down is measured on its strip's bottom (its block's top), while a child attached below
lands under its block. The owner chose option 1: the PARENT's measuring rect is its strip rect (A10),
except that each edge on a side the parent grows toward (its vertical growth side: bottom growing down,
top growing up; its horizontal growth side: right growing right, left growing left) is taken out to its
block's far edge on that side (the union of strip and block, on that edge only), when the block reads.
The dragged child's rect stays its strip (its strip is on its own before side, which a seam joins). The
side pick, the thirds, the dots, the line and the leeway all follow. The before side's one-element jump
and overlap (known limitations) stay as documented.

## A12-A13. Fourth smoke round (owner, 2026-10-03, Default profile)

Owner: "sometimes, the wrong side is chosen (on the child container) to attach to": two screenshots
of a column of 288 by 20 strips growing up. In the right one the child, up and to the right of its
parent, joins by its left side to the parent's right side. In the wrong one the child sits right
beside one strip of the column, overlapping its height, and is joined by its RIGHT end to the
top-right corner of the strip below, a line the child's whole width long. And: "when doing a drag
operation and a highlight is active on the anchor (strip with gold border) - it should highlight BOTH
the parent and child. Currently only the parent gets the highlight."

### A12. A side the child faces, then the shortest line (fixes the wrong side)

Cause: A7 ranks the eligible sides by their gap alone. The strip below's top was 16 away and the strip
beside's right 21, so the top won, and its thirds named the end pair, whose two points lie a whole
strip width apart. The side and the third are still found as A7 says (eligible by the gap and the
widened span; the pair by the third). Among the eligible sides, of every target:
1. a side the child FACES, its span along that side overlapping the target's own, unwidened (a
   touch is no overlap), beats a side it is only off the corner of;
2. between two alike, the shorter line between the pair's two points (the line the mark draws) wins;
3. ties keep the first target in id order, then A2's table order.
The answer's `dist` stays the gap (A4's "strictly nearer" is unchanged); the line's length rides along
as `line`.

### A13. The dragged container's strip is lit too

While a mark shows, the dragged container's own strip is repainted exactly as the target's (A6: its
own edge, 2px, through `Style.DrawEdge`, in the mark's color, green or red past the leeway), and gets
its 1px gold back on every path the mark ends by, alongside the target's.

### A14. The strip tooltip under a parent holding auras (owner's option B)

The owner saw the strip tooltip at the cursor for containers attached under a parent holding auras:
their strip's rect reads secret, so `tooltipPlace` declined and the widget followed the cursor. Of the
three options put to the owner (document it; pin it beside the cursor; a custom tooltip frame inside
the restricted tree, a LibKa0s change), the owner chose B: where the strip's rect does not read,
`NS.AnchorsTooltip.Place` pins the tooltip to UIParent beside the cursor where it entered the strip
(TOPLEFT `CURSOR_GAP` = 16 right of it and `CURSOR_RISE` = 10 above it, or TOPRIGHT 16 left of it near
the screen's right edge), fixed for the hover. Only a cursor, tooltip or screen that does not read
still answers nil (the cursor-following fallback).
