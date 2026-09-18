# Text container style — design spec (issue #2)

- **Date:** 2026-09-18
- **Issue:** https://github.com/tusharsaxena/AuraMaster/issues/2
- **Status:** approved design, 2026-09-18; not yet planned or implemented.
- **Evidence:** two throwaway in-game probes on client 12.1.0 (120100), the same evening (§2), plus a
  read of Blizzard's live UI source (Gethe/wow-ui-source `live`, `Blizzard_AuraContainer/` and
  `Blizzard_APIDocumentationGenerated/`).

## 1. Goal

A third container style beside Bars and Icons. Each aura is drawn as **one line of text**, laid out
from a player-written **template** such as `$spellname$[ x$stacks$][ - $remainingduration$ / $maxduration$]`.
The line is justified inside a box of set width and height, uses the standard font controls, can carry
an optional icon, and can animate: a looping effect, plus a blink when the aura is running out. It
must work live in combat, where every aura value is secret to addon code.

## 2. What the client allows (the facts this design rests on)

### 2.1 From the source

- The engine's aura button has exactly one binding for each text field: `SetSpellName(fs)` (no
  options), `SetApplicationCount(fs, { formatter })`, `SetDispelTypeText(fs, { showWhenHarmful,
  showWhenHelpful, showWithoutDispelType, customDispelTextMap })` and `SetDurationText(fs, options)`.
  Calling a binding a second time replaces the first. There is **no** binding for caster/source name.
- `SetDurationText`'s `textFormat = { formatString, components }` substitutes each `{}` in the format
  string with one component `{ property, formatter }`. The properties come from
  `Enum.DurationTextBindingProperty`: `RemainingDuration`, `RemainingPercent`, `ElapsedDuration`,
  `ElapsedPercent`, `TotalDuration`, `StartTime`, `EndTime`. Only duration values can be components.
  Spell name and stacks cannot.
- `options.binding` accepts a prebuilt binding (`C_DurationUtil.CreateDurationTextBinding()`), which
  is the only way to set `SetUpdateInterval`, `SetZeroDurationText` and `SetExpiredText`.
  `textColor = { curve, property }` recolours the duration text through a colour curve.
- Addon code can never combine secret values into one string. `SetFormattedText` accepts secret
  arguments, but addon code can never *obtain* the values (the 12.1 aura APIs raise while auras are
  secret; `docs/midnight-quirks.md`). So one line has to be a **chain of font strings**: one per
  engine field, plus static font strings for plain text.
- A bound font string gets the secret Text aspect. Its geometry getters are
  `SecretWhenAnchoringSecret`.

### 2.2 Probe round 1 (two containers of the player's buffs, 40 buttons)

- **Every binding and option was accepted** (29 setup steps, 0 errors). That covers `SetSpellName`;
  `SetApplicationCount` with a `C_StringUtil.CreateNumericRuleFormatter` whose breakpoints are
  `{0: ""}, {2: " x%d"}`; `SetDurationText` with the format `" - {} / {} ({})"` (remaining, total,
  remaining %) and a prebuilt binding (`SetUpdateInterval(0.1)`, `SetZeroDurationText("")`,
  `SetExpiredText("")`); a stepped `C_CurveUtil` colour curve on `RemainingDuration`; and looping
  AnimationGroups played at dress time.
- **Folding works.** With the text folded into the engine formats, a timeless buff showed only its
  name, a single stack showed nothing, and 2+ stacks showed ` x5`.
- `RemainingPercent` arrives on a **0–100** scale, so `%d%%` reads correctly (e.g. `40%`).
- A stepped colour curve with alternating alpha **blinks the duration text in the last N seconds**,
  in and out of combat.
- **Animations started at dress time keep playing through combat and after it.** In combat,
  every call on the button's objects raises *"Attempt to access forbidden object from code tainted by
  an AddOn"*: `AnimationGroup:IsPlaying/Play/Stop`, `Region:IsShown`, `IsAnchoringSecret`. So an
  animation can only be set up at dress time, never started, stopped or changed in combat.
- `FontString:IsAnchoringSecret()` answers **true even out of combat** for the engine-written name,
  so no width in the chain can ever be read.
- **A Scale animation broke the chain.** The pulsing (Scale 1.00→1.08) left-justified list overlapped
  (`Fortun`**x**), while the fading (Alpha) list did not.

### 2.3 Probe round 2 (four left-justified variants, each font string shown with a tinted box)

- **All four variants rendered cleanly, in and out of combat.** Every piece sat inside its own box,
  with no overlap. The variants were: folded with default justify; folded with justify LEFT; static
  ` x`/` - ` literals; and space-free literals with 4 px anchor gaps. The client sizes an
  engine-written font string to its secret text correctly, and chains anchored to it lay out right.
- `SetJustifyH` makes no difference to a single-anchored, auto-sized font string (variants 1 and 2
  looked the same).
- **Conclusion:** round 1's overlap came from the Scale animation (the glyphs grow about 8 % past
  their unscaled boxes), not from chaining. This design has no scale animation.

### 2.4 What follows from the facts

| Want | Possible? | How |
|---|---|---|
| Name, stacks, dispel type and durations in one line | yes | a chain of font strings, one per engine field, plus static literals |
| Several duration values with text between them | yes | one duration field, `textFormat` with several `{}` |
| Text that disappears with its value | yes | fold it into that value's engine format (§3.3) |
| The same token twice | no | one binding per field |
| A duration token on each side of the name | no | one duration field, so the duration tokens must be one run |
| Caster/source name | no | no binding exists |
| Centering a multi-piece line | no | needs the chain's width, which is never readable |
| Loop animations in combat | yes | start at dress time; they run inside the client |
| Change an animation in combat | no | the button's objects are forbidden to addon code in combat |
| Blink when running out | yes, on the duration run only | a stepped colour curve with alternating alpha |
| Scale / grow animation | no (breaks layout) | not offered |

## 3. The template

### 3.1 Tokens (case-insensitive)

| Token | Engine field | Rendered as |
|---|---|---|
| `$spellname$` | `SetSpellName` | the aura's name |
| `$stacks$` | `SetApplicationCount` | the stack count; hidden at 1, like Blizzard (§3.3) |
| `$dispeltype$` | `SetDispelTypeText` | the localized type name, via `customDispelTextMap`, keyed by the aura's `dispelName` (`Blizzard_CustomAuraButton.lua:397`). Mapped for every `C.DISPEL_TYPES` entry except `None`, plus `Enrage`. A type the map lacks falls back to the engine's own symbol, and an aura with no type shows nothing |
| `$remainingduration$` | duration run | time left, in the container's time format |
| `$maxduration$` | duration run | total duration (`TotalDuration`), in the time format |
| `$elapsedduration$` | duration run | time elapsed, in the time format |
| `$remainingpercent$` | duration run | `NN%` of the duration left |
| `$elapsedpercent$` | duration run | `NN%` elapsed |

`StartTime` and `EndTime` are not offered: they are clock timestamps, which make no sense as seconds
formatted by a `SecondsFormatter`.

### 3.2 Rules (checked when the template is entered; the first broken rule is reported)

1. Tokens are `$name$`. An unknown name is refused: *"Unknown token $foo$. Known: …"*. A lone `$` with
   no closing `$` is literal text.
2. Each token may appear **at most once**: *"$stacks$ appears twice — each token can be used once."*
3. The duration tokens form **one run**: between the first and last duration token there may be only
   literal text and other duration tokens, never `$spellname$`, `$stacks$` or `$dispeltype$`.
   *"Duration tokens must sit together — $spellname$ splits them."*
4. `[` … `]` brackets are **hide-with-token groups**: not nested (*"Brackets can't be nested."*),
   balanced (*"Unmatched [ or ]."*), and holding **exactly one** foldable unit: `$stacks$`,
   `$dispeltype$`, or the whole duration run (*"A [ ] group must hold exactly one of $stacks$,
   $dispeltype$ or the duration tokens."*). A bracket holding only `$spellname$`, or only text, is
   refused the same way. The name is never empty, so bracketing it would do nothing.
5. A bracket around the duration run must contain the **whole** run (*"Put all the duration tokens
   inside the same [ ]."*).
6. `{` and `}` may not appear inside the duration run or its bracket, because the engine's escape for
   them is unknown (*"{ and } can't be used next to duration tokens."*). They are allowed elsewhere as
   plain literals.
7. The template may not be empty and must contain at least one token (*"Use at least one $token$."*).
8. Length ≤ 200 characters.

To type a literal `[`, `]` or `$`, double it: `[[`, `]]`, `$$`. In a run of consecutive `[`, an odd-length run opens a group with its **first** `[` and the rest are escaped pairs (`[[[$stacks$]]]` hides both brackets with the count); an odd-length run of `]` closes with its **last** `]`. An even-length run is all literal.

### 3.3 Compilation: from template to pieces

The parser (`modules/TextTemplate.lua`, pure Lua, no WoW API) turns a valid template into an ordered
list of **pieces**, each one font string:

| Piece | Holds | Bound with |
|---|---|---|
| `literal` | text outside any bracket, between fields | nothing (static `SetText`) |
| `name` | `$spellname$` | `SetSpellName` |
| `stacks` | `$stacks$` plus its bracket text | `SetApplicationCount` + a rule formatter |
| `dispel` | `$dispeltype$` plus its bracket text | `SetDispelTypeText` with a text map |
| `duration` | the duration run, the literals inside it, plus its bracket text | `SetDurationText` with `textFormat` |

Folding:

- **Stacks.** Bracketed: breakpoints `{ threshold = 0, format = "" }, { threshold = 2, format = pre .. "%d" .. post }`,
  where `pre`/`post` are the bracket's text with every `%` doubled. Unbracketed: the same, with
  empty `pre`/`post`, which also hides a single stack, as Blizzard's own default does.
- **Dispel.** `customDispelTextMap[type] = pre .. label .. post` for each dispel type,
  `showWithoutDispelType = false`, and both `showWhenHarmful` and `showWhenHelpful` on.
- **Duration.** The format string is `pre .. run .. post`, with each duration token replaced by `{}`
  and its component `{ property, formatter }` appended in order. The prebuilt binding always has
  `SetZeroDurationText("")` and `SetExpiredText("")`, so a timeless or expired aura's whole piece
  (bracket text included) is empty. Text **between** two duration tokens is always part of the
  format, bracketed or not.
- Adjacent literals merge into one piece, and an empty literal is dropped.

The parser returns `{ ok = true, pieces = {…}, single = <bool> }` or
`{ ok = false, err = "<localized message>" }`. `single` is true when there is exactly one piece
(needed for centering, §4).

## 4. The box, layout and icon

- Each aura is one element of **width × height** (`text.width`, `text.height`), laid out by the
  engine's flow layout like a bar.
- The **text area** is the element minus the icon and its gap. A clip frame covers it
  (`SetClipsChildren(true)`), so a line wider than the box is cut off at the box edge, never drawn
  over its neighbour.
- **Horizontal justify** (`text.justifyH`):
  - `LEFT`: the first piece anchored to the area's left, each next piece `LEFT` → previous `RIGHT`.
  - `RIGHT`: the last piece anchored to the area's right, each earlier piece `RIGHT` → next `LEFT`.
  - `CENTER`: allowed only when the compiled template is `single`. Otherwise the dress falls back to
    `LEFT`, and the Justify row's tooltip, plus a note under it, says why (*"Center needs a one-piece
    template; this one has N pieces, so it lines up Left."*).
- **Vertical justify** (`text.justifyV`: `TOP` / `MIDDLE` / `BOTTOM`) picks the anchor points
  (`TOPLEFT`/`LEFT`/`BOTTOMLEFT`, or the right-hand equivalents). `text.x` / `text.y` nudge the whole
  chain.
- Every piece is single-line (`SetWordWrap(false)`) and auto-sized (no `SetWidth`). Round 2 showed
  the client sizes engine-written text correctly.
- **Icon** (`text.icon`: `NONE` default / `LEFT` / `RIGHT`), with `iconSize` (0 = element height),
  `iconGap`, `iconZoom` and the composed icon-border block, all as on Bars. The icon placement
  helpers move from `modules/Style_Bars.lua` into `modules/Style.lua` (`Style.LayoutIcon`,
  `Style.IconSizeFor`, `Style.IconInset`), parameterized by the style's template block, so Bars and
  Text share one implementation. This is a targeted refactor; Bars' behaviour is unchanged and its
  tests must stay green without edits.
- Nothing is drawn around the box (no background, no border). That was the owner's choice,
  2026-09-18.

## 5. Font

One composed font block for the whole line (`text.font` via `H.FontGroup`: font, size, flags, shadow,
colour + class-colour companion), applied to every piece, literals included. `text.timeFormat`
(`blizzard` / `short` / `long`) drives the duration components' `SecondsFormatter`
(`Compat.CreateSecondsFormatter`, as the Bars and Icons time text use today). Percent components use a
rule formatter with `%d%%`.

## 6. Animation

### 6.1 Loop (`text.anim`)

| Value | Effect | Built as |
|---|---|---|
| `none` (default) | — | no AnimationGroup |
| `pulse` | smooth fade down and back | Alpha 1 → `animIntensity`, `SetLooping("BOUNCE")`, smoothing IN_OUT |
| `blink` | hard on/off | Alpha 1 → `animIntensity`, duration ≈ 0, then a hold; `REPEAT` |
| `bounce` | small up-and-down move | Translation 0 → `animBounce` px on Y, `BOUNCE` |

- `animSpeed`: seconds per cycle, 0.2–3.0, default 1.0. `animIntensity`: the lowest alpha, 0–0.9,
  default 0.3. `animBounce`: 1–10 px, default 3.
- The group lives on an **animation frame** that holds the chain and the icon, inside the clip
  frame, so the whole line animates together. A bounce is clipped by the box, which is the point of
  the box. The Bounce tooltip notes it needs a little headroom.
- **No Scale animation** (§2.3).
- It is built and played in the dress (`initializeFrame` or a restyle while auras are readable). A
  restyle that changes it stops the old group and builds the new one. Because the engine forbids
  touching the button in combat (§2.2), a change made in combat applies when the addon's normal
  deferred restyle runs after combat. This is the existing `ContainerManager.MustDefer` path, with
  nothing new.

### 6.2 Running out (duration run only)

- Reuses the Bars/Icons leaves: `expiringColorOn`, `expiringThreshold`, `expiringColor`.
- New: `expiringBlink` (bool, default false). When it is on, the colour curve alternates the
  running-out colour's alpha between full and 0.1 every 0.25 s from the threshold down to 0 (a
  stepped curve, as in probe round 1), and the prebuilt binding's `SetUpdateInterval(0.1)` is set so
  the blink is smooth. It is set **only** when blink is on, so the default update cost is unchanged.
- It applies only to the duration piece. The rest of the line keeps the font colour. The Blink row's
  tooltip says so.
- It needs a duration token in the template. Without one, the Running-out rows are disabled, with a
  note.

## 7. Data

`defaults/Profile.lua` `CONTAINER_TEMPLATE.text`:

```lua
text = {
    width = 220, height = 16,
    template = "$spellname$[ x$stacks$][ - $remainingduration$]",
    justifyH = "LEFT", justifyV = "MIDDLE", x = 2, y = 0,
    font = <composed font block, size 12, OUTLINE, shadow off, white>,
    timeFormat = "blizzard",
    icon = "NONE", iconSize = 0, iconGap = 2, iconZoom = 0.08,
    iconBorderShow = false, iconBorderStyle = "Solid", iconBorderSize = 1,
    iconBorderColor = color(0, 0, 0, 1), useClassColorIconBorder = false,
    anim = "none", animSpeed = 1.0, animIntensity = 0.3, animBounce = 3,
    expiringColorOn = false, expiringThreshold = 5, expiringColor = color(1, 0.25, 0.25, 1),
    expiringBlink = false,
},
```

- `C.STYLES` gains `"text"` (`C.STYLE_LABELS.text = "Text"`). New constant lists: `C.TEXT_JUSTIFY_H`,
  `C.TEXT_JUSTIFY_V`, `C.TEXT_ANIMS` (+ labels), `C.TEXT_TOKENS` (the token table the parser and the
  cheat sheet share).
- Existing containers backfill the new block from the template on load; no `schemaVersion` bump.
### 7.1 A starter Text container (owner request, 2026-09-18)

A fresh profile gets a **fourth starter container** in `NS.STARTER_CONTAINERS` (`defaults/Profile.lua`),
seeded by `core/Database.lua`'s `seedStarters` like the other three:

```lua
{
    name = "Player cooldowns", unit = "player", auraType = "HELPFUL", style = "text",
    filter = { castBy = "any", categories = NS.Categories.StatesShowing({ "offensiveCDs", "defensives" }) },
    position = { point = "CENTER", relativePoint = "CENTER", x = -260, y = -40 },
    layout = { axis = "vertical", growH = "right", growV = "down" },
},
```

- `Cat.StatesShowing(keys)` (new, `defaults/Categories.lua`) returns `DefaultStates()` with **every
  `Cat.HELPFUL` key set to `"hide"`** except the listed ones, which stay `"show"`. That includes
  every Blizzard token/flag category (Big defensives, External defensives, Important, Castable by
  you, Cancelable, Stealable), Weapon enchants and **Uncategorized**. `Cat.HARMFUL` keys keep
  `"show"`: they are inert on a buff container, and leaving them at the default means switching the
  container to debuffs later does not start from an all-hidden grid.
- The effect: only buffs on the Offensive cooldowns or Defensives lists draw. Show beats Hide
  (batch 6's filter priority), so a defensive the Blizzard *Big defensives* token also flags still
  draws. A buff on neither list has no Show to rescue it once Uncategorized is Hidden.
- `defaults/Profile.lua` already loads after `defaults/Categories.lua` (a load-bearing TOC comment),
  so `NS.Categories` is available when the starter list is built.
- **New profiles only.** An existing profile is already marked `seeded` and gets nothing. That is
  the seeding contract, which deliberately never brings starters back.
- Everything else in it (text block, template, size) is the template default.
- Tests:
  - `Cat.StatesShowing` output: every HELPFUL key hidden but the two, HARMFUL untouched.
  - A fresh profile seeds 4 containers, and the 4th is style `text` with those states.
  - `FilterCompiler.Compile` on that container draws only the two lists' ids. That means one group
    per Show category, no catch-all, and `FC.ExplainSpell` of an unlisted buff answers `hidden`.
  - **Correction (plan review, 2026-09-19):** a fourth starter turns about 35 existing cases red
    across 11 suites (they assume three starters, or that starter 1 is the first container of its
    kind). Plan Task 10 lists every edit. The count-based assertions do follow
    `#NS.STARTER_CONTAINERS`; the rest do not.
- Smoke check (§13, new item 10): on a new profile, the Player cooldowns list shows a defensive and
  an offensive cooldown when popped, and nothing else (no food, flask or mount buffs).

- Stored templates are re-validated at dress time. An invalid stored template (hand-edited SV, or a
  future token removed) draws the default template and prints one debug line. It never errors.

## 8. Settings: the Text page

`settings/Text.lua`, a Containers sub-page after Icons (load position N-2), registered with
`NS.RegisterContainerPage("text", L["Text"], "AuraMasterTextPanel", { disabledFor = style ~= "text",
disabledNotice = … })`, like Bars and Icons.

| Tab | Rows |
|---|---|
| **General** | Size: width (40–600), height (8–80). Template: an EditBox row (`dialogControl = "EditBox"`, like `container.name`) with `validate` = the parser, whose error is the refusal text; below it a read-only **token cheat sheet** (each token, one line each, plus the `[ ]` rule with one example). Placement: horizontal justify, vertical justify, X, Y, and the centering note (§4). |
| **Font** | the composed font block; time format. |
| **Icon** | position, size, gap, zoom; the composed icon-border block. |
| **Animation** | Loop: effect, speed, intensity, bounce height (each row disabled unless its effect uses it). Running out: recolor on/off, threshold, colour, blink. |

- The Containers page's Style dropdown offers Text. `/am set container.text.template "<…>"` goes
  through the same `validate`.
- Every row has `coverage` honesty per the render-coverage suite: `expiringBlink` is `engine-only`
  (the preview shows the colour, not the blink); the loop animation plays on placeholders too.

## 9. Preview

`Style.Text.FillPreview(frame, aura, cfg)` fills the same pieces from the placeholder aura with plain
values: the name; stacks through the same breakpoint logic (Lua mirror: `< 2` → `""`); dispel type
text by map; the duration run by substituting each component (`Style.PreviewTime`'s formatter for
durations, `%d%%` for percents), then applying `pre`/`post`, and `""` when the placeholder is timeless.
The same parser output drives both paths, so preview and live cannot drift in structure.

## 10. Code map

| File | Change |
|---|---|
| `modules/TextTemplate.lua` (new) | pure parser/compiler (§3); no WoW API; `TT.Compile(template) → result`, `TT.TOKENS` |
| `modules/Style_Text.lua` (new) | build regions (clip frame, animation frame, piece font strings, icon); dress: layout (§4), fonts (§5), animation (§6.1); bind each piece; `FillPreview` |
| `modules/Style.lua` | dispatch `"text"` in `Style.Element`; `ElementSize` and `UsesClassColor` text branches; shared icon helpers (moved from Bars); a duration-text helper taking `textFormat` + prebuilt binding + optional blink curve |
| `modules/Style_Bars.lua` | uses the shared icon helpers (no behaviour change) |
| `core/Compat.lua` | `Compat.CreateRuleFormatter(breakpoints)`, `Compat.CreateDurationBinding(opts)`, `Compat.BlinkTextColor(threshold, color)`: guarded wrappers, nil on a client without the API |
| `core/Constants.lua` | `"text"` style + the lists in §7 |
| `defaults/Profile.lua` | `CONTAINER_TEMPLATE.text`; the fourth starter container (§7.1) |
| `defaults/Categories.lua` | `Cat.StatesShowing(keys)` (§7.1) |
| `modules/Preview.lua` | text style placeholders |
| `settings/Text.lua` (new), `settings/Containers.lua` | the page; Style dropdown |
| `AuraMaster.toc` | `modules\TextTemplate.lua` (before Style), `modules\Style_Text.lua` (after Style_Icons), `settings\Text.lua` (after Icons) |
| `locales/enUS.lua` | every new string, error messages included |

A piece's font strings are created per dress. A restyle that changes the template rebuilds the
text regions (`Style.RegionsFor` already tags regions per style; the text style also tags them with
the compiled template, so a changed template rebuilds instead of re-binding stale pieces).

## 11. Tests (headless harness)

- `tests/test_texttemplate.lua`: every rule in §3.2 with its exact message; `[[`/`]]`/`$$` escapes;
  case-insensitivity; piece output for representative templates (default; name only; duration run
  with inner text; bracketed stacks with `%` in it; dispel; literal-only pieces merging); `single`.
- `tests/test_style.lua` (extended), text style:
  - element size;
  - the chain anchors for LEFT and RIGHT and each `justifyV`;
  - `CENTER` falling back to `LEFT` for a multi-piece template;
  - the clip frame;
  - each piece's engine call and options: the rule-formatter breakpoints, the dispel text map, and
    the duration `textFormat`, components, prebuilt binding and zero/expired text;
  - blink: the curve and `SetUpdateInterval` present only when it is on;
  - the loop animation: the group type and settings per effect, none for `none`;
  - the icon on and off;
  - an invalid stored template drawing the default.
- Bars' existing icon tests pass unchanged after the helper move.
- `tests/test_preview.lua`: the text placeholders render the template, and bracket text hides.
- `tests/test_pages_text.lua`: the rows, tabs and disabled state; the template `validate` refusal
  text; the cheat sheet; the centering note.
- The schema, render-coverage, locale, docs, load-order and surface-parity suites updated.
- `tests/perf.lua`: a text-style dress scenario.

Green gate: `lua tests/run.lua`, `luacheck .` 0/0, and lizard with no function above CCN 15.

## 12. Docs

- `docs/ARCHITECTURE.md`: the module map, and the style dispatch.
- `docs/schema.md`, `docs/settings-panel.md`: the text block and the page.
- `docs/midnight-quirks.md`: a new section, "Text chains and animations on engine buttons", holding
  the §2.2–2.3 findings.
- `docs/smoke-tests.md`: the in-game checks in §13.
- `README.md`: the style and the token list.
- Issue #2: close on ship.

## 13. In-game smoke checks (owner)

1. The default template on player buffs: names, ` x3` stacks, and ` - 12s`, all live in combat;
   timeless buffs show the name only.
2. `$spellname$ $remainingduration$ / $maxduration$ ($remainingpercent$)`, justified Left and then Right.
3. `$dispeltype$` on a target-debuff Text container: correct type names; no text on typeless debuffs.
4. Pulse, Blink and Bounce, each through a pull; no overlap while animating.
5. Running out: the colour, then the blink, in the last N seconds.
6. The optional icon, Left and Right, with a border.
7. Invalid templates in the settings box and via `/am set`: each refusal message reads right.
8. Switching a container Bars → Text → Icons → Text, out of combat: redraws cleanly.
9. Weapon-enchant containers with style Text: name and duration show (the engine's enchant buttons
   take the same bindings).
10. On a **new** profile, the seeded "Player cooldowns" Text container shows only offensive
    cooldowns and defensives (§7.1). No food, flask, mount or raid buffs.

## 14. Out of scope

- Scale/grow animations (they break the chain, §2.3).
- Centering a multi-piece line (the chain's width is unreadable).
- A caster/source name token (no engine binding).
- Per-token fonts or colours.
- Starting, stopping or changing an animation in combat (forbidden by the engine).
- A box background or border (owner's choice).

## 15. Standards check

- It follows the existing Bars/Icons patterns: schema rows through the one write seam, composed font
  and border blocks (options-ui-§16) with class-colour companions (§17), a sub-page registered like
  its siblings, and guarded engine calls.
- The parser is pure and fully unit-tested.
- It adds no SavedVariables, events or frames outside the engine's buttons.
- **No deviations identified.**

---

# Part B — the owner's backlog batch (added 2026-09-19, same release)

The owner asked for four in-game fixes to ship with the Text style (the memory note of 2026-09-18,
answered 2026-09-19). Each is independent of Part A and of the others, except that B1 and A both touch
`modules/Preview.lua`.

## B1. Unlock shows real auras; a separate, standard test mode

**Today.** Unlocking a container disables its engine and shows placeholder auras
(`modules/Container.lua:401-446`: `previewing = not p.locked`; `SetEnabled(show and not previewing)`).
Under preview-mode's exception, that unlocked view **is** the addon's test mode:
- no `testModePath` is passed to `H.MasterControls` (`settings/General.lua:27-31`);
- there is no `/am test` verb;
- the launcher's left-click toggles the lock (`core/LauncherSetup.lua:20,124`).

**Change.** Unlocking only makes containers draggable, and the **live** auras keep drawing. Placeholders
move to a **test mode** of their own. The exemption no longer applies, so the test mode follows the
standard's full rule (preview-mode; options-ui-§15; anti-pattern #80; launcher-§2 rung (b);
slash-commands on `test`):

- **State:** `NS.State.testMode` (session-only, boolean, false at login). `core/State.lua`'s "There
  is no preview flag" note is rewritten.
- **Checkbox:** `H.MasterControls` gets `testModePath = "testMode"`, a **session row**
  (`default = false`) whose get/set are bound to `NS.State.testMode` through the host seam, the way
  the debug console row is bound. The composer places it in the second column beside *Minimap
  button* (LibKa0s ≥ v1.39.0; the addon vendors v1.43.0, so this is available). The General.lua
  header comment is rewritten, and it now cites the rule instead of the exemption.
- **Verb:** `/am test` toggles it (`/am test on|off` sets it), reusing the same seam. `/am help` lists
  it. The `unlock` verb's description drops "(shows placeholder auras)".
- **Combat:**
  - It **ends when combat starts** (`PLAYER_REGEN_DISABLED`, while secure writes are still allowed).
  - A start **during combat is refused**, with one `NS.PREFIX` line: *"Test mode can't start in
    combat."*
  - The checkbox follows every start and stop; a refused start leaves it unticked.
- **Reset:** *Reset all settings* ends it (it is a session row with `default = false`, restored by the
  row walk, options-ui §1).
- **Launcher:** left-click now toggles **test mode** (rung (b): "the test mode where the addon has
  one"), through the same seam. The launcher tooltip text follows.
- **Visibility and drawing** (`ContainerClass:ShouldShow` / `ApplyVisibility`):
  - `previewing = NS.State.testMode` (was `not p.locked`).
  - While previewing: the engine is disabled, the placeholders show, and the container shows
    whatever its visibility rule says. The test mode's job is to show the display.
  - While **unlocked and not previewing**: the engine stays **enabled**, the drag handle shows
    (`NS.Anchors.UpdateHandle(self, not p.locked)`), and the container is forced visible whatever
    its visibility rule, so a container set to "in combat only" can still be found and moved.
  - An **outline** is drawn: a faint 1-px box, one element's size, at the container's anchor
    point, on an addon-owned frame beside the handle (not on the engine). It shows while unlocked,
    so an **empty** container can still be seen and grabbed. It hides when locked, and it hides in
    test mode (the placeholders are there then).
  - Locked and not previewing is unchanged from today.
- **Docs:** `docs/ARCHITECTURE.md` (the preview section, the launcher row, the slash surface),
  `docs/smoke-tests.md`, README `## Usage` (the documentation standard's `## Usage` item requires describing how test mode is
  reached), and `docs/midnight-quirks.md` only if a combat edge needs noting.
- **Tests:**
  - `test_container` / `test_containermanager`: unlocked keeps the engine enabled; unlocked forces
    visibility; test mode disables the engine and shows placeholders; the outline shows only while
    unlocked and not previewing.
  - `test_slash_verbs`: `test`, `test on/off`, and refusal in combat.
  - A combat-start test: `PLAYER_REGEN_DISABLED` ends test mode and the checkbox reads false.
  - `test_launcher`: left-click toggles test mode.
  - `test_pages_general`: the Test mode row is present, in the second column beside Minimap
    button, and a session row.
  - A *Reset all settings* test.

## B2. Spell lists: an X icon instead of checkboxes and Remove buttons

**Today.** LibKa0s's `IdList` (`libs/LibKa0s/OptionsWidgets.lua:2540-2560`, `entryAction`) draws, on the
**right** of each row, a **checkbox** for a toggle entry (a starter spell) or a **Remove** button for
any other entry. General → Spell Categories marks starters as toggles (`settings/GeneralSpells.lua`
`entriesFor`), and a starter unticked is stored `false`.

**Change: the library (owner's choice, opt-in).**
- **LibKa0s** (`../LibKa0s`) gains an opt-in IdList spec key **`removeStyle = "icon"`**.
  - With it, every entry draws a small **X button on the LEFT** of the row, before the spell icon
    and name. It uses the atlas **`transmog-icon-remove`** (ConsumableMaster's delete icon), about
    16 px, with the tooltip *"Remove"* (a `strings.remove` override is honoured).
  - A click calls `spec.onRemove(id)` and rebuilds the list.
  - Toggle entries are not drawn differently under this style. The host simply sends no `toggle`
    entries.
  - With the key absent, the list is **byte-for-byte unchanged**, so no other addon's look changes
    until it opts in.
- The library change follows library-stack-§7:
  - a new **minor** (`v1.44.0`), with the `LibStub` minor of the options file bumped;
  - `docs/api/Options` documents `removeStyle`;
  - a CHANGELOG entry;
  - LibKa0s tests covering both styles.
- The **tag and push of LibKa0s wait for the owner** (the plan stops there for a go-ahead).
- Aura Master then re-vendors LibKa0s v1.44.0, both payloads (`libs/LibKa0s/`, `tests/_kit/`), and
  updates the CLAUDE.md provenance line in the same change, per the re-vendor procedure.

**Change: Aura Master.**
- **General → Spell Categories:**
  - `removeStyle = "icon"`.
  - `entriesFor` no longer emits toggle entries. It lists the starters that are **not** removed,
    then the added spells, all removable.
  - `onRemove(id)`: a starter is stored `false` (hidden), an added spell `nil`. `onToggle` goes away.
  - **Restoring a removed starter:** the existing **"Restore this category's starter list"** button
    (it clears every edit to the category; unchanged behaviour) **moves to the top**, right under the
    Category dropdown and above *Add a spell*. Re-adding a starter by typing it still works (`onAdd`
    already drops its `false`).
  - The intro sentence changes from "Untick one to leave it out" to "Click X to leave one out;
    Restore brings the starter list back."
  - The restore tooltip says starters come back **and** added spells are removed (as today).
- **Filters → Overrides** (whitelist/blacklist) also opt in to `removeStyle = "icon"`, so every spell
  list in the addon looks the same. Their behaviour is unchanged: they only ever had Remove.
- **Tests:**
  - LibKa0s: both styles; the X on the left; the click routes to onRemove; the default is unchanged.
  - Aura Master `test_pages_general`: no checkbox; X per row; a removed starter is absent from the
    list and stored `false`; the restore button above the Add row; restore clears edits.
  - `test_pages_filters`: the overrides use the icon style.

## B3. The "Not in use" notice in muted gold

`settings/OptionsSetup.lua:521-525` `drawDisabledNotice` wraps the text in gray `|cff808080`. It becomes
a **muted gold**, from one constant: `C.NOTICE_COLOR = "ffc8a85a"` (`core/Constants.lua`), about
(0.78, 0.66, 0.35), readable against the dark panel and quieter than the title gold. The notice is
shared by every container page that declares `disabledNotice`, so Bars, Icons and the new Text page
all pick it up from this one change. `test_optionssetup`: the notice carries the new colour code.
The standard sets no colour for page notices; the combat-refusal "gray notice" in options-ui (refusing to open settings in combat) is a
chat line, not this, so this is not a deviation.

## B4. Bars time text no longer truncates

**Observed.** On a default bar (220 px, time text size 11, Blizzard format), a 59-minute Power Word:
Fortitude reads **"59..."**; "28 s" and "4 s" fit. Moving the time text's X offset from -4 to -15
changes nothing.

**Cause** (from the code): `modules/Style_Bars.lua` `timeBoxWidth` budgets
`fontSize × C.TIME_TEXT_EMS[fmt]` (`blizzard = 2.5`, `core/Constants.lua:150`), which is 27.5 px at size
11. That is too narrow for the formatter's spaced output with a wide glyph ("59 m"). The box then adds
`|x|`, which `Style.ApplyText` subtracts again, so the offset moves the text but can never widen its
box.

**Fix: measure, don't guess.**
- `Style.TimeTextWidth(t, fmt)` (new, `modules/Style.lua`) renders, into one hidden addon-owned
  scratch FontString (plain values, never secret), the widest strings the chosen format can produce:
  the formatter's own `Format` over a fixed sample set (59, 599, 3599, 35999, 86399, 863999 seconds).
- It returns the widest string width plus 2 px for the outline/shadow, cached per
  (font path, size, flags, format).
- `timeBoxWidth` uses it (plus the offset, as today) and falls back to the ems budget only when the
  scratch string can't be measured (the headless harness's mock returns a size-proportional width,
  which the tests pin).
- `C.TIME_TEXT_EMS` stays as that fallback.
- The same helper replaces any other place a time box is budgeted from ems (the plan greps
  `TIME_TEXT_EMS` and converts each use). The Text style's duration piece is auto-sized and needs
  none of this.
- **Tests:**
  - `test_style`: the box is at least the measured width of "59 m" at size 11; a larger font gives
    a wider box; the X offset doesn't shrink the box.
  - The cache key changes with the font.
- **Smoke:** the Fortitude case reads "59 m" in full.

## B5. Changing Style resets Fill to suit the new style (added 2026-09-19)

**Owner request.** Changing a container's **Style** (Containers → "What it shows, and how") resets its
**Fill** (Layout → Growth, `container.layout.axis`):
- Bars and Text → `vertical` ("Columns (fill top to bottom first)").
- Icons → `horizontal` ("Rows (fill left to right first)").

**Scope, as read from the request:** only `axis` is reset. `growH`, `growV`, `perLine`, `spacing` and
`lineSpacing` keep the player's values (the owner's screenshots show Right/Down in both cases, which
are also the template defaults). If the owner wants the grow directions reset too, it is one table
entry.

**Design.**
- `C.STYLE_FILL_AXIS = { bars = "vertical", text = "vertical", icons = "horizontal" }`
  (`core/Constants.lua`).
- The `container.style` row (`settings/Containers.lua:82-86`) gets an `onChange(value, id)` that, when
  the style actually changed, writes `container.layout.axis` through the one write seam
  (`NS.SetByPath`, for the same container id). It then runs the existing `structural` handler, so a
  single rebuild follows. The seam announces both writes, so the Layout page and the preview follow.
- It runs for every route that writes the style row: the dropdown, `/am set container.style …`, and
  the page's Defaults (a style reset to the template's `bars` resets Fill to Columns, which is
  consistent).
- It does **not** run for a duplicate, a copy-from, a profile switch or the starter seeding, because
  those don't go through the row's `onChange`. Their stored axis is kept as copied or seeded. The
  §7.1 Text starter is seeded `vertical`, and the Icons starters `horizontal`, as today.
- Re-selecting the same style does nothing: the seam doesn't call `onChange` for an unchanged
  value. Check this in `settings/Schema.lua`; if it does call it, guard on old ~= new.

**Tests** (`tests/test_pages_containers.lua` or `test_schema.lua`):
- bars → icons sets `horizontal`;
- icons → bars and icons → text set `vertical`;
- the grow directions are untouched;
- `/am set container.style icons` behaves the same;
- a duplicate keeps the source's axis;
- exactly one structural rebuild per style change.

**Smoke 16:** switch a container Bars → Icons → Text on the Containers page; Layout → Growth → Fill
reads Rows, then Columns.

## Part B smoke checks (added to §13)

11. **Unlock:** live auras keep drawing, and each container shows an outline and its handle. An
    empty container can still be dragged.
12. **Test mode:** the Master controls checkbox and `/am test` show placeholders without unlocking.
    Entering combat ends it. `/am test` in combat is refused with one line. The minimap left-click
    toggles it.
13. **Spell Categories:** an X on the left of every row and no checkboxes. X on a starter hides it.
    Restore (at the top) brings it back. The Overrides lists show the X too.
14. **The "Not in use" notice** is muted gold on Bars, Icons and Text.
15. **A 59-minute buff's time** reads in full on a default bar, and still does with the X offset at -15.
16. **Changing Style** resets Fill: Icons → Rows; Bars and Text → Columns. Grow directions are kept.
