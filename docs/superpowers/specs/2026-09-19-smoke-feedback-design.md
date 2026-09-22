# Smoke-test feedback batch — design spec

- **Date:** 2026-09-19
- **Source:** the owner's in-game smoke-test feedback on the Text-style release (items #1–#10 plus a
  Lua error), given the same day.
- **Status:** decisions taken 2026-09-19 (#1 stacked centering; #6 enchants as a category only).
  Not yet planned.
- **Repos:** AuraMaster (all items); LibKa0s (#4's new widget, a new minor + release); every Ka0s
  addon with a dropdown that gates sections (#4 adoption; PartyFrameEnhanced at least).
- **Binding:** the Ka0s WoW Addon Standard (v2.59.1). Any deviation stops and is flagged.

## E. The Lua error — attaching to another frame

**Observed.** `modules/Anchors.lua:452: attempt to perform arithmetic on a secret number value
(execution tainted by 'AuraMaster')`, out of combat, when a container is attached to another frame.
It comes from `placeHandle` → `handle.label:GetStringWidth()`. The handle is anchored to the
container's anchor. Once that anchor is attached to a frame whose geometry is secret (an engine
container, or a frame anchored to one), the handle's anchoring is secret too, so its label's width
reads secret.

**Fix.** Never read a measurement off a region that may be anchored to secret geometry.
- Measure the label's width on a detached, never-anchored font string with the same font and text.
  That is the `Style.__measurer` pattern from B4.
- Take the width only through `NS.Secrets.IsReadableNumber`. When it isn't readable, fall back to
  the element width (the old `math.max` floor).
- Sweep `modules/Anchors.lua` and `modules/Container.lua` for other `Get*Width` / `GetLeft` /
  `GetPoint` reads on regions that can be attached, and guard them the same way.
- **Test:** the anchor/handle suite makes `GetStringWidth` return a secret (the kit's secret mock).
  `UpdateHandle` must not raise, and the handle must get a sane width.

## 1. Justify = Center: stacked rows (owner decision)

The probes proved a multi-piece line's width is unreadable, and no addon code runs when the engine
changes text in combat, so a multi-piece line can't be centered as one line. **Center** therefore
lays the line out **stacked**:
- Each **field piece** (name, stacks, dispel, the duration run) gets its own row, centered
  horizontally in the box, in template order, top to bottom.
- Folded bracket text rides with its field and hides with it.
- **Plain literal pieces are not drawn in Center.** A literal between two rows has nothing to sit
  between. The Justify tooltip says so and suggests brackets, which fold text into a field.
- **A row can't collapse when its field is empty**, because a secret-empty font string still holds
  its row. The spec accepts that: rows are fixed in position. The row height is the font's line
  height plus a small gap; the element height follows the row count.
  - Where the box height the player set is smaller than the rows need, the box grows to fit. The
    height slider's tooltip says Center sizes by rows.
- `justifyV` places the stack within the box (top, middle or bottom).
- A single-piece template centers as one line, as today; that is the same thing as a one-row stack.
- Everything stays engine-bound, with no Lua in combat, as today.
- The "Player cooldowns" starter keeps Left. The new built-in templates (§5) include an
  "above the head" centered one.
- **Tests:** row order and anchors (each row `CENTER` under the previous one); literal pieces not
  drawn; the element height for N rows; `justifyV` placement; and a single piece identical to
  today's Center.

## 2. Containers page: the banner above the tab strip

Move the **container dropdown** and the **New container** button out of the tab content, to sit
**above the tab strip**, matching the banner the Filters / Layout / Bars / Icons / Text sub-pages
use (the same helper). Behavior is unchanged. Tests assert that the order is banner, then tabs.

## 3. Spell Categories: Restore beside the Category dropdown

Put **"Restore this category's starter list"** on the **same row, to the right of the Category
dropdown** (`H.RenderGrid` cells: dropdown plus button). Today it sits under the dropdown. The
behavior is unchanged; the test asserts that both are in the same grid row, the button second.

## 4. Sections chosen by a dropdown are shown, not dimmed (LibKa0s widget + adoption)

**Today.** Layout → Anchor has an **Attach to** dropdown (Screen / Another container / Named frame).
The three subsections under it are all drawn, and the two that don't apply are **disabled and
dimmed** through `disabledIf`.

**Change.** Only the **selected** subsection is drawn; the others are **hidden outright** (not
rendered, no reserved space). Switching the dropdown redraws the tab.

**A LibKa0s widget ("switched sections").** This is conceptually a tab strip whose selector is a
dropdown, so it belongs in the library:
- A row (or group) option names a **selector path** and the **value that shows it**. For example, a
  subsection declared with `shownWhen = { path = "container.attach.mode", equals = "container" }`.
  The flow engine skips the subsection's rows (heading included) when the selector's current value
  doesn't match, and re-renders the tab when the selector changes.
- It is data-driven and generic, so any consumer can declare it on existing rows without bespoke
  render code.
- It lands in LibKa0s's Options major as an **opt-in** key. With it absent, rendering is
  byte-for-byte unchanged.
- The release follows LibKa0s's own procedure (docs/api, CHANGELOG, tests, the minor bump,
  `--release`, commit, tag, push), then a re-vendor into every consumer, as with v1.44.0.

**Adoption.**
- **AuraMaster:** Layout → Anchor (Screen / Another container / Named frame), plus any other
  dropdown-gated group the sweep finds in AuraMaster.
- **PartyFrameEnhanced:** Cast Bars → Size & Position → Placement, and the same shape under Target
  Frames and Pet Frames.
- **Every other Ka0s addon:** a sweep for `disabledIf` predicates keyed on one dropdown's value
  that gate a whole subsection. Each hit is adopted, or reported as not a fit (for example, a single
  row dimmed by a checkbox stays dimmed: this is for dropdown-chosen **sections**).
- A dimmed row the standard requires to stay visible (a color swatch, anti-pattern #74) is not a
  section and is left alone.
- **Standard check:** options-ui governs disabled-vs-hidden. If it requires dimming rather than
  hiding for this shape, **stop and flag** before implementing: either a deviation row, or an
  upstream change to the standard (the owner asked for this behavior collection-wide, so the
  upstream route is the likely one).

## 5. Templates: token output and built-in templates

**Token output.**
- **Percent tokens carry no `%`.** `$remainingpercent$` / `$elapsedpercent$` render the bare number
  (rule format `"%d"`); the player writes the `%` in the template.
- **No leading or trailing whitespace from any token.** Every format Aura Master hands the engine
  is trimmed. The seconds formatter's own unit spacing ("12 s") is Blizzard's `SecondsFormatter`
  output, and the abbreviation setup is chosen to add no trailing space.
- **The stray space in `( )` must be traced.** The owner's `($remainingpercent$)` rendered `( )`.
  Find where the space comes from (the rule formatter's output, the zero-duration text, or the
  format string). Fix what the addon controls, and confirm in game (a smoke item). Addon code
  cannot trim the engine's secret output after the fact.
- **Timeless auras:** text outside `[ ]` always shows, by design (§3.2 of the Text-style spec). The
  built-in templates wrap every duration run in brackets, so `Aura name   )` can't happen with them,
  and the cheat sheet gains a one-line example of the bracketed form.

**Built-in templates.** On Text → General, above the template box:
- A **Template** dropdown listing built-in templates for the container's aura type, plus **Custom**.
- Choosing a built-in writes its template string. Choosing **Custom** reveals the template edit box
  (hidden otherwise), seeded with the current template.
- A stored template that matches no built-in reads as Custom.
- A **Preview** line under the dropdown or edit box renders the template against a sample aura (the
  preview placeholder path, readable values), so the player sees the result before closing the
  panel. It updates on every change.
- **Built-ins** (localized labels; the exact strings are pinned in the plan):
  - **Buffs:** "Name" (`$spellname$`); "Name + time"
    (`$spellname$[ - $remainingduration$]`); "Name, stacks, time"
    (`$spellname$[ x$stacks$][ - $remainingduration$]`, today's default); "Time / max"
    (`$spellname$[ $remainingduration$ / $maxduration$]`); "Centered: name over time" (the same
    as "Name + time", with Justify set to Center).
  - **Debuffs:** the buff set, plus "Name (type)" (`$spellname$[ ($dispeltype$)]`) and "Name, type,
    time".
  - Weapon enchants no longer have an aura type (§6), so they use the buff set.
- **Tests:** the dropdown lists per aura type; picking one writes the string; Custom reveals the
  box; an unmatched stored template reads as Custom; the preview renders brackets and hides empty
  ones; the percent format has no `%`.

## 6. Weapon enchants: a buff category only (owner decision)

**Today** there are three surfaces: the **Aura type** "Weapon enchants" (an enchant-only
container), the buff **category** "Weapon enchants" (enchants mixed into a buff list, Show/Hide per
container), and the **profile-wide enchant slot** toggles (General → Spell Categories → Weapon
enchants).

**Change.**
- **Remove the "Weapon enchants" Aura type.** `C.AURA_TYPES` becomes `HELPFUL`, `HARMFUL`.
- Enchants are shown by the buff category; an enchant-only container is a buff container whose
  categories are all Hidden except Weapon enchants.
- The slot toggles stay where they are.
- **Migration (a schemaVersion step in `core/Database.lua`):** every stored container with
  `auraType == "ENCHANT"` becomes `auraType = "HELPFUL"`, with categories from
  `Cat.StatesShowing({ "weaponEnchants" })` (every other buff category hidden, Uncategorized
  hidden). Its unit is forced to `player`, and `hidePermanentEnchants` carries over. Styling and
  position are untouched.
- The migration is logged with one `[Migrate]` debug line per container, and tested on a fixture
  profile.
- All code, docs, locale strings and tests that branch on `ENCHANT` as an aura type are removed or
  folded: the FilterCompiler enchant path becomes the category path only; Containers page choices;
  `/am new` words; the `ENCHANT_UNIT` warning; the preview; Style_* enchant-specific binds.

## 7. Color by dispel type (debuffs)

- **Text style:** a new option **Color by → Font color / Dispel type** (debuff containers only).
  With Dispel type, each piece's text color follows the aura's dispel type from the profile's
  Dispel Colors, and falls back to the font color when the aura has no type.
  - The engine binding is `AddDispelTypeTexture`-style for regions; for text, research the
    supported binding. `SetDispelTypeText` writes text, not color, so the plan must find a
    color path: a color curve keyed by dispel type, or `customDispelColorCurve` on a region
    behind the text.
  - **If there is no engine path to color text by dispel type in combat, stop and report.** Offer a
    dispel-colored backdrop or edge on the Text box instead.
- **Bars style:** the fill already has Color by → Dispel type. **Add the same for the bar
  background** (`bgColorMode`), using the same map and the same fallback to the background color.
- **The fallback when there is no dispel type** (owner decision): the normal bar / background /
  text color.
- **Mystic Touch and similar debuffs show no type because they have none.** The engine reports a
  dispel type only for dispellable categories (Magic, Curse, Disease, Poison, Bleed, Enrage);
  Mystic Touch is not dispellable, so it takes the fallback color. A settings tooltip says so.
- **Tests:** option rows only on debuff containers; the bindings carry the color map and fallback;
  the preview shows the Magic stand-in color as Bars does today.

## 8. Test mode shows in the unlocked anchor

While test mode is on, each container's drag handle, and the anchor strip when unlocked, shows a
visible **TEST** marker next to the container name (for example, an orange "TEST" tag on the label),
so the player can tell placeholders from live auras. It updates when test mode toggles. Test:
handle label text or tag shown iff `NS.State.testMode`.

## 9. Right-click the handle's "?" → the Containers page, that container selected

Right-clicking the **?** on an unlocked container's handle opens the settings panel to the
**Containers** page with **that container** selected in the banner dropdown. Left-click keeps its
current behavior. It uses the existing panel-open seam (`/am config` path) and
`NS.State.activeContainerId`. In combat it's refused, the same as opening settings today (the
options-ui combat refusal line). Tests: the right-click handler selects the id and opens the page;
refused under lockdown.

## 10. Filters → Categories: "Show all" / "Hide all"

At the top of the **Blizzard categories** section and of the **Spell categories** section, add
**Show all** and **Hide all** buttons. Each writes every category in that section for the selected
container through the seam, as one bulk write (one apply, one `[Set]` summary line). Tests: each
button sets exactly its section's keys, leaves the other section alone, and makes one write batch.

## Order and risk

1. **E** (the error) and **#3, #2, #8, #10**: small and independent.
2. **#5 token output**, then **#5 built-in templates**, then **#1 stacked Center** (it uses #5's
   Center template).
3. **#6 enchant migration**: a schema step, so it's the riskiest single item.
4. **#7 dispel colors**: the text color path is a research gate.
5. **#9** handle right-click.
6. **#4**: LibKa0s widget, release, re-vendor to all consumers, adoption in AuraMaster +
   PartyFrameEnhanced + the sweep's hits. This is the largest item and spans repos.

**In-game checks owed after:** Center rows above the head; the `( )` space gone; the dispel-color
text path (if found); the enchant migration on a real profile; the switched sections in each
adopting addon.
