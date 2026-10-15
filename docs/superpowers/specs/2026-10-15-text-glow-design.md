# Text glow: design

**Owner request (2026-10-15).** Text containers get an optional glow behind the text: off by default,
on the text element only (never the icon, never the container box), with its own color, intensity,
blend mode, radius and whatever else is relevant. It adds to the font's outline and shadow and never
replaces them.

**Owner decisions (2026-10-15, asked upfront):**

- Shape: a **soft halo that hugs the text's bounds**. A glyph-shaped glow is impossible for live text (G0).
- Placement: a **Glow** subgroup on the Text section's **Font** tab, directly under Font and before
  Countdown and Dispel type.
- Extras: a **class-color companion** on the glow color, and an **X/Y offset**. Pulse and the
  dispel-type tint were offered and declined.

## G0. Why a halo, not a per-glyph glow

The engine writes every field (name, stacks, dispel type, duration) into a font string of ours through
a `Set…` binding (`SetSpellName`, `SetApplicationCount`, …). Each binding has one target, and no addon
code can read the secret value to copy it into a second, glow-colored font string behind the first.
WoW's outline is always black and its one shadow already belongs to the font's Shadow row. So the glow
is a texture: a soft rounded rectangle anchored to the font strings' own edges, which the client
sizes to the live, secret text without any addon read. It works in combat because nothing is called
after the dress. The engine never touches it.

## G1. Stored leaves (flat, under `container.text`, beside the dispel leaves)

| Leaf | Default | Range / values |
|---|---|---|
| `glow` | `false` | bool |
| `glowColor` | `color(1, 0.82, 0, 1)` (gold) | color with alpha |
| `useClassColorGlow` | `false` | bool, the swatch's class-color companion (options-ui-§17) |
| `glowIntensity` | `0.6` | 0.05 – 1, step 0.05, percent. Multiplies the color's alpha |
| `glowRadius` | `6` | 1 – 24 px, step 1. How far the halo reaches past the text |
| `glowBlend` | `"BLEND"` | `"BLEND"` (Normal) or `"ADD"` (Additive), `C.TEXT_GLOW_BLENDS` / `_LABELS` |
| `glowFalloff` | `"soft"` | `"soft"` (a long, gaussian fade) or `"hard"` (a solid core with a short fade), `C.TEXT_GLOW_FALLOFFS` / `_LABELS` |
| `glowX`, `glowY` | `0`, `0` | -20 – 20 px, step 1. Nudge the halo off the text |

They are new keys in an existing block, so the load backfill stamps them into every stored container
and **no schema step** is needed (the S5 `situations` precedent). A test pins that a container stored
without them draws with no glow.

## G2. Media (amended in TG-05)

No addon media. `C.TEXT_GLOW_TEXTURES[falloff]` in `core/Constants.lua` names a radial texture the
client ships, by an extensionless path:

- `soft`: `Interface\GLUES\Models\UI_Draenei\GenericGlow64` (file 1063457, 64×64), a linear radial
  alpha fade to nothing at its edge. Its color dims with its alpha.
- `hard`: `Interface\CharacterFrame\TempPortraitAlphaMask` (file 130924, 128×128), a white disc that
  is opaque out to a crisp, anti-aliased rim.

Both were read from the live client's files (alpha and color per texel) on 2026-10-15. Smoke TEXT-32
checks that both draw in game.

*Why not the original plan.* The first draft shipped two TGAs in `media/textures/` plus a generator,
`tools/make_glow_textures.py`. TG-01 held them back: layout-§3 keeps `media/` for what only this addon
has, and library-stack-§8 puts the collection's shared art in LibKa0s-Media. A generic glow falloff is
neither, so the TGAs would have been a deviation. The client's own textures need no media, so no
deviation remains and the question for the owner is closed.

## G3. Rendering: `modules/Style_TextGlow.lua` (new, TOC right after `Style_Text.lua`)

`modules/Style_Text.lua` is already 856 lines. The glow gets its own file, which decorates
`Style.Text` with `Text.Glow`, the same file-scope decoration pattern the others use. Its TOC line and
the ARCHITECTURE load order name it.

- **A glow set** is nine textures on `am.anim`'s **BACKGROUND** layer (amended in TG-05; first
  `am.area`'s ARTWORK): four corners, four edges and a center, each its own key on the set. Region keys
  are never hidden in a list the style suites cannot see, so each set is `am.glow1`, `am.glow2`, …,
  built lazily the first time it is needed and kept. The icon is `am.anim`'s ARTWORK, so it covers
  the glow. On the area's ARTWORK the halo drew over the icon, because the area is a child frame of
  `anim` and Size to fit turns its clipping off. Order, back to front: glow, icon, then the area's
  backdrop, edges and text with its shadow and outline.
- **One texture as a nine-slice.** Every piece samples the same radial texture. A corner takes a
  quadrant, `SetTexCoord(0, .5, 0, .5)` and its mirrors, at `r × r`. An edge takes the center column
  or row, stretched along the side. The center takes the center texel. So the fade runs exactly
  `glowRadius` px past the text on every side, at any line length, which one stretched blob could not do.
- **Anchoring, no reads.** Let L be the leftmost and R the rightmost drawn piece, offset (x, y) =
  (`glowX`, `glowY`). The center runs from L's TOPLEFT to R's BOTTOMRIGHT, both offset by (x, y). The
  top edge runs from L's TOPLEFT to R's TOPRIGHT, `r` tall, above them, and the other edges mirror
  it. Each corner is `r × r`, set off the matching corner of L or R. Every anchor is on a font string,
  so the client follows the engine's rewrites in combat.
  - **A line** (not stacked) gets one set. L is piece 1 and R is the last piece, whatever the justify:
    pieces are laid in template order either way.
  - **A stacked Center** line gets one set per name or duration row (L = R = that row's piece). Its
    hidden literal pieces get none, and so do its stacks and dispel rows (amended in TG-05). The engine
    writes those empty below 2 stacks or with no dispel type, and the corners would ring the empty
    string as a glowing dot. A line of only stacks and dispel fields gets no set either. A duration
    keeps its set, and is a dot only on a timeless aura (a known limitation).
  - Every set past the ones used, and every set while `glow` is off, is hidden.
- **Dress.** Each texture gets the falloff's file, `SetBlendMode(glowBlend)`, and a vertex color from
  `Style.Color(glowColor, useClassColorGlow)` with its alpha × `glowIntensity`. The class color
  resolves like the font's, so preview snapshots work: take `Style.ColorWith` when a class is given.
  The dress runs in `Text.Apply` after `layoutChain`, so it moves and fades with the element's loops
  (it lives under `anim`). It is set at dress time only, and a change made in combat waits for the
  deferred restyle like every other setting.
- **Class color.** `useClassColorGlow` matches `^useClassColor`, so `Style` already treats a container
  with it on as class-colored (`anyClassFlag`). A test pins that.
- **Layout untouched.** Size to fit and the element size ignore the glow, as they ignore the shadow.
  Under Size to fit nothing clips, so the halo draws in full. Under a hand-set Width and
  Height the element's clip frame cuts the halo at the box (a known limitation).
- **Preview.** Preview frames dress through `Text.Apply`, and `FillPreview` writes their text, so the
  glow shows in the panel's preview and the unlocked placeholders with no extra code.

## G4. Settings (`settings/Text.lua`, Font tab, subgroup `L["Glow"]`)

They are registered between the FontGroup block and the Countdown block, in this order:

1. `glow`: bool, `startsLine`, label "Glow behind the text", desc "Draw a soft glow behind the
   text, in addition to its outline and shadow. The icon and the box get none."
2. `H.ColorPair{ prefix = P, key = "glowColor", companionKey = "useClassColorGlow", label = L["Glow color"], classColor = UNIT, … }`.
   The composer forbids `disabledIf` on these rows (options-ui-§17).
3. `glowIntensity`, `glowRadius`, `glowBlend`, `glowFalloff`, `glowX`, `glowY`, each
   `disabledIf = unlessOn("glow")`, with labels Intensity, Radius (px), Blend mode (Normal /
   Additive), Falloff (Soft / Hard), Offset X, Offset Y.

Every string goes through `L[...]` in `locales/enUS.lua`. `/am set container.text.glow…` reaches every
row through the one write seam, and so do the Defaults button and the resets.

## G5. Tests (new `tests/test_style_text_glow.lua`, plus touched suites)

Each case is test-first, with a true `-- red under:` note.

- Defaults: every leaf at its G1 value, and a stored container missing them backfills (no glow drawn).
- Off: no set is built, or every built set is hidden after turning it off.
- On, plain line, LEFT, CENTER single-piece and RIGHT justify: one set. The center is anchored to
  piece 1's TOPLEFT and the last piece's BOTTOMRIGHT with the offset, the corners are `r × r`, and
  each texture carries the falloff's file and the blend mode.
- Stacked Center: one set per field row, none for the literals. A shape change hides the extra sets.
- Color: vertex color = color × intensity alpha, the class color under the companion, and
  `Style.AnyClassColor` true with only the glow companion on.
- Settings rows: every path is registered on page `text`, group Font, subgroup Glow, in order, and
  the dependents dim while `glow` is off.
- Outline and shadow still applied with the glow on (`ApplyFont` unchanged).
- Mock changes only in `tests/wow_mock.lua` (`SetTexCoord`, `SetBlendMode` and `SetVertexColor`
  recorded, if missing).

## G6. Docs

- `docs/schema.md`: the text leaves.
- `docs/settings-panel.md`: the Font tab row and a Glow paragraph.
- `docs/ARCHITECTURE.md`: the module map, the load order and Known Limitations.
- `docs/module-map.md`.
- `docs/known-limitations.md`: no per-glyph glow, the clip under a hand-set Width, and no glow of its
  own for a field the engine may write empty.
- `docs/smoke-tests.md`: new owner checks, never marked passed.
- `README.md`: the feature line and the test badge.
- `docs/test-cases.md`: regenerated.

The version is not bumped and no release notes are written.

## Out of scope

Bars and Icons text. A pulse. The dispel-type tint. A glyph-shaped glow (G0).
