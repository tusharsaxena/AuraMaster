# Text glow addendum: a glyph glow from twin engines

**Supersedes** spec G0, G2 and G3 and parts of G1, G4, G5 and G6
(`2026-10-15-text-glow-design.md`). Unchanged: off by default, text containers only, on the text and
never the icon or the box, in addition to the outline and shadow.

## Why the halo is gone (owner smoke, 2026-10-15)

The nine-slice halo drew a solid gold box behind every line. Its center piece samples the peak
texel, so the center is opaque, and `TempPortraitAlphaMask` has no fade along its center row or
column. The owner rejected the box shape in any case. What the owner wants is a glow that hugs each
letter.

## What the in-game probe established (owner, 2026-10-16, `AMGlowProbe`, 12.1)

- **The Slug outline takes no color.** `OUTLINE,SLUG`, `OUTLINE|SLUG`, `THICKOUTLINE,SLUG` and `SLUG`
  all draw a black rim. A colored shadow at offset 0 does not tint it.
- **A ring of glow-colored copies reads as a glow.** The owner picked **r = 2, 8 copies, one ring at
  alpha ≈ 0.55**, with the main text drawn on top. `CreateFontString` takes **no** sublevel argument:
  the layer order needs `SetDrawLayer(layer, sublevel)`. Otherwise the last-created string draws on
  top.
- **Twin engines work.** Nine `CustomAuraContainerTemplate` engines ran side by side: one main and
  eight twins, each with the same unit (player), filter, sort and layout, and each offset by a ring
  direction × 2 px. In and out of combat, and while auras were gained and lost:
  - every twin built the same buttons (10 each);
  - the gold copies stayed under the right aura's name and timer;
  - the tooltip and right-click cancel on the main text still worked;
  - the framerate did not drop.
- **A button with no size is never placed.** Size it (`frame:SetSize`) in `initializeFrame`, as
  `Text.Apply` already does. `GetSize` on an engine returns secret values, so it can never be logged
  as numbers.
- **Shadow pairing works (owner probe `/amgp twin4s`, 2026-10-16):** four twins, each drawing +d with
  its font string shadow in the glow color at offset −2d, look the same as eight twins. So
  `C.TEXT_GLOW_TWINS = 4` with pairing is the shipped value.

## Why twins (G0 revised)

Each engine binding has one target (`SetSpellName`, `SetApplicationCount`, `SetDispelTypeText`, and
the C-side duration text binding). The engine writes from the secure environment through forbidden
handles, so no hook sees the write. In combat the button's strings refuse every addon call. The only
way to get a second copy of the live, secret text is a second engine that writes it.

## Stored leaves (replace G1; the branch is unmerged, so nothing migrates)

| Leaf | Default | Range |
|---|---|---|
| `glow` | `false` | bool |
| `glowColor` | `color(1, 0.82, 0, 1)` | color with alpha |
| `useClassColorGlow` | `false` | the swatch's companion |
| `glowIntensity` | `0.55` | 0.05 – 1, step 0.05, percent. Each copy's alpha = color alpha × intensity |
| `glowThickness` | `2` | 1 – 6 px, step 1. The ring's radius (the owner's "r") |
| `glowX`, `glowY` | `0`, `0` | −20 – 20 px, step 1. Shift the whole ring |

`glowRadius`, `glowBlend` and `glowFalloff` are **removed**, together with `C.TEXT_GLOW_BLENDS`,
`C.TEXT_GLOW_FALLOFFS` and `C.TEXT_GLOW_TEXTURES` and their labels and locale strings. A FontString
has no blend mode. That is the owner's original "mode" control, and it cannot exist for a glow that
hugs the glyphs (the owner was told this). Settings: the Font tab's Glow subgroup becomes Glow
(bool), Glow color with its class-color companion, Intensity, Thickness (px), Offset X and Offset Y.
Every row but the color pair dims while Glow is off.

## Rendering

### Live: twin engines

For a text container with `glow` on, the container builds **`C.TEXT_GLOW_TWINS`** twin engines beside
its main engine. The value is 4 under shadow pairing, or 8 without it. It is one constant plus a
pairing flag, so the twin4s outcome flips one line.

- **Same content.** Each twin gets the same unit, groups (filter, candidate filters, sort method and
  direction, max frame count, per-group layout), view (Situations), enchant slots and flow layout as
  the main engine, sent through the same `callEngine` paths and in the same order. Every place that
  updates the main engine updates the twins in the same pass: `Build`, `Update`, `ApplyView`, the
  unit swap, the enchant updates, `Destroy`, and the hide paths (zones, unit filter, disabled,
  empty-watch). A twin is never left holding an older plan than its main.
- **Same place, offset.** Each twin is anchored exactly as the main engine is (`EngineOffset`, flow
  anchor point). On top of that it takes `thickness × d_k + (glowX, glowY)`, where d_k is the k-th
  unit ring direction. Every twin sits at a frame level below the main engine, on the same strata.
- **Never interactive.** Twin buttons take no mouse motion and no clicks, cancel no aura and show no
  tooltip. Twin engines never join the drag, snap, attach, the frame picker or anchor targets, and
  never feed the empty watch, diagnostics counts that mean "visible auras", or the attach chain's
  geometry. They are decoration that follows the main engine.
- **The glow dress (`initializeFrame` of a twin).** The element is dressed through the **same**
  `Text.Apply` code path as the main: same size, chain or stack, icon-and-area layout, justify,
  offsets and loops. Only the look changes, through a variant flag:
  - the icon and its border are laid out but never shown or bound, so the text keeps its exact place;
  - no dispel backdrop or edges;
  - every piece in the glow color (`Style.Color` or `ColorWith(glowColor, useClassColorGlow)`) with
    alpha × intensity;
  - font flags with the outline dropped, keeping MONOCHROME if set;
  - the glyph-color tricks are off on the twin: dispel-word coloring and the pandemic time color;
  - a duration piece is bound with a plain glow color, so the engine's time-color curve never turns
    the glow red;
  - under shadow pairing, the shadow is in the glow color at the same alpha, offset −2 × thickness × d_k.
    Without pairing it is off.
  - Literal pieces take their text as on the main.
  - The animations play the same loop as the main.
- **Lifecycle.** Toggling `glow`, or changing `glowThickness`, `glowX` or `glowY`, rebuilds or
  re-anchors the twins. Glow on or off is part of the structure key. Color and intensity restyle in
  place. All of it follows the existing rules: defer in combat (`ContainerManager.MustDefer`), and
  build only when an apply may run.

### Preview and unlocked placeholders: addon-written copies

The preview element writes its own text (`Text.FillPreview`), so its ring is plain copies. Each
piece gets `C.TEXT_GLOW_TWINS` copy strings (twice that without pairing), dressed like the twin
pieces. They are placed with `SetDrawLayer` under the main string and given the same text. The
preview matches the live look, so the owner can tune the glow in the panel.

### Removed

`modules/Style_TextGlow.lua`'s nine-slice sets and their tests. The module may stay as the home of
the glow dress (pure functions over a font string plus the settings) and the preview copies. Its file
header describes the new design.

## Limits to document (known-limitations, ARCHITECTURE)

- Each glowing text container costs `C.TEXT_GLOW_TWINS` extra aura engines, each with its own
  UNIT_AURA work. The probe saw no framerate drop with 8, but a perf run should confirm.
- A twin orders auras with the same comparator as its main engine. A sort tie broken differently is
  possible in principle, and the probe never saw one.
- A twin's loop starts when its own button is dressed, so a pulse or bounce can run a few frames out
  of phase with its main.
- Under a hand-set Width the box clips the copies, as it clips the text.

## Tests

- A twin engine is built per `C.TEXT_GLOW_TWINS` only while glow is on, at the right offsets and
  frame level, with the main's groups, unit, view and layout. It is mirrored on update, view switch,
  unit swap and destroy, and kept off every interactive and geometry path.
- The glow dress: color × intensity, the class color, no outline, the shadow pairing, the icon and
  tints hidden, no time-color curve.
- The preview copies.
- The settings rows, the defaults, and removed leaves gone. The engine recorder carries the twins.
- Each case gets a true `-- red under:` note.
