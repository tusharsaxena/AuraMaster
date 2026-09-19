# Smoke-Test Feedback Batch 2 — Design

**Date:** 2026-09-19. **Source:** the owner's in-game pass over the `feat/smoke-feedback` build (items
1–8 and the combat settings errors). **Branch:** Aura Master `feat/smoke-feedback-2`, from `master`
(which carries the unpushed `feat/smoke-feedback` merge, 799ddda).

Every root cause below was traced read-only before this spec was written; file:line citations are to
the tree at 799ddda (Aura Master) and v1.45.0 / `2b32ee8` (LibKa0s).

## Owner decisions (2026-09-19)

- **D-1 Combat lock scope:** fix it in LibKa0s, release **v1.46.0**, re-vendor into **all 11**
  consumers (AbsorbTracker, AuraMaster, BankLedger, ConsumableMaster, KickCD, LootHistory, MultiMeters,
  PanelMaster, PartyFrameEnhanced, PrettyChat, WhatGroup), as the v1.45.0 round did.
- **D-2 Lock everything:** the combat lock covers the **whole page, tab strip included**. This
  contradicts options-ui-§13 ("a tab click works in combat and a host MUST NOT add a guard that
  refuses one"), so the **standard changes upstream first** (WowAddonStandards, minor bump), then the
  library conforms.
- **D-3 Anchor wording:** Point / Relative point are reworded as the corner of the **first aura**, plus
  a hint when the anchor side and the growth direction point at each other.

## Items

### ⚔ Combat: the settings window breaks when a page is shown in combat (LibKa0s)

**Cause.** `LibKa0s/Options.lua:1040-1052` (`O.SetRenderer`): the panel's `OnShow`, in combat, calls
`SettingsPanel:Close()` (fallback `HideUIPanel(SettingsPanel)`). The AddOns sidebar reaches that
`OnShow` from inside Blizzard's `DisplayCategory → DisplayLayout → Show`, so the close runs from addon
code: `Close → ExitWithCommit → Commit → CommitBindings → SaveBindings()` (protected →
`ADDON_ACTION_BLOCKED`), then `TransitionBackOpeningPanel → ToggleGameMenu` re-enters the half-shown
panel's close path → `C stack overflow` cascade. Nothing refuses writes in combat
(`OptionsWidgets.lua:997-1000` `write`, `:1046-1049` `set`, `Options.lua:875-895` `runBulk`), which is
why the owner's mid-combat changes applied afterwards.

**Design (LibKa0s, Options minor 21→22, OptionsWidgets 22→23; `docs/api/` pages follow).**
- **Never touch `SettingsPanel` in combat.** Remove the close/`HideUIPanel`; no `ToggleGameMenu`,
  `OpenToCategory`, and no read/write of `SettingsPanel` fields while `InCombatLockdown()`.
- **A combat cover per registered page** (`ctx`): a plain, non-secure `Frame` parented to `ctx.panel`,
  covering the **whole page — the header band and the tab strip included** (D-2), at a frame level
  above everything the page draws, `EnableMouse(true)` + `EnableMouseWheel(true)`, with a centered
  gray line "Settings are locked during combat." Built once, out of combat (at panel creation or the
  first out-of-combat show). No `SetPropagateKeyboardInput`, no hooks on `SettingsPanel`.
- **Show in combat:** show the cover, skip render and font preload, mark an unrendered page dirty;
  print nothing on every show (one gray notice per combat, the first time a locked page is shown or
  written).
- **`PLAYER_REGEN_DISABLED`:** `lib.combatLocked = true`; show the cover on every rendered page (it
  displays only while its panel is shown). Any open dropdown / color picker the library owns is closed
  where the library can do it without touching Blizzard's settings frame; otherwise the write seam
  refuses its commit.
- **`PLAYER_REGEN_ENABLED`:** hide the covers; a shown dirty/unrendered page renders, a shown clean one
  runs `RefreshScalars` (values changed by slash or profiles show up). Nothing is re-opened
  (options-ui-§2: no defer-and-replay).
- **Write seam refuses in combat:** `write()`, `runBulk` (Defaults, reset-all), structural
  `refreshCtx` / `renderCtx`, and tab switches refuse while locked and put the widget back via
  `RefreshScalars`. A consumer's slash `set` / reset verbs are **not** changed by this library release
  (they are not the settings window; each addon's own combat rules apply).
- **Tests (LibKa0s headless):** cover shown on show-in-combat with no `SettingsPanel` call (a recorder
  that fails any `SettingsPanel` method call in combat); cover on REGEN_DISABLED over a shown page and
  its tab strip; a write, a Defaults and a tab click refused in combat; the cover lifts and a dirty page
  renders on REGEN_ENABLED; out of combat nothing changes.

**Standard (upstream first, D-2).** WowAddonStandards minor bump (v2.59.1 → **v2.60.0**):
- **options-ui-§2** gains: an addon **MUST NOT** close, hide or commit Blizzard's settings window
  (`SettingsPanel:Close`, `HideUIPanel(SettingsPanel)`, `ToggleGameMenu`, `OpenToCategory`) from its
  own code in combat — a page shown in combat (the AddOns sidebar path) is **locked**: a cover over the
  whole page states it, and every write through the options surface is refused until
  `PLAYER_REGEN_ENABLED`, when the page renders from current state. New anti-pattern: closing the
  settings window from addon code in combat.
- **options-ui-§13**'s "a tab click works in combat and a host MUST NOT add a guard that refuses one"
  is replaced: the combat lock covers the tab strip too, and the library (not the host) owns it; a host
  still MUST NOT add its own tab guard.
- Ripple per the standard's own process: `STANDARDS.md` index blurb and version line, changelog entry,
  anti-pattern range, `EXECUTIVE_SUMMARY.md` / `NEW_ADDON_CONTEXT.md` where they state the tab rule,
  and any playbook (`AUDIT.md`) line that checks the old rule.

### 1. Growth and anchor

**Cause (the bug).** The engine frame is pinned to the one-element anchor at the growth corner **only
in `Build`** (`modules/Container.lua:225-227`); after the first `AddAuraGroup` it cannot be re-anchored
(`Container.lua:223-224`, `docs/midnight-quirks.md:274`). `Apply` chooses rebuild vs in-place by
`structure = FilterCompiler.StructureKey(plan)..":"..Style.StructureKey(cfg)` (`Container.lua:364-370`),
which carries no growth (`FilterCompiler.lua:767-770`, `Style.lua:519-523`). A Grow vertically / Grow
horizontally / Fill change therefore updates in place (`Container.lua:287-292`) and `applyFlow` sends a
new flow anchor point while the engine stays pinned at the old corner — Up-after-Down hangs the block
below the anchor with the handle (correctly on the away side, `Anchors.lua:497-510`) in the middle.
`/reload` and test mode (`Preview.lua:46-71`) look right, which is why it was missed. Followers
attached to a container inherit the parent's growth and hit it too (`Anchors.lua:145-171`).

**Fix.** Append the effective growth corner (`NS.Container.FlowSettings(cfg).anchorPoint`) to the
structure key, so a corner change retires and rebuilds the engine (the parent's growth write already
re-applies its followers, `Anchors.lua:111-118`). An axis-only change keeps the corner and stays in
place. Cost: one more retired engine frame per corner change, settings-time only, never in combat
(applies defer, `ContainerManager.MustDefer`).

**Wording (D-3).** Point / Relative point (`settings/Layout.lua:136` promises "the corner of this
container that is attached") are reworded to the corner of the **first aura** — the container's full
extent is secret and cannot be anchored. A hint line on Layout → Anchor shows when the anchor's
vertical side and Grow vertically point at each other (a BOTTOM* point with Grow Down, a TOP* point with
Grow Up) — and the horizontal equivalent — saying the auras will grow back across what the container is
attached to, and which growth to pick instead. Docs (`settings-panel.md`, `smoke-tests.md:46`) follow.

**Tests.** Flip `growV` down→up and apply: the engine is retired, the new engine's first `SetPoint` is
the BOTTOM corner and precedes `AddAuraGroup`; same for `growH`; a spacing / per-line change still
updates in place; a parent's growth flip rebuilds its follower's engine at the derived corner; the hint
shows exactly for the facing combinations.

### 2. "Many debuffs have no dispel type"

**Finding — no code bug.** Text and bars read the **same** engine key, `auraData.dispelName or "None"`
(`Blizzard_CustomAuraButton.lua:397-398`), through `customDispelTextMap` (`Style_Text.lua:405-420`, no
`None`, `showWithoutDispelType=false`) and `customDispelColorMap` (`Style.lua:414-425`, `None` and
Enrage take the surface's own color). They cannot disagree about one aura. The Paladin debuffs
(Consecration, Judgment, Empyrean Hammer, Seal of Reprisal, Blessed Hammer) almost certainly carry no
dispel type; the druid bleeds carry `Bleed` (red, `core/Constants.lua:175`). The blue on those bars is
most likely the default **fill** (`barColor` 0.20/0.55/0.95, `defaults/Profile.lua:166`), near the Magic
swatch (0.20/0.60/1.00, `Constants.lua:171`).

**Change.** Reword the strings that imply a typeless debuff is rare (they cite only Mystic Touch:
`locales/enUS.lua:114`, `:608`, `settings/Bars.lua:124`) to say many class debuffs have none. Hand the
owner the out-of-combat `/run` probe (in the batch report; it prints name, auraInstanceID,
isFromPlayerOrPlayerPet, dispelName and the curve's enum, every value through an `issecretvalue`
guard, every call in a `pcall`) and record its result in `docs/midnight-quirks.md` when it comes back.
No addon debug line: addon code cannot read aura data in combat.

### 3. A note on Text → Justify Center

Add a note row under Justify on Text → General (the collection's note widget; `NS.L` strings):

> Center centers the line only when the template is a single piece. With several fields, each field
> (name, stacks, dispel type, and the duration tokens together) gets its own centered row, text outside
> [ ] is not drawn, and the box grows to fit the rows. Rows keep their place even when a field is empty
> (one stack, no dispel type, no duration), and an icon at size 0 is one row tall. Aura text is secret,
> so its width can't be measured to center several fields on one line.

Facts behind it: `Text.Stacked` (`Style_Text.lua:222-224`), rows (`:256-271`), height
(`Style.lua:461`, `Style_Text.lua:239-244`), icon (`:205`). `docs/settings-panel.md` follows.

### 4. Bars: dispel-colored background ignores Background opacity

**Cause.** The engine's `customDispelColorMap` values are `colorRGB` (no alpha): `SetVertexColor`
paints alpha 1, dropping `bgColor.a` (and `barColor.a` for the fill) (`Style_Bars.lua:311-313`, map at
`Style.lua:414-425`). Possible second cause: `AddDispelTypeTexture` marks the texture's Alpha aspect
secret, so a later tainted `am.bg:SetAlpha` may not land.

**Fix.** In dispel mode, build map entries at alpha 1 and carry the opacity on the region:
`am.bg:SetAlpha(bgAlpha * bgColor.a)` in `applySurfaces`, likewise the fill with
`barAlpha * barColor.a` (plain config numbers, no secret arithmetic). If the in-game check shows the
region alpha is refused, the background moves onto its own child frame and the frame's alpha carries
it (the engine never marks frame alpha secret) — decided by the smoke item, not guessed.

**Tests.** Dispel mode with `bgColor.a = 0.5`, `bgAlpha = 0.4` records `SetAlpha(0.2)` on `am.bg`; the
fill likewise; map entries carry a = 1; static mode unchanged.

### 5. Move Text → Animation → Dispel type to Text → Font

A group/order move in `settings/Text.lua`; paths and stored values unchanged (no migration). Tests
that locate the rows by tab follow; `docs/settings-panel.md` follows.

### 6. Text → Icon border does nothing

**Cause.** The Text style draws the icon and its border only when Icon position is Left or Right
(`Style_Text.lua:199-203`); the default is `NONE` (`defaults/Profile.lua:221`), and the Icon tab's rows
(`settings/Text.lua:330-349`) carry no `disabledIf`, so they look live and draw nothing.

**Fix.** Every Icon-tab row except Icon position dims while the icon is `NONE`, with a note "Set Icon
position to show the icon." **Tests:** rows dimmed on `NONE`, live on `LEFT`; icon `LEFT` with the
border on shows `am.iconBorder` with the configured edge size and color (today only "hidden" is
asserted, `test_style_text.lua:430`).

### 7. The template "breaks" after any Text setting change

**Finding.** Not reproducible headless (a scratch probe re-dressed the owner's template with every
option on, no error). What is certain: `Container:Restyle` drops every re-dress error in a bare `pcall`
(`Container.lua:329,335`) though `Style.Element` builds a stack and re-raises (`Style.lua:566-568`); and
the owner's picture — every row an empty bordered square, no text — is exactly the state an error leaves
between `Text.Apply` clearing the icon art's and text area's anchors (`Style_Text.lua:197-198`),
`Style.LayoutIcon` drawing the icon border (`Style.lua:170-175`), and the re-anchoring that follows
(`Style.lua:177-179`, `Style_Text.lua:209-210`). It needs the icon on, and a restyle of a button the
engine already owns — a first dress does not hit it.

**Fix (defensive, then diagnose).** (a) Report the swallowed re-dress error: one `NS.Debug("Style", …)`
line with the message, and `geterrorhandler()` once per session, so `scriptErrors 1` names it. (b)
Re-order the Text layout so the text area is anchored **before** any icon or border call (its size and
inset are plain arithmetic). (c) Guard the icon/border block (the `Style.Bind` pattern), so a refused
client call costs the icon only, never the text. **Tests:** a recorder whose `am.iconBorder:SetBackdrop`
(and separately `am.icon:SetSize`) raises on a live re-dress: the text area keeps both anchors, the
chain head is anchored, the text binding is still bound, and the error is reported. **Smoke:** the owner
re-runs the failing sequence with `/am debug` and `scriptErrors 1`; the named line decides whether a
further fix is owed.

### 8. Extra whitespace between tokens

**Cause.** Each unbracketed literal and each field is its own font string (`TextTemplate.lua:345-373`,
`Style_Text.lua:161-170`), chained edge to edge at offset 0 (`Style_Text.lua:293-297`); the duration run
is one engine string, which is why `6 s-32 s-26 s-19-81` has no gaps. An empty field still has width
(`midnight-quirks.md:318`), and the pieces carry no `SetJustifyH`, so the client's default padding sits
on both sides of each piece.

**Fix.** Each chained piece gets `SetJustifyH` matching its side of the chain; the per-string padding is
measured once per font/size/flags on the addon's own non-secret measurer (`W("a") + W("b") - W("ab")`,
like `Style.TimeTextWidth`) and each chained piece is anchored at `-pad` (fallback 0 when it cannot be
measured). An empty field's width cannot be detected (secret), so the Text Template **Rules** list and
the docs recommend separators inside brackets (`$spellname$[-$stacks$]`). **Tests:** the chain uses the
measured offset and falls back to 0; every piece carries its side's justify. **Smoke:** the owner's
template prints `Fire Breath-Magic-6 s-…` spacing-free wherever a field is non-empty.

## Order and risk

1. **WowAddonStandards v2.60.0** (the rule change D-2 needs) — committed on its `master`, **stops before
   push** for the owner.
2. **LibKa0s v1.46.0** — the combat lock, its tests, `docs/api/`, CHANGELOG, the release bundle; stops
   **before the tag and push** for the owner.
3. **Aura Master items 1–8** on `feat/smoke-feedback-2`, one commit per item, gate green after each —
   independent of 1–2, can run while they wait.
4. **Re-vendor v1.46.0** into the 11 consumers, each on `chore/libka0s-v1.46.0` (Aura Master's on its
   feature branch), after the owner tags.
5. Final gate in every touched repo; smoke items appended to Aura Master's `docs/smoke-tests.md`
   (section U) and to the library's smoke/record where it keeps one.

Nothing is merged, pushed, tagged or version-bumped without the owner's go-ahead.

## In-game checks owed after

- Settings open, enter combat: every page shows the lock cover, tabs included; clicking, dragging,
  typing, Defaults do nothing; switching category in the sidebar raises no error and does not close the
  window; `/console scriptErrors 1` shows nothing; after combat the page is live and current.
- Growth flip Down→Up (and Right→Left) without reloading, screen- and frame-attached, and a follower.
- The facing-growth hint; the reworded Point rows.
- The probe output for item 2.
- Bars at 20% background opacity in dispel mode, typed and typeless, in and out of combat.
- Justify note; the moved Dispel type rows; the dimmed Icon rows; the icon border drawn when on.
- Item 7's sequence with `/am debug` and `scriptErrors 1`.
- The owner's all-tokens template spacing.
