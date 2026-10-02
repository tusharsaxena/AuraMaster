# Drag-and-drop container attachment: design

Issue: [#22](https://github.com/tusharsaxena/AuraMaster/issues/22). Branch `feat/2026-10-02-drag-attach`.
Decided by the orchestrator under the owner's standing run guidelines (decide, ask only when necessary);
every decision below is open to the owner's smoke-test feedback.

## What the issue asks, and what is already true

1. **Drag to attach.** While unlocked, dropping a container near another one attaches it there
   (Layout > Anchor: Attach to *Another container*, the dragged container the child). **New.**
2. **Drag to detach.** Dragging an attached container away and dropping it puts it back on the screen at
   the drop position. **New.** Today an attached container cannot be dragged at all (`canDrag`,
   `modules/Anchors.lua`; the owner, 2026-09-26).
3. **Richer anchor points.** **Already delivered** by batch 11 G1/G2: `attach.childPoint` and
   `attach.relPoint` are two free absolute points with an Automatic default. The issue comment's
   `attach.edge` token is pre-v11; this design targets the two points. The issue is closed against 1
   and 2 with a comment saying so.

## Decisions (the issue's open questions)

| # | Question | Decision |
|---|---|---|
| D1 | Which pair a drop picks | The nearest of the **nine classified sides** (`C.ATTACH_EDGES`, after/ahead/behind x start/center/end) under the target's flow growth (`Anchors.EdgePoints`): for each side, the distance between the dragged anchor's child point and the target's relative point. A free pair is never picked by a drop; the point dropdowns still reach every pair. |
| D2 | Snap threshold | `C.SNAP_RADIUS = 24`, in UIParent units, between the two points. Nearest side of the nearest target wins; a tie keeps the first target in id order and the first side in `ATTACH_EDGES` order. |
| D3 | Visual feedback | While a candidate is in range: a highlight frame over the target's rect (2px edge, `C.SNAP_COLOR` green, `Style.DrawEdge` strips on a plain frame of ours under UIParent, no Backdrop) and a 6px marker on the join point. Hidden when nothing is in range, Shift is held, combat starts, or the drag ends. |
| D4 | Suppressing the snap | Holding **Shift** suppresses it (no highlight, no attach on drop). Read every tick and again at the drop. |
| D5 | Cycles | A target is eligible only when `Anchors.WouldCycle(dragged, target)` is false: a container can never snap onto itself or onto anything that follows it, directly or through a chain. |
| D6 | Detach | An attached container dropped with no candidate (or with Shift held) detaches: `container.position` is written from the drop (as a screen drag stores it today), then `container.attach` with `mode = "screen"` and `x = y = 0`. The target id and the two points stay stored, as a mode switch on the panel leaves them. |
| D7 | Attach write | One whole-section write of `container.attach`: `mode = "container"`, `container = <target id>`, `x = y = 0`, and the two points of the picked side, each stored **nil (Automatic) when it equals Automatic's point** for that child on that target, else the absolute point. `frame`, `point`, `relativePoint` are kept. `container.attach` joins Schema's `SECTIONS` (it was "deliberately absent: no caller writes it whole"; the drop is that caller). Each row's onChange still fires (fireSectionChanges), so the panel's flow notices and parent re-apply run unchanged. |
| D8 | Growth conflict (GC-1) | When `Anchors.FlowChangeOnAttach(cfg, target)` is non-nil, the drop re-places the container where its stored settings put it and asks with the existing `AURAMASTER_ATTACH_FLOW` popup, whose OnAccept writes the same section. Cancel leaves everything as it was before the drag. The popup stays in `settings/Layout.lua`; it publishes one seam, `NS.AttachByDrop(id, section)`, which asks or writes. |
| D9 | Which containers drag | Screen and container-attached ones, out of combat. Frame-attached containers still cannot be dragged (unchanged; out of scope). |
| D10 | X/Y offsets | Reset to 0 on attach and on detach (the issue comment). |
| D11 | Combat | No drag starts in combat (unchanged). If combat starts mid-drag, snapping stops (no highlight) and the drop does not attach: a screen container saves its position as today; an attached one is re-placed where its settings put it (no detach under lockdown, nothing written). |

## Mechanics

### Starting a drag (the attached case)

`canDrag` answers true for `mode == "container"` too. Before the widget calls `StartMoving` an attached
anchor must hang from UIParent, or the move starts from the parent's (possibly secret) geometry. The
widget asks `canDrag` immediately before `StartMoving` (`libs/LibKa0s/WidgetsDragHandle.lua`
`dhSetDragScripts`), so `canDrag` becomes `beginDrag(container)`: it answers the gate and, when the
answer is yes, re-anchors an attached anchor to UIParent:

- its `GetLeft()`/`GetBottom()` read plain (`NS.Secrets.CanAccess`): `BOTTOMLEFT` of UIParent at those
  offsets, so it does not move;
- either reads secret (it hangs from an engine holding auras): its center under the cursor
  (`GetCursorPosition()` over its effective scale). It jumps by at most its own size. Recorded in
  `docs/known-limitations.md`.

It sets `container.dragging = true` and starts the snap driver. `onDragStop` clears it.

### Holding the drag steady

`Anchors.Place` returns early while `container.dragging` is set (its points stay as the drag left them;
it answers `container.placedAs or "screen"`), so a visibility pass, a parent's hang-mode change
(`PlaceAttached`) or an apply cannot yank the anchor back mid-drag.

### The snap driver (new module `modules/Anchors_Snap.lua`)

Loaded after `modules/Anchors.lua`. One driver frame with an OnUpdate that runs only while a drag is
live, throttled to 0.03s. Each tick: if Shift is down or `InCombatLockdown()`, no candidate; else
`Snap.Find(dragged)`. It shows or hides the highlight.

- **Eligible targets**: every live instance (`NS.ContainerManager.instances`) that is enabled, not the
  dragged one, whose anchor is shown, and with `WouldCycle(dragged.id, target.id)` false.
- **The target rect**: the frame a follower hangs from in the target's hang mode, the one `targetFor`
  picks (preview extent, anchor for slot, else engine). Its rect read through `Secrets.CanAccess`; an
  unreadable engine falls back to the target's anchor (one element), and an unreadable anchor drops the
  target. Rects are converted to UIParent units (`value * frame:GetEffectiveScale() /
  UIParent:GetEffectiveScale()`).
- **The pure core**: `Snap.Nearest(childRect, candidates, radius)`, where `childRect` and each
  candidate's rect are `{ left, bottom, right, top }` in UIParent units and each candidate carries its
  growth; returns `{ id, token, point, relPoint, dist }` or nil. No frame access, so the headless
  harness tests it directly. `Snap.PointAt(rect, point)` gives a WoW point's coordinates on a rect.

### Dropping

`onDragStop` calls `Snap.Drop(container)` (replacing `Anchors.SavePosition` as the stop callback):

1. clear `dragging`, stop the driver, hide the highlight;
2. combat (D11): screen container -> `SavePosition`; attached -> `Anchors.Place`; done;
3. a candidate and no Shift -> build the D7 section and call `NS.AttachByDrop(id, section)`;
4. else screen container -> `SavePosition` (unchanged behaviour); attached -> D6 detach.

Every outcome writes a `[Anchor]` debug line (`drop: attach to <id> <token>`, `drop: detach`,
`drop: moved`, `drop: held (combat)`).

## Strings

The strip tooltip's how-to line (`tooltipSpec`, locale `enUS`):

- screen: "Drag to move. Drop it on another container to attach it there; hold Shift to place it
  without attaching. Right-click for settings."
- container-attached: "Attached to '%s'. Drag it away to detach it, or onto another container to attach
  it there; hold Shift to place it without attaching. Right-click for settings."
- frame-attached: unchanged.

The attached name color stays: it now means "attached", not "cannot be dragged"; the comments say so.

## Tests (headless, test-first)

`tests/test_anchors_snap.lua` (new): `Snap.Nearest` picks the nearest side under each of the four
growths; out of radius -> nil; ties; `PointAt` for all nine points. Eligibility: self, a follower and a
chain follower excluded; disabled and hidden excluded. Automatic folding: a side equal to Automatic
stores nil, another stores the absolute pair. `beginDrag`: screen and container true, frame false, combat
false; re-anchors a container-attached anchor to UIParent at its read position and under the cursor when
the read is secret. `Place` is inert while dragging. Drop: attach writes the section; GC-1 path calls the
popup and writes nothing; Shift detaches; detach writes position then mode screen with x/y 0; combat
drop of an attached container writes nothing. Schema: `container.attach` is a whole section and its rows'
onChange fire. Mock additions only in `tests/wow_mock.lua` (`IsShiftKeyDown`, `GetCursorPosition` if
absent).

## Docs

`docs/ARCHITECTURE.md` (module map, the drop path), `docs/module-map.md`, `docs/known-limitations.md`
(the secret-rect jump, the one-element fallback for an engine that reads secret), `README.md` usage,
`docs/smoke-tests.md` (new `DRAG-NN` cases under Layout, Pending sign-off), `docs/test-cases.md`
regenerated, README test badge.

## Out of scope

Dragging frame-attached containers; snapping to non-AuraMaster frames; picking a free pair by drop.

## Review corrections (DD-05)

The whole-branch review found these; the text above is left as decided, and these supersede it.

- **D7, the fold.** A drop picks a whole side, so its pair is folded whole: both points nil when the
  pair equals Automatic's, else both absolute. Folding each half on its own stored mixed pairs (ahead-start
  under right/down as `nil > TOPRIGHT`) that resolve to a degenerate pair once the parent's growth or a
  Text parent's justify changes Automatic (`TOPRIGHT > TOPRIGHT` under Grow Left). The panel's dropdowns
  still set one point each.
- **D8 and D11, the placement after a drop.** A drop places the container itself (`Anchors.Place`)
  whatever `NS.AttachByDrop` answers, and an attached container dropped in combat is re-placed at
  `PLAYER_REGEN_ENABLED` (`Snap.PlaceHeld`): ContainerManager holds applies while auras are secret as
  well as under lockdown (`CM.MustDefer`), so the apply a write queues cannot be relied on in a key.
- **A drag cut short.** A strip hidden mid-drag gets no OnDragStop, so the driver's tick cancels that
  drag once out of combat (stop moving, end the drag, place from the settings, nothing written), and
  `ContainerClass:Destroy` ends a drag still live.
