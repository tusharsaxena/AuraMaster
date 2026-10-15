# Text glow twins: technical design (TG-08, 2026-10-16)

- **Spec (binding):** `docs/superpowers/specs/2026-10-16-text-glow-addendum-glyph-glow.md`, which
  supersedes the halo parts of `docs/superpowers/specs/2026-10-15-text-glow-design.md`.
- **Plan:** `docs/superpowers/plans/2026-10-15-text-glow.md`, Addendum, items TG-09 to TG-14.
- **Line numbers** are those of `dfc4150`, the branch head this note was written on. This note is not
  in `test_docs`' citation check (it reads `docs/*.md` only), so the numbers are a snapshot. TG-11 moves
  lines that `docs/*.md` cites. It fixes those citations in the same commit (section 7).

## 0. The shape in one paragraph

A text container with `glow` on owns one main engine and `C.TEXT_GLOW_TWINS` twin engines. Each twin
is a `CustomAuraContainerTemplate` engine with the main's content, built in the same `Build` pass and
retired with it in the same `Retire`. Every twin is anchored to its own **holder**, a plain frame of
ours under the anchor. The holder is the anchor's rect shifted by the ring offset. Moving a holder
moves its twin, so a thickness or offset change re-points holders and builds nothing. Twin buttons
are dressed by the same `Text.Apply` as the main's, with a `twin` index that switches on the glow
dress. The preview gets addon-written copy strings per piece instead, dressed by the same glow-dress
function. Nothing outside `Container.lua` and the new `Container_Twins.lua` ever sees a twin.

## 1. Every touch of the main engine, and how the twins mirror it

`M` = mirrored on every twin, in the same pass, right after the main. `N` = main only, with the reason.
All mirrored sends go through `callEngine` (`modules/Container.lua:30-37`), so a refusal on a twin is
logged once and costs only that call, as on the main.

### Created, anchored, populated (`ContainerClass:Build`, `modules/Container.lua:388-450`)

| Line | Main engine | Twins |
|---|---|---|
| 391-393 | `CreateFrame("AuraContainer", nil, anchor, "CustomAuraContainerTemplate")`, stored as `self.engine` | M. Parent is holder k, not the anchor. Stored as `self.twins[k]` (section 2) |
| 399 | `applyFlow(engine, cfg)`: the five `SetFlowLayout*` calls (`:143-153`) | M. Same `flow` table, sent to each twin |
| 400-402 | `EngineOffset` → `ClearAllPoints` → `SetPoint(flow.anchorPoint, anchor, flow.anchorPoint, ex, ey)`, before the first group | M. Same call with **holder k** in place of `anchor`. Same `ex, ey`, also before the twin's first group |
| 406 | `SetSize(1, 1)` provisional rect | M |
| (new) | none today, with glow on: the main's level is decided and written here, after `SetSize` and before its first group (section 2) | M. Each twin's level is set in the same window on that twin, from the main's decided level |
| 408 | `init = function(frame) self:InitFrame(frame) end` | M with a twin init: `function(frame) self:InitTwinFrame(frame, k) end` |
| 409-421 | `ResolveView`, then `AddAuraGroup(g.key, filter, { initializeFrame, candidateFilters, sortMethod, sortDirection, maxFrameCount, layout })` per group | M. Same `view`, same `viewOf(g, view)` values, same `groupLayout(cfg, i)`. Only `initializeFrame` differs |
| 423-438 | Enchants: `SetItemEnchantmentSortMethod`, `SetItemEnchantmentLayout`, `AddItemEnchantment` per slot, frames kept in `self.enchantFrames` | M. The twin's enchant frames go in `self.twinEnchantFrames[k]`, never `self.enchantFrames` (whose count `ResetEnchants` and the `[Cont]` line read) |
| 442-443 | `SetUnit(cfg.unit)` last; `self.unit` | M. Each twin's unit is last **on that twin** |
| 444-449 | `enchantDir`, `plan`, `structure`, `viewStale = nil`, `NoteView` | Shared container state, set once. It describes what every engine of the container holds |

Order inside `Build`: the main is built completely first (create … `SetUnit`), then twin 1 … twin N.
Each engine keeps its own order: anchored, sized and leveled before its first group, its unit last.
The main's level is decided inside the main's own build, in the window before its first group, and
never after: a live engine forbids untrusted layout work (`Build`'s anchoring comment, `:397-398`, and
`Retire`'s, `:207-208`) and might
refuse a level change (`ApplyBlocker`'s comment, `:228-231`). The main goes first so that this
decided level exists before the twins' levels are derived from it (section 2).

### Updated in place (`ContainerClass:Update`, `modules/Container.lua:469-499`)

| Line | Main engine | Twins |
|---|---|---|
| 475 | `applyFlow` | M |
| 477-489 | Per group: `sendGroupView` (`:320-332`) against the old plan's group and `self.view`, `SetAuraGroupSortMethod` when it moved, `SetAuraGroupMaxFrameCount` when it moved, `SetAuraGroupLayout` always | M. The same diff decides for every engine, because every engine holds the same old plan in the same view. `ok` is AND-ed over all engines, so one refused send leaves `viewStale` set and the next switch resends to all |
| 490, 455-467 | `updateEnchants`: `SetItemEnchantmentLayout` always; the sort only when `cfg.filter.sortDirection` moved, then `self.enchantDir` is recorded | M. The "moved" test is taken **once**, before any engine is sent, and the direction is recorded after the last engine. If the main recorded it first, the twins would never get the change |
| 491-494 | `SetUnit` when `self.unit ~= cfg.unit` | M. Same test, taken once; `self.unit` written after the last engine |
| 495-497 | `plan`, `viewStale`, `NoteView` | Shared, once |
| 498 | `self:Restyle(cfg)` | M, inside `Restyle` (below) |

To keep `Update` under CCN 15, its per-engine body moves into a local
`updateEngine(engine, cfg, plan, old, view, oldView, stale, moved)`, which returns `ok`. `Update`
calls it for the main and then for each twin. `moved` carries the enchant direction and the unit
decisions. `updateEnchants` splits the same way: deciding stays in it, and the sends move to a
per-engine helper.

### Re-viewed (`ContainerClass:ApplyView`, `modules/Container.lua:366-386`)

`sendGroupView` per group (`:380-382`) is mirrored: the same `view`, `was` and `stale` go to every
engine, and `ok` is AND-ed. This runs in combat and while secret, as on the main. The two setters are
the ones Blizzard does not gate, and a twin is the same template. Callers that need no change:
`CM.ApplyViews` (`modules/ContainerManager.lua:431-439`), which runs from `onViewEvent` and
`onPlayerViewEvent` (`:791-805`) and from the `view` effect (`:872`).

### Re-unit'd and refreshed

- **Unit write.** Covered by `Update` (above). An apply is the only path that changes `cfg.unit`.
- **`ContainerClass:Refresh`** (`modules/Container.lua:855-857`, `UpdateAllAuras`): M. Its callers are
  `CM.RefreshUnit` (`modules/ContainerManager.lua:404-418`, which is fed by
  `addon:OnUnitSwap`, `core/AuraMaster.lua:172-178`, and the pet path, `:189`) and the font primer's
  refresh (`modules/FontPrimer.lua:185-189`). The primer's gate reads `inst.engine` only (a twin
  never exists without its main), and its refresh reaches the twins through `Refresh`.

### Restyled (`ContainerClass:Restyle`, `modules/Container.lua:509-528`)

The walk over `GetAuraGroupFrameCount` and `GetAuraGroupFrame` per plan group (`:513-522`), plus the
enchant frames (`:523-526`), is mirrored. Each twin's buttons are re-dressed with
`redress(frame, cfg, self.classColor, k)` (`:503-506`, which gains the `twin` argument). The returned
count stays the **main's** button count, which is what `tests/perf.lua`'s `restyle` scenarios
measure. The walk moves into a local `restyleEngine(engine, plan, frames, cfg, classColor, twin)`,
because `Restyle` is already CCN 10.

### Shown, hidden, enabled, disabled

| Where | Main engine | Twins |
|---|---|---|
| `ApplyLive` (`modules/Container.lua:696-699`) | `SetEnabled(on)` | M. This one call is every hide path in the spec: General visibility, the zone gate, the Unit type gate, a disabled container, test mode, the stand-down, a parked id (`ShouldShow`, `:665-673`, via `ApplyVisibility`, `:825-852`). EmptyWatch has no hide of its own |
| `Flip` (`:865-873`) | `SetEnabled(false)` then `SetEnabled(true)` | M, after the main's pair. `ResetEnchants` (`:881-885`) is a `Flip`, gated on `#self.enchantFrames` (the main's, unchanged). `/am redraw light` and `full` (`modules/ContainerManager.lua:550-579`) run through `Flip` |
| `Park` (`:892-902`) | `SetEnabled(false)` | M |
| `Retire` (`:203-216`) | `SetEnabled(false)`, `Hide()`, appended to `self.retired`, fields cleared | M. Twins go to `self.retiredTwins`, never `self.retired`, so `#inst.retired` keeps meaning main engines (`test_container`, `test_redraw`, `test_enchantreset` and the `[Cont]` line's `retired=` all read it). `self.twins` and `self.twinEnchantFrames` are cleared. **Holders are kept** for the next build |
| `Destroy` (`:913-928`) | through `Retire` (`:919`), then `anchor:Hide()` | M through `Retire`. The holders are children of the anchor and hide with it |
| `ApplyAnchorShown` (`:685-693`) | the anchor only | Nothing to add: holders and twins are descendants of the anchor |

### Re-anchored

The main engine is never re-anchored after its first group: `Retire`'s comment, and the "one exception"
in the file header. Twins are not re-anchored either. Their **holders** are re-pointed in `Apply`, which
`ContainerManager` holds out of combat and secrecy (`CM.MustDefer`, `modules/ContainerManager.lua:217-219`).
The anchor's own moves (`Anchors.Place`, drag, snap) carry the holders, because each holder is pinned
to the anchor by two points.

### Read (main only, and why)

| Where | Read | Twins |
|---|---|---|
| `ApplyBlocker` (`modules/Container.lua:232-247`) | `GetFrameLevel` (`:240`), `SetAllPoints(engine)` (`:245`) | N. The blocker closes the gaps between the **main's** buttons for the hover. Twin buttons take no mouse, so nothing needs blocking under them. The blocker sits at main level − 1 (E − 1, section 2). That is above every twin engine frame (E − 3) and holder, but not above a twin's own frames: its button at E − 2, clip E − 1, anim E, area E + 1 and chain E + 2 sit at or above the blocker. This is harmless, because the blocker draws nothing and a twin button takes no mouse, so the blocker neither hides a twin nor loses a hover to one |
| `Anchors.HangFrame` (`modules/Anchors.lua:143-148`) | `t.engine or t.anchor` | N. A twin is never a hang target (spec: never joins the attach chain's geometry). A twin's rect is the main's rect plus at most 26 px, so hanging from it would shift every follower |
| `Anchors.Place` (`modules/Anchors.lua:324`) | `target == owner.engine` | N, same reason. `engineLead` (`modules/Anchors_Attach.lua:323`, `:369-370`) reads the main's lead |
| Snap and drag (`modules/Anchors_Snap.lua`) | through `HangFrame` and the anchor | N. No engine read of its own (grep), so nothing to exclude |
| Frame picker (`modules/FramePicker.lua:64`) | `NamedAncestor(GetMouseFocus())` | N. A twin button takes no mouse, so it is never the focus |
| `EmptyWatch` `poolOf` (`modules/EmptyWatch.lua:161-166`, `:177`) | `inst.engine:GetAuraGroupFrameCount` | N. The prediction is about the main. A twin's pool mirrors it anyway |
| Diagnostics `instFlags` (`modules/Diagnostics.lua:374-385`) | `yesno(inst.engine)`, `#inst.retired`, `#inst.enchantFrames` | N for those fields. **Add `twins=N`** (`#inst.twins`, 0 when off) to the `[Cont]` line, so a smoke run can see that the twins exist. It is not a count of visible auras |
| Diagnostics `frameCounts` and `groupButtons` (`:515-532`, `:671-688`), `shownLines` (`:757`) | the main's buttons | N. These are the "visible auras" counts the spec keeps twins out of |
| `ContainerManager` (`modules/ContainerManager.lua:97, 127, 131, 141, 299, 317, 408, 435, 492, 553`) | instance methods only, never `inst.engine` | Nothing to change: every call lands in a mirrored method above |

## 2. Offsets and frame levels

### The ring

```
C.TEXT_GLOW_RING    = { {1,0}, {0,1}, {1,1}, {1,-1}, {-1,0}, {0,-1}, {-1,-1}, {-1,1} }
C.TEXT_GLOW_PAIRED  = true                       -- the twin4s outcome (owner probe, 2026-10-16)
C.TEXT_GLOW_TWINS   = C.TEXT_GLOW_PAIRED and 4 or 8
C.TEXT_GLOW_LEVEL_GAP = 3                        -- below
```

Twin k (1 ≤ k ≤ `C.TEXT_GLOW_TWINS`) takes `d_k = RING[k]`. Under pairing, the first four directions
are one of each opposite pair, and each twin's shadow draws the opposite one (section 3). Without
pairing, all eight are twins. Flipping `C.TEXT_GLOW_PAIRED` is the one-line change the spec asks for.

### Where the offset is applied

```
anchor ─┬─ main engine     SetPoint(flow.anchorPoint, anchor,   flow.anchorPoint, ex, ey)   (Build, :400-402)
        └─ holder k        SetPoint("TOPLEFT",     anchor, "TOPLEFT",     ox_k, oy_k)
           │               SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", ox_k, oy_k)
           └─ twin k       SetPoint(flow.anchorPoint, holder k, flow.anchorPoint, ex, ey)
ox_k = glowThickness × d_k.x + glowX        oy_k = glowThickness × d_k.y + glowY
```

- `ex, ey` is `NS.Container.EngineOffset(flow.growH, flow.growV)` (`modules/Container.lua:129-132`),
  computed once in `Build` from the same `applyFlow` result. The twin also takes the same
  `EnginePadding` through `applyFlow`. So relative to the anchor, twin k sits at exactly the main's
  place plus `(ox_k, oy_k)`, on any growth corner, and an empty twin has the main's `ENGINE_LEAD`
  geometry.
- The holder has the anchor's rect because it is pinned by two points. `Anchors.Place` sizes the
  anchor from `ElementSize` (`modules/Anchors.lua:315-316`), and a holder follows every later resize
  and move with no call of ours.
- `Twins.Place(self, cfg)` re-points every holder. It runs from `Apply` right after the
  Build-or-Update branch (`modules/Container.lua:558-563`), on every apply, so a thickness, X or Y change
  re-places the ring with no rebuild. It also re-levels the holders (section 2, frame levels).
  `Apply` never runs in lockdown, so a holder (the ancestry of an aura engine) is never moved in combat
  (events-frames-taint-§2).
- A holder is created with `CreateFrame("Frame", nil, anchor, "DisableUntrustedLayoutScriptsTemplate")`,
  the anchor's own template (`:45-46`). An engine is pinned to the holder, and the template keeps the
  holder acceptable to the engine whatever Blizzard checks on the relative frame. One holder per k per
  container, built on first need and kept for the container's life, as the blocker is (`:236-239`).
  Frames are never freed.

### Frame levels

A text element nests our frames under the engine's button B: `clip` B+1, `anim` B+2 (the icon
texture), `area` B+3 (the dispel backdrop and edges; `iconBorder` is also B+3, on `anim`), and `chain`
B+4 (the font strings) (`modules/Style_Text.lua:131-152`, `:167-177`). Each is a `CreateFrame` child,
so it sits one above its parent. The offset between the main's tree and a twin's tree is therefore the
same at every depth: the gap between the two engines. For the twin's text (its chain, Bt+4) to draw
under the main's icon (Bm+2), the gap must exceed 2. The gap is 3.

The level is decided in two places, each in the window before its engine's first group.

**On the main, in `ContainerClass:Build`.** With glow on, right after the main's `SetSize(1, 1)` and
before its first `AddAuraGroup`, `Build` calls `NS.ContainerTwins.LevelMain(self, engine, cfg)`. That
is one call and no branch in `Build`. It returns E, or nil with glow off, and writes nothing then:

```
A  = guarded read of the anchor's level:                                (Apply sets it, :545)
       local ok, v = pcall(anchor.GetFrameLevel, anchor)
       A = ok and NumberOr(v, stored layout.level) or stored layout.level
E  = max(A + 1, GAP + 1)                         -- layout.level min is 1, so E is 4 or more
if not callEngine(main, "SetFrameLevel", E) then  -- pre-group, guarded and logged once
    local ok, v = pcall(main.GetFrameLevel, main) -- the ApplyBlocker form (:240-242)
    E = ok and NumberOr(v, A + 1) or A + 1
end
```

The anchor read takes the `ApplyBlocker` form, `pcall` plus `NS.Secrets.NumberOr`, because a level
is a `SecretAspect` on an attachable frame (`docs/midnight-quirks.md:555-563`). The stored-level
fallback is the one `levelOf` uses (`modules/Anchors.lua:689-692`). The main's level is **written**
with glow on, not read and trusted, so E does not rest on the mock's parent + 1 assumption
(`tests/wow_mock.lua:186-195`). The write goes through `callEngine`, so a refusal costs that one call
and is logged once. The only read of the main's level is the fallback after a refused write, and it is
guarded the same way. With the default `layout.level` of 5, E = 6. At a stored level of 1 or 2,
E = 4, which raises the main above A + 1. `ApplyBlocker` reads the main's current level
and so follows it (`:240-243`). `Build` hands E to `Twins.Build`.

**On each twin, in `Twins.Build`.** It only reads E. It never touches the main:

```
twin k:SetFrameLevel(E - GAP)        holder k:SetFrameLevel(max(0, E - GAP - 1))
```

The twin's write lands in the same pre-group window as its `SetPoint` and `SetSize`, through
`callEngine`. The holder is ours and takes a plain write.

- **Strata.** The twins inherit the anchor's strata (`:544`). They are never set apart.
- **A later `layout.level` change (unprobed risk).** It re-levels the anchor (`:545`) with no rebuild.
  The two trees have **different depths**: the main engine is a child of the anchor, while twin k is a
  grandchild (anchor → holder k → twin k). Nothing in this repo verifies whether the client re-bases
  existing descendants on a re-level. The mock's note calls its answer an assumption
  (`tests/wow_mock.lua:186-195`), and `ApplyBlocker`'s comment (`modules/Container.lua:225-228`) says
  the engine does not follow the anchor. If the client does not re-base, every level stays where `Build`
  put it and the gap holds. If it clamps each descendant to its parent + 1, raising `layout.level` from
  5 to 20 puts the main at 21, holder k at 21 and twin k at 22, so the glow draws over the main's text
  and icon.
- **Decision: `Twins.Place` re-levels the holders on every apply.** It reads the main's current level
  (the guarded `ApplyBlocker` form, skipped when unreadable) and sets each holder to
  `max(0, level - GAP - 1)`, as `ApplyBlocker` re-levels the blocker. A holder is ours, so this is a
  plain write. It never writes a twin engine, which is live by then. When the client re-bases nothing,
  this changes nothing. When it re-bases on the anchor's change, the main's new level is read and the
  holders are put back under it, so a twin that follows its holder is put back too. The case it cannot
  mend is a client that re-bases on the anchor's change but not on a holder's. The R2 smoke step decides
  it. If the glow then draws over the text, the fallback is to add `layout.level` to the structure key
  while glow is on, so a level change rebuilds. That costs five engines per change and needs an owner
  decision (Q4).
- The mock answers a child's level as its parent's + 1 at creation. Every level the gap depends on is
  written explicitly, so no test leans on that assumption. The re-level case is tested on the holders'
  recorded writes, not on any re-base by the mock.

## 3. The glow dress through `Style.Element` → `Text.Apply` → `Text.Bind`

### Signatures

| Function | Today | After |
|---|---|---|
| `Style.Element` (`modules/Style.lua:844-854`) | `(frame, cfg, engine, classColor)` | `(frame, cfg, engine, classColor, twin)`. `twin` is nil or the twin index k. A fifth upvalue, `dressTwin`, is set and cleared with the others (`:848`, `:850`), and `runDress` (`:821-823`) passes it on |
| styler `Apply` | `Text.Apply(frame, cfg, engine)` (`modules/Style_Text.lua:562-579`) | `Text.Apply(frame, cfg, engine, twin)`. `Bars.Apply` and `Icons.Apply` ignore the extra argument. A twin exists only on a text container, because the structure key carries the style |
| `Text.Bind` (`:534-542`) | `(frame, am, cfg, s, compiled)` | `(frame, am, cfg, s, compiled, twin)` |
| `BINDERS[kind]` (`:521-531`) | `(frame, fs, piece, s, am)` | `(frame, fs, piece, s, am, twin)`. Only `dispel` and `duration` read it |
| `redress` (`modules/Container.lua:503-506`) | `(frame, cfg, classColor)` | `(frame, cfg, classColor, twin)` |
| `ContainerClass:InitTwinFrame(frame, k)` | new | `if cfg then NS.Style.Element(frame, cfg, true, self.classColor, k) end`, beside `InitFrame` (`:159-162`) |

### `Text.Apply` with a twin (the same path, a flag)

The step order is unchanged. Size, the chain, the icon-and-area layout, the clip, the justify, the
offsets and the loops are all identical, because they read only `cfg`, and `cfg` is shared:

1. `ElementSize`, `RegionsFor`, `ClearAdditiveBindings` (engine), and `frame:SetSize(w, h)`. A button
   with no size is never placed (owner probe), so this stays first.
2. `useChain`, `layoutIconAndArea`, `applyClip`: unchanged. The icon and border are laid out so the
   area sits exactly where the main's does. **Then, for a twin, `am.icon:Hide()` and `am.iconBorder:Hide()`.**
   This goes in `Text.Apply`, not in `layoutIconAndArea`, which is CCN 11 and stays untouched.
3. `dressPieces(am, s, compiled, twin)`: a twin's font goes through `Text.GlowFont(fs, s, k)`
   (section 3, below) in place of `Style.ApplyFont`. Literals take their text as on the main.
4. `layoutChain`: unchanged. The chain pull is `Style.PiecePadding(s.font)` (`:325`), read from the
   settings and not the font string, so the twin's pieces take the main's pull. (Risk R1.)
5. `dressDispelTints`: unchanged. It hides the backdrop and the four strips on every dress.
6. `Text.Bind(..., twin)` (engine only).
7. **`Text.GlowCopies(am, s, compiled, engine)`** replaces the `Text.Glow` call (`:577`). It dresses the
   preview copies (section 4) when `engine` is false. It hides any copies otherwise.
8. `applyLoops`: unchanged, so a twin plays the main's loop with the main's timing (and the documented
   phase limit).

### `Text.Bind` with a twin

| Step | Main | Twin |
|---|---|---|
| `SetIcon` (`:535`) | bound when the icon is on | **not bound**. The texture stays hidden and empty |
| `name` | `SetSpellName(fs)` | the same |
| `stacks` | `SetApplicationCount(fs, stackOptionsFor(piece))` | the same (same formatter, so "" below 2 on both) |
| `dispel` | `SetDispelTypeText(fs, dispelOptionsFor(piece, s))` | `dispelOptionsFor(piece, nil)`. `wordPalette(nil)` is nil, so the plain-word map is used and no `\|c` escape tints a glow word. No new options table, because the memo keys plain maps under `"p"` (`:445`) |
| `duration` | `BindDurationFormat(frame, fs, textFormat, bindingFor(am, blink), s, D, CurveColor(font))` | `BindDurationFormat(frame, fs, textFormat, bindingFor(am, false), NO_RUN, D, nil)`, where `NO_RUN` is a constant empty table. `runTextColor(NO_RUN, …)` (`modules/Style.lua:966-974`) answers nil, so no `textColor` is sent and the color `GlowFont` set stands. Same `textFormat`, so the same digits. The plain binding, because the twin has no blink refresh to drive (Question Q2) |
| `dispelTints` (`:540`) | the backdrop and edges handed to `AddDispelTypeTexture` when on | **skipped** |
| behavior (`:541`) | `Style.ApplyBehavior(frame, cfg)` | **`Text.TwinBehavior(frame)`**: `SetMouseMotionEnabled(false)`, `SetMouseClickEnabled(false)`, `Style.Bind(frame, "SetCancelAuraButtons", nil)`. No tooltip anchor, no hide-in-combat |

### `Text.GlowFont(fs, s, k)` (`modules/Style_TextGlow.lua`, pure over a font string)

- **Face and size.** These come from `Style.FontKey(s.font or D.font, D.font)` (`modules/Style.lua:1020-1024`).
  The flags drop `OUTLINE` and `THICKOUTLINE` and keep `MONOCHROME`: `"OUTLINE"` → `""`,
  `"THICKOUTLINE"` → `""`, `"MONOCHROME,OUTLINE"` → `"MONOCHROME"`. The `SetFont` fallback is the
  one `ApplyFont` uses (`:126`).
- **Color.** `Style.Color(s.glowColor or D.glowColor, s.useClassColorGlow)`, with alpha × `glowIntensity`.
  Inside a dress, `Style.Color` reads the dress's class snapshot. `Style.UsesClassColor` already sees
  `useClassColorGlow` through its `useClassColor` prefix scan (`:75-80`, `:98-108`), so a tracked unit's
  class swap re-applies a glowing container with no new code.
- **Shadow.** When `C.TEXT_GLOW_PAIRED` is on: `SetShadowColor(r, g, b, a × intensity)` and
  `SetShadowOffset(-2·t·d_k.x, -2·t·d_k.y)`, where t = `glowThickness`. Relative to the main, the shadow
  then lands at `-t·d_k + (glowX, glowY)`, the opposite point of the ring. When pairing is off:
  `SetShadowOffset(0, 0)`. The font's own `fontShadow` never reaches a twin.
- The same function dresses the preview copy j (section 4) with `k = j`, so the live look and the
  preview look cannot differ.

## 4. The preview copies in `Text.FillPreview`

A placeholder writes its own text, so its ring is made of plain copy strings. These are dressed exactly
as twin k would be.

- **Regions.** `am["glow" .. i]` for piece i is an array of `C.TEXT_GLOW_TWINS` font strings, built
  lazily on first need with `am.anim:CreateFontString(nil, "BACKGROUND")` and kept. They sit on
  `anim`'s BACKGROUND, under the icon (`anim`'s ARTWORK) and under the `area` and `chain` child frames,
  which is the same stacking a live twin gets from the level gap (section 2). They are on `anim`, so
  they move with the loops. The key keeps the `glow<N>` shape that `tests/test_render_coverage.lua`'s
  `isGlowSet` already matches (`:154-156`). Its `glowParts` walks a nine-part set today and becomes an
  array walk. `am.glowCount` keeps the highest piece index built, as today.
- **Dress** (`Text.GlowCopies`, called from `Text.Apply` with `engine` false): when glow is on, every
  copy of each piece 1 … `am.pieceCount` takes `Text.GlowFont(copy, s, j)`, `SetJustifyH` of its
  piece, and two points:
  `SetPoint("TOPLEFT", piece, "TOPLEFT", ox_j, oy_j)` and the same for BOTTOMRIGHT, with
  `ox_j = t·d_j.x + glowX`, `oy_j = t·d_j.y + glowY`. A placeholder's piece has a readable rect, so the
  copy takes its bounds. A stacked line's literal pieces are hidden, and so are their copies. Every
  copy past `pieceCount`, and all of them while glow is off, or on an engine button, is hidden.
  Pieces are re-fetched every dress, because `useChain` swaps strings on a shape change.
- **Fill** (`Text.FillPreview`, `modules/Style_Text.lua:661-675`): after each field's
  `fs:SetText(...)`, every shown copy takes the same text, except that a dispel piece's copies take the
  uncolored word (`dispelWord(piece, aura.dispel, nil)`), as the live twin is bound without a palette.
  `previewRunColor` (`:632-637`) is never applied to a copy. Literal copies take their text in the dress
  (step 3 above). A stacks text under 2 is "" on the copies too, so no glowing dot appears: a font
  string that is "" draws nothing.
- `Text.PreviewLine` (the Text section's Preview box) and the unlocked outline (a box with no text) get
  no glow.
- **Count.** It is `C.TEXT_GLOW_TWINS`, so 4 copies with shadows under pairing, or 8 without. The spec's
  "twice that without pairing" is read as twice the paired 4, which is the unpaired value of the same
  constant (Question Q3).

## 5. Structure key and restyle rules

| Change | Effect | Where |
|---|---|---|
| `glow` on or off | **Rebuild**: the main engine and its twins are retired together, and the new main is built with twins only when on | `Style.StructureKey` (`modules/Style.lua:802-806`) becomes `"text:" .. shape .. (s.glow and ":glow" or "")`, so it flows into the container key (`modules/Container.lua:556-557`) |
| `glowThickness`, `glowX`, `glowY` | **Update**: holders re-pointed (`Twins.Place`), plus the twin restyle that moves each twin's shadow offset | `Apply` → `Update` → `Restyle`, then `Twins.Place` |
| `glowColor`, `useClassColorGlow`, `glowIntensity` | **Update**: only the twins' buttons and the preview copies change look | `Restyle` mirror, and `previewDirty` (`:571`) |
| font, template of the same shape, justify, offsets, icon, size, animation, time format | Update on the main and every twin alike | the existing rules |
| a class swap on a tracked unit | re-apply, as today | `CM.RefreshUnit` with `usesClass` |

Every glow row keeps the default apply effect. A change in combat or while auras are secret waits for
the flush (`CM.MustDefer`), and the build runs only where an apply may run, with the startup exception
(`mustHold`, `modules/ContainerManager.lua:330-333`). A container whose style is not text never builds
twins, even if a stale `text.glow` leaf is true. `Twins.Build` checks `Style.StyleKey(cfg) == "text"`
and the leaf.

## 6. Test plan

Each case is written test-first with a true `-- red under:` note.

| Item | Suite | Cases |
|---|---|---|
| TG-09 | `test_defaults`, `test_schema`, `test_schema_paths`, `test_pages_text`, `test_locale`, `test_docs`, `test_migrations` (none expected: the branch is unmerged) | the new leaf `glowThickness = 2` (1-6, step 1) and `glowIntensity = 0.55`. `glowRadius`, `glowBlend`, `glowFalloff` and `C.TEXT_GLOW_BLENDS`, `_FALLOFFS` and `_TEXTURES`, with their labels and locale keys, are gone. The rows are Glow, color pair, Intensity, Thickness, Offset X and Offset Y, and every row but the color pair dims while off. `docs/schema.md`'s `text` paragraph names the new set (`test_docs` `:378` today names `glowFalloff`) |
| TG-10 | `test_style_text_glow` (rewritten) | `GlowFont`: color × intensity; class color through the dress snapshot; flags with the outline dropped and MONOCHROME kept; the paired shadow at −2·t·d_k in the glow color; no shadow when unpaired (flip the constant in the case). Twin `Text.Apply`: same `SetSize` and same piece points as a main dressed from the same cfg; icon and border hidden and `SetIcon` never bound; no `AddDispelTypeTexture`; the dispel map holds no `\|c`; the duration bound with no `textColor` even with `expiringColorOn` and `expiringBlink` on; mouse off, `SetCancelAuraButtons` nil, no tooltip binds; a literal's text set; the main's loop played. Preview copies: count per piece, BACKGROUND on `anim`, the same text as their piece, the plain dispel word, no run color, hidden while off, past `pieceCount`, on a stacked literal and on an engine button; a re-dress after a shape change re-anchors them to the new strings |
| TG-10 | `test_render_coverage` | the glow rows each move a copy's recorded state. `isGlowSet` and `glowParts` walk the copy arrays |
| TG-10 | `test_preview` | a glowing text container's placeholders carry shown copies, and a non-glowing one's carry none |
| TG-11 | **`test_container_twins`** (new, listed in `tests/run.lua`) | built only for a text container with glow on (none for bars or icons with a true leaf, and none with glow off). `C.TEXT_GLOW_TWINS` engines: each anchored to its holder before its first group, its unit last; the main's `AddAuraGroup` arguments with only `initializeFrame` different; the same flow calls and enchant slots. Holder k's two points at `t·d_k + (x, y)`, and the twin's own point equal to the main's `ex, ey`. With glow on, the main's `SetFrameLevel(E)` recorded before its first `AddAuraGroup`, E = 6 at `layout.level` 5 and 4 at 1 or 2, and no main level write with glow off (red under: the raise taken in `Twins.Build`, after the main's groups). A refused main write falls back to the guarded read. Twin level E − 3 before each twin's first group, and holder levels E − 4 |
| TG-11 | `test_container_twins` (mirroring) | a filter, sort, cap or layout change sends the main's calls to every twin; an enchant direction change reaches every twin (red under: recording `enchantDir` after the main); a unit change; `CM.ApplyViews` switching every twin; `CM.RefreshUnit`; `ApplyLive` through test mode, the stand-down, a zone, the Unit type gate and a disabled container; `Flip` (redraw light) and `ResetEnchants`; `Park`; delete → `Destroy` (twins disabled and hidden, `#inst.retired` unchanged by the twins, `retiredTwins` filled) |
| TG-11 | `test_container_twins` (lifecycle) | the glow toggle rebuilds; a thickness, X or Y change re-points the holders and keeps the same engines; a `layout.level` change re-levels every holder from the main's current level, writes no engine level and keeps the same engines; a color or intensity change re-dresses twin buttons in place; a glow toggle in combat or while secret waits for the flush |
| TG-11 | `test_container_twins` (kept apart) | twin buttons have the mouse off; `Anchors.HangFrame` is the main; `EmptyWatch` reads the main's pool only (a twin pool with frames changes nothing); the Diagnostics shown counts read the main; the blocker covers the main; the `[Cont]` line carries `twins=4` |
| TG-11 | `test_diagnostics` | the `[Cont]` format with `twins=` |
| TG-11 | `test_loadorder` | `modules\Container_Twins.lua` under its note, after `Container.lua` |
| TG-11 | `test_perf` and `tests/perf.lua` | the stand-down disables every engine in `mocks.__engines`, twins included (the existing loop at `test_perf.lua:65` covers it once a glowing container exists in the scenario); a `restyleTextGlow` scenario |
| TG-11 | the existing `test_container`, `test_redraw`, `test_enchantreset` and `test_anchors*` | unchanged: glow is off by default, so no twin exists there |

**Mock.** No change is expected in `tests/wow_mock.lua`. Twin engines are `CreateFrame("AuraContainer")`,
so `makeEngine` records them, and `mocks.__engines` lists them. That is "the engine recorder carries the
twins". `SetFrameLevel` and `GetFrameLevel` are recorded on every frame. If a case needs to tell twins
apart, it reads `inst.twins[k]` and never adds a mock field.

## 7. Size, CCN and where the code lives

| File | Now (lines) | After (estimate) | What changes |
|---|---|---|---|
| `modules/Container.lua` | 928 | ~990 | `updateEngine`, `restyleEngine` and enchant-send helpers; mirrored loops in `ApplyView`, `ApplyLive`, `Refresh`, `Flip`, `Park` and `Retire`; `InitTwinFrame`; `Twins.Build` and `Twins.Place` calls |
| `modules/Container_Twins.lua` (new) | — | ~170 | `NS.ContainerTwins`: the ring offsets, `LevelMain(self, engine, cfg)`, holders (create, level, place, re-level), `Build(self, cfg, plan, view, flow, level)` per twin, `Each(self, fn, ...)`, `Retire(self)` and `Count(self)`. Peers resolved at call time; TOC right after `Container.lua` with a `# Conventional:` note |
| `modules/Style_TextGlow.lua` | 189 | ~150 | rewritten: the nine-slice sets go; it holds `GlowFont`, `TwinBehavior` and `GlowCopies`, plus a new header. It stays after `Style_Text.lua` (load-bearing, unchanged) |
| `modules/Style_Text.lua` | 857 | ~885 | the `twin` threading in `Apply`, `Bind`, `BINDERS` and `dressPieces`; the copy fill in `FillPreview` |
| `modules/Style.lua` | 1024 | ~1030 | `Style.Element`'s fifth argument; `StructureKey` with glow |
| `modules/Diagnostics.lua` | 799 | ~800 | `twins=` |
| `core/Constants.lua` | — | ±0 | the ring, pairing, twins and gap constants replace the three removed tables |

Every file stays well under the 1500 cap. CCN watch, from lizard at `dfc4150`: `ContainerClass:Apply`
is 12 and gains one call with no branch. `Restyle` is 10, and its walk moves out. `Build` is 9: the level decision lives
in `Twins.LevelMain` and the twin loop in `Twins.Build`, so `Build` gains two calls and no branch. `Update` is 8: its body moves to `updateEngine`.
`Text.Apply` is 4 and gains two branches. `Text.Bind` is 5 and gains three, which is still well
under 15. `Text.FillPreview` is 8 and gains one call. `Style.Element` is 5 and gains none.
`layoutIconAndArea` (11) and `Preview.Show` (6) are untouched.

**Docs to move with the code (TG-11 and TG-12).** These citations move with `Container.lua` and
`Style.lua` line shifts: `docs/ARCHITECTURE.md:18, :242`; `docs/common-tasks.md:31`;
`docs/data-flow.md:34, :47, :188, :192, :197`; `docs/midnight-quirks.md:55, :142, :163, :219, :314, :449, :588, :694, :716, :721, :801`;
`docs/performance.md:111, :113`. `test_docs` fails on any stale one. The ARCHITECTURE module count
("23 modules") becomes 24. `docs/module-map.md` gains the new file. TG-12 also covers
`docs/known-limitations.md` (the spec's four limits, with the paired-shadow clip of R4 in the
clipping entry, plus R1), `docs/midnight-quirks.md` (twin engines,
`CreateFontString` takes no sublevel, a button is placed only once sized, the colorless Slug
outline) and `docs/smoke-tests.md`.

## 8. Questions and risks for the reviewer

- **Q1. The diagonal's length.** `RING` uses (±1, ±1) per axis, so a diagonal twin sits t·√2 out, a
  square ring. The probe said "a ring direction × 2 px" and did not say whether diagonals were rounded
  to (1.41, 1.41). The constant is one line either way. The smoke check should look at the corners of
  a large font.
- **Q2. Blink.** Per the spec, a twin's duration gets no curve. Under `expiringBlink`, the main's time
  blinks while its glow stays lit. The alternative stays inside "never turns red":
  `blinkCurveFor(threshold, glowRGBA, glowRGBA)` on the twin, with the blink binding, so the glow blinks
  with its text. This needs a memoized glow color table per (color, intensity), because the curve memos
  key by table identity. It is the orchestrator's call. Default: the spec, which is no curve.
- **Q3.** The preview copy count (section 4) follows the reading given there.
- **Q4. Holders, not rebuilds.** The spec allows "rebuilds or re-anchors". Holders make a slider drag
  on X, Y or Thickness cost no engine frames. Rebuilding would leak five engines per coalesced apply,
  and frames are never freed.
- **R1. Outline width drift.** The twin draws without the outline. If the client widens an OUTLINE
  string's advance, a twin's chained pieces 2 … n drift back by that much per piece, and a long
  multi-piece line would show its ring off-center toward the end. A stacked Center line and a
  one-piece line cannot drift. The smoke check: a three-piece Left line with OUTLINE, looked at on its
  last piece. If it drifts, the fallback is to keep the twin's outline flag (its rim is black, the
  colorless Slug outline) and accept a darker glow. That change would need an owner decision.
- **R2. `SetFrameLevel` on an engine before its first group** has not been probed. `SetPoint` and
  `SetSize` in the same window are proven. Smoke: the glow stays under the icon and under the
  main's text at `layout.level` 1 and at 5. Then, with glow on and no rebuild, change Frame level
  from 5 to 20 and check that the glow still stays under the main's text and icon. This decides the
  re-level risk in section 2 (a client that re-bases descendants per parent would put the twins
  above the main).
- **R3. A holder as the engine's relative frame** has not been probed (the probe's twins hung from the
  same parent as the main). Smoke: a thickness slider moves the ring live, out of combat, with no
  `/reload`, and the ring follows a drag of the container.
- **R4.** The spec's limits stand: N extra engines each with their own UNIT_AURA work (a perf run owed),
  sort ties broken differently, loop phase, and clipping under a hand-set Width. A twin's area clips at
  its own offset box, while a preview copy is clipped only by the element's `clip`. This is a 1-26 px
  difference at the box edge under a hand-set Width only. **Under shadow pairing it is larger.** Each
  twin's shadow lands at −2·t·d_k from the twin's own text, outside the twin's own clip and area box
  (`applyClip`, `modules/Style_Text.lua:238-242`, turns clipping on when `autoSize` is off). With a
  hand-set Width, the opposite copy is cut by up to 2·t (12 px at t = 6), plus the `glowX`/`glowY`
  shift past the box edge. A preview copy's shadow is cut only by the element's `clip`, so the
  preview shows more of the opposite side than the live twin does. With `autoSize` on, nothing clips
  and the two agree. The known-limitations entry names this case.

No deviation from the Ka0s WoW Addon Standard. The new module sits in `modules/` with a TOC note
(layout-§1). Frames are made once and kept. Every combat-sensitive write stays behind
`CM.MustDefer`. Every engine call goes through the existing guarded `callEngine` and `Style.Bind`.
