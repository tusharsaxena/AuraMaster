# Compat layer

`core/Compat.lua` publishes **22** shims on `NS.Compat`, counted with the command documentation-§3
fixes:

```sh
grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua    # 22
```

A shim is the one entry point a feature module calls in place of a new-in-12.x, version-variant or
enum-valued client API, so a renamed enum or a moved function is a one-file fix, and a headless run
(where none of these globals exist) degrades to a plain answer (compat). Retail only: every shim
covers a cross-**patch** difference, never a game flavor. What LibKa0s already supplies — the TOC
metadata ladder (`LibKa0s-Env-1.0`, `core/EnvSetup.lua`), the secret-safe stringifier
(`LibKa0s-Core-1.0`), and the spell-info reader and the three secret guards
(`LibKa0s-Compat-1.0`) — is not repeated here. Shim 16 delegates to that last major behind this
addon's number-only guard; the guards are wired in `core/Secrets.lua`, whose own bodies are only
their library-absent arm.

## The shims

| # | Shim | Wraps | Fallback | Why it exists | Called from |
|---|---|---|---|---|---|
| 1 | `HasAuraContainer()` | `AuraContainerSortMethod` and `CreateFrame` present | `false` | Without the 12.1 engine nothing can be drawn; say so once instead of erroring per render | `modules/Container.lua` (and shim 17 `EnsureAuraContainer`) |
| 2 | `AurasAreSecret()` | `C_Secrets.ShouldAurasBeSecret()` (pcall) | `false` | The gate in front of every apply, restyle and aura scan | `modules/ContainerManager.lua`, `modules/TimedSpells.lua` |
| 3 | `SortMethod(key)` | `AuraContainerSortMethod[member]` via `SORT_METHOD_ENGINE` | `0` | The addon stores its own sort keys; the engine enum is looked up at call time | `modules/Container.lua` |
| 4 | `SortDirection(key)` | `AuraContainerSortDirection.Normal/Reverse` | `0` / `1` | Same | `modules/Container.lua` |
| 5 | `EnchantSlot(key)` | `AuraContainerItemEnchantmentSlot.MainHand/OffHand/Ranged` | `0` / `1` / `2` | Same, for `AddItemEnchantment` | `modules/Container.lua` |
| 6 | `EnchantSortByDuration()` | `AuraContainerItemEnchantmentSortMethod.Duration` | `1` | Enchant ordering | `modules/Container.lua` |
| 7 | `EnchantPlacementAfter()` | `CustomAuraContainerItemEnchantmentPlacement.AfterAuraGroups` | `1` | Enchants drawn after the aura groups | `modules/Container.lua` |
| 8 | `FlowAxis(axis)` | `AnchorUtil.FlowLayoutAxis` | the string | The engine's flow layout axis | `modules/Container.lua` |
| 9 | `FlowDirection(dir)` | `AnchorUtil.FlowDirection` | the string | The engine's growth directions | `modules/Container.lua` |
| 10 | `TimerDirection(which)` | `Enum.StatusBarTimerDirection` | `nil` | The elapsed-time status bar behind the full-bar fill | `modules/Style_Bars.lua` |
| 11 | `Interpolation(smooth)` | `Enum.StatusBarInterpolation` | `nil` | The Smooth animation option | `modules/Style_Bars.lua` |
| 12 | `DispelStyle(member)` | `Enum.CustomAuraButtonDispelTypeTextureStyle` | `nil` | Dispel-colored fill (`PreserveAsset`) and icon border (`Border`) | `modules/Style_Bars.lua`, `modules/Style_Icons.lua` |
| 13 | `CreateSecondsFormatter(format)` | `C_StringUtil.CreateSecondsFormatter` plus its setup (pcall); Blizzard's step curve from `C_CurveUtil.CreateCurve` | `nil` (the engine's own format); no curve → a `Days` maximum | The engine formats a secret duration the addon never sees | `modules/Style.lua` |
| 14 | `ExpiringTextColor(threshold, expiring, normal)` | `C_CurveUtil.CreateColorCurve` step curve over `DurationTextBindingProperty.RemainingDuration` | `nil` (text keeps its font color) | Recolor the time text in the last seconds without comparing a secret | `modules/Style.lua` |
| 15 | `GetMouseFocus()` | `GetMouseFoci()[1]` | `nil` | `GetMouseFocus` was removed in 11.0 | `modules/FramePicker.lua` |
| 16 | `GetSpellInfo(id)` | `LibKa0s-Compat-1.0`'s `GetSpellInfo` (`C_Spell.GetSpellInfo`, then the old global with its rank dropped): `name, iconID, castTime, minRange, maxRange, spellID`, callers read `name`; a non-number id answers `nil` here, before the library | `nil` (also the answer without the library: the major's documented no-rung value) | Spell names for the spell lists' sort and the cast-aura and overlap messages, and the test-mode placeholders' names and icons | `settings/GeneralSpells.lua`, `modules/CastAura.lua`, `modules/Preview.lua` |
| 17 | `EnsureAuraContainer()` | `C_AddOns.LoadAddOn("Blizzard_AuraContainer")` when it is not loaded (pcall), then `HasAuraContainer()` | `HasAuraContainer()` | `Blizzard_AuraContainer` is load-on-demand: until it loads, neither `CustomAuraContainerTemplate` nor the enums shims 3–7 read exist (`docs/midnight-quirks.md`) | `modules/ContainerManager.lua` (`CM.Init`) |
| 18 | `DurationProperty(member)` | `Enum.DurationTextBindingProperty[member]` | `nil` | Each `{}` of a Text-style duration run names the property it reads | `modules/Style.lua` |
| 19 | `CreateRuleFormatter(breakpoints)` | `C_StringUtil.CreateNumericRuleFormatter` + `SetBreakpoints` (pcall) | `nil` | The Text style's stack count (hidden below 2) and its percent components (`%d`, rounded by `step = 1`; a client refusing `step` gets plain `%d`) | `modules/Style.lua`, `modules/Style_Text.lua` |
| 20 | `CreateDurationBinding(interval)` | `C_DurationUtil.CreateDurationTextBinding` + `SetZeroDurationText("")`, `SetExpiredText("")`, `SetUpdateInterval` only for a blink (pcall) | `nil` | A timeless or expired aura writes no duration text, bracket text included | `modules/Style_Text.lua` |
| 21 | `BlinkTextColor(threshold, blink, normal)` | `C_CurveUtil.CreateColorCurve` step curve over `RemainingDuration`, alternating alpha every 0.25 s | `nil` | Blink the Text style's duration run in the last seconds without reading a secret | `modules/Style.lua` |
| 22 | `SetAuraBorderColor(region, dispelType)` | `AuraUtil.SetAuraBorderColor(region, type)`, Blizzard's own color for the type, as the engine's `PreserveAsset` style paints with no `customDispelColorMap`; without `AuraUtil`, the client's `DebuffTypeColor[type]` | `false` (no region, no type, or no color for it) | A test-mode icon has no engine to tint its dispel strips (batch 8 TD-4, DB-1) | `modules/Style_Icons.lua` |

## Rules for this file

- A feature module calls `NS.Compat.X`, never the global it wraps.
- Every shim answers something sensible when the API is absent, because the headless harness has
  none of them.
- No `WOW_PROJECT_ID` branching; Retail patch differences only.
- A new shim adds a row here and moves the count in `docs/ARCHITECTURE.md`'s Documentation map.
