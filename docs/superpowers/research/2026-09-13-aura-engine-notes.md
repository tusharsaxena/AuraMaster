# Aura engine research notes: feedback batch 5 (Task R0)

- **Date:** 2026-09-13
- **Plan / spec:** `docs/superpowers/plans/2026-09-13-feedback-batch5.md` (Task R0),
  `docs/superpowers/specs/2026-09-13-feedback-batch5-design.md`
- **Source:** Gethe/wow-ui-source, branch `live`, fetched raw on 2026-09-13. Every path below is
  relative to that repo's root. Line numbers are those of the fetched copy.
- **Our code read for context:** `modules/Style.lua`, `modules/Style_Bars.lua`,
  `modules/Style_Icons.lua`, `modules/Preview.lua`, `core/Compat.lua`.

Files that carry the answers:

| File | What it holds |
|---|---|
| `Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.lua` | Every `CustomAuraButton` binding (`Set*` / `Add*` / `Clear*`) and the apply pass |
| `Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraButton.lua` / `.xml` | The base `AuraButton`: tooltip, click, duration object |
| `Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerShared.lua` | `DefaultAuraDurationFormatter` |
| `Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerFrameProviders.lua` | Button creation, `initializeFrame`, access restrictions |
| `Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraContainerUtil.lua` | Inbound-object validation, the default tooltip |
| `Interface/AddOns/Blizzard_AuraContainer/Mainline/Blizzard_AuraButtonTooltip.xml` | The `AuraButtonTooltip` frame |
| `Interface/AddOns/Blizzard_FrameXMLUtil/AuraUtil.lua`, `.../Mainline/AuraUtil.lua` | `DEBUFF_DISPLAY_INFO`, border atlas and border color helpers |
| `Interface/AddOns/Blizzard_APIDocumentationGenerated/AuraContainerUtilDocumentation.lua` | Option structures (dispel texture, duration bar, duration text) |
| `Interface/AddOns/Blizzard_APIDocumentationGenerated/AuraContainerSharedDocumentation.lua` | `CustomAuraButtonDispelTypeTextureStyle` |
| `Interface/AddOns/Blizzard_APIDocumentationGenerated/SecondsFormatterSharedDocumentation.lua` / `SecondsFormatterAPIDocumentation.lua` | Formatter enums and methods |
| `Interface/AddOns/Blizzard_APIDocumentationGenerated/FrameAPICooldownDocumentation.lua`, `CooldownFrameConstantsDocumentation.lua` | Cooldown countdown API |
| `Interface/AddOns/Blizzard_APIDocumentationGenerated/SimpleStatusBarAPIDocumentation.lua`, `DurationTextBindingObjectAPIDocumentation.lua`, `LuaDurationObjectAPIDocumentation.lua` | Timer bar, text binding and duration object |

---

## A cross-cutting fact: every binding call re-runs the whole apply pass

**Read this first. It is the root of B-4.** Every `Set*` / `Add*` binding ends with
`self:UpdateAuraDisplay()`, and that runs the full `ApplyAuraInstance`, dispel textures included.
**`Clear*` does not.**

`Blizzard_CustomAuraButton.lua`:

```lua
204 function CustomAuraButtonSharedMixin:SetDurationBar(statusBar, options)
...
211 	self.durationBar = PackDisplayElement(statusBar, options);
212 	self:UpdateAuraDisplay();
```

```lua
594 --[[override]] function CustomAuraButtonPrivateMixin:UpdateAuraDisplay()
595 	local unitToken, auraData = self:GetAuraInstance();
596 	self:ApplyAuraInstance(unitToken, auraData, Enum.CustomAuraButtonUpdateMode.Update);
597 end
```

```lua
580 function CustomAuraButtonPrivateMixin:ApplyAuraInstance(unitToken, auraData, updateMode)
581 	self:UpdatePandemicWindow(unitToken, auraData);
583 	self:ApplyApplicationBar(unitToken, auraData, updateMode);
584 	self:ApplyApplicationCount(unitToken, auraData);
585 	self:ApplyDispelTypeTextures(unitToken, auraData);
586 	self:ApplyDispelTypeText(unitToken, auraData);
587 	self:ApplyDuration(unitToken, auraData, updateMode);
...
591 	self:ApplyVisibility(unitToken, auraData);
```

The same `self:UpdateAuraDisplay();` ends `SetApplicationCount` (:68), `AddDispelTypeTexture` (:96),
`SetDurationCooldown` (:147), `SetDurationText` (:192), `SetIcon` (:229), `AddPandemicRegion` (:244)
and `SetSpellName` (:275). The engine also runs it once right after our `initializeFrame`, in
`Blizzard_AuraContainerFrameProviders.lua`:

```lua
78 	if self.initializeFrame ~= nil then
79 		securecallfunction(self.initializeFrame, auraFrame:GetObjectTable());
...
90 	-- Force an immediate display update to apply initial secrets and suitable
91 	-- default values.
92 	auraFrame:UpdateAuraDisplay();
```

---

## Q1 (B-4): what `ClearDispelTypeTextures` and `AddDispelTypeTexture` do to a region

**Answer.**
- `ClearDispelTypeTextures` only empties the list. It touches no region: no vertex color, no
  texture, no `Show`/`Hide`, no display update. **It restores nothing.**
- `AddDispelTypeTexture` marks the texture's Alpha, VertexColor, TexCoords and Shown aspects secret,
  appends it, and runs a full display update.
- On every apply pass (every later binding call and every aura assign, update or clear), each
  registered texture is either styled, tinted and `Show()`n, or `Hide()`n.

`Blizzard_CustomAuraButton.lua`:

```lua
111 function CustomAuraButtonSharedMixin:ClearDispelTypeTextures()
112 	self.dispelTypeTextures = {};
113 end
```

```lua
84  function CustomAuraButtonSharedMixin:AddDispelTypeTexture(texture, options)
...
89  	texture:AddSecretAspect(Enum.SecretAspect.Alpha);
90  	texture:AddSecretAspect(Enum.SecretAspect.VertexColor);
91  	texture:AddSecretAspect(Enum.SecretAspect.TexCoords);
92  	texture:AddSecretAspect(Enum.SecretAspect.Shown);
94  	table.insert(self.dispelTypeTextures, PackDisplayElement(texture, options));
96  	self:UpdateAuraDisplay();
```

```lua
467 local function ApplyDispelTypeTexture(dispelTypeTexture, unitToken, auraData)
468 	local texture, options = UnpackDisplayElement(dispelTypeTexture);
470 	if ShouldShowDispelTypeForAura(options, auraData) then
471 		ApplyDispelTypeTextureStyle(texture, options, auraData);
472 		ApplyCustomDispelTypeTextureColor(texture, options, unitToken, auraData);
473 		texture:Show();
474 	else
475 		texture:Hide();
476 	end
477 end
```

The visibility rule; **with no aura the texture is hidden, even with `showAlways`**:

```lua
372 local function ShouldShowDispelTypeForAura(options, auraData)
373 	if not auraData then
374 		return false;
375 	elseif options.showAlways then
376 		return true;
...
381 	elseif auraData.dispelName == nil and not options.showWithoutDispelType then
382 		return false;
```

`PreserveAsset` keeps the texture's asset and sets only the vertex color. The engine paints
Blizzard's dispel color, then our map overrides it:

```lua
450 	elseif style == Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset then
451 		AuraUtil.SetAuraBorderColor(texture, auraData.dispelName);
```

`Interface/AddOns/Blizzard_FrameXMLUtil/AuraUtil.lua`:

```lua
614 function AuraUtil.SetAuraBorderColor(borderRegion, dispelType)
615 	borderRegion:SetVertexColor(AuraUtil.GetAuraBorderColor(dispelType):GetRGBA());
```

Enum docs (`AuraContainerSharedDocumentation.lua:28`):
`{ Name = "PreserveAsset", ..., EnumValue = 3, Documentation = { "Preserves the texture's existing asset." } }`.

**The mechanism of B-4, from the source.** In static mode, `Bars.Apply` (`modules/Style_Bars.lua`)
paints `barColor` in `applySurfaces`. Then `Bars.Bind` calls `SetDurationBar` **first**. Because
the old `am.fill` entry is still in `dispelTypeTextures` at that point, its `UpdateAuraDisplay`
(:212) runs `ApplyDispelTypeTextures` and repaints the fill with the dispel color. The later
`ClearDispelTypeTextures` (Style_Bars.lua:191) only drops the entry (:112), so the dispel tint
stays until the next restyle, which repeats the same order. The spec's suspicion had the order
right but not the mechanism: it is not the Clear that resets the region. The binding calls
*before* the Clear re-run the tint.

Two related hazards:
- **Hidden fill.** The last apply pass before the Clear can run on a pooled button with no aura
  (`auraData == nil`). That pass hides `am.fill` (:474-475), and nothing in our static path calls
  `am.fill:Show()`. The fill can stay hidden on that button.
- **Alpha.** Our `customDispelColorMap` colors are built with `CreateColor(r, g, b)`
  (`modules/Style.lua` `DispelColorMap`), so `color:GetRGBA()` (:463) sets vertex alpha to 1. The
  fill's opacity survives only because `applySurfaces` uses `SetAlpha`, not vertex alpha.

**Implication for our fix.**
1. In `Bars.Bind` **and** `Icons.Bind`, call `ClearDispelTypeTextures` (and
   `ClearPandemicRegions`) **before any other binding**, so no `Set*` re-runs a stale entry.
2. After binding in static mode, repaint `am.fill`'s vertex color (and alpha) and `Show()` it. The
   Clear restores nothing, and the last pass may have hidden it.
3. The recorder test in the spec (static → dispel → static, asserting `ClearDispelTypeTextures`
   precedes the last `SetVertexColor`) should also assert that the Clear precedes the first
   `SetDurationBar` / `SetIcon`, and that the fill ends shown.
4. The secret-aspect marks from `AddDispelTypeTexture` (:89-92) are never removed. `ChangeParent`
   and `RemoveSecretAspects` become forbidden aspects (`Blizzard_AuraContainerUtil.lua:290-291`).
   The source does not say whether a tainted `SetVertexColor` on a region whose VertexColor aspect
   is secret is honored as a plain value afterwards. **UNSETTLED — in-game check required:** after
   static → dispel → static, the fill shows `barColor`, in and out of combat.

---

## Q2 (G-3): does the `Border` style honor `customDispelColorMap`?

**Answer: yes, for every style.** The custom color is applied after the style step and does not
depend on the style. For `Border`, the style step sets Blizzard's colored atlas and resets the
vertex color to white. Our map then **multiplies** a tint onto that already-colored art: the
result is not a clean recolor.

`Blizzard_CustomAuraButton.lua`:

```lua
439 	if style == Enum.CustomAuraButtonDispelTypeTextureStyle.Border then
440 		local showIcon = false;
441 		AuraUtil.SetAuraBorderAtlas(texture, auraData.dispelName, showIcon);
442 		texture:SetVertexColor(1, 1, 1, 1);
```

```lua
406 local function GetCustomDispelTypeTextureColor(options, unitToken, auraData)
407 	local colorMap = options.customDispelColorMap;
408 	local color = colorMap and colorMap[GetDispelTypeMapKey(auraData)];
...
459 local function ApplyCustomDispelTypeTextureColor(texture, options, unitToken, auraData)
460 	local color = GetCustomDispelTypeTextureColor(options, unitToken, auraData);
462 	if color then
463 		texture:SetVertexColor(color:GetRGBA());
```

```lua
397 local function GetDispelTypeMapKey(auraData)
398 	return auraData.dispelName or "None";
```

Documentation (`AuraContainerUtilDocumentation.lua:275`): `customDispelColorMap` is an
"Optional map of dispel type names to custom vertex colors. The \"None\" key represents auras
without a dispel type." It is not restricted to a style. By contrast, `customDispelAssetMap`
(:274) says "Only applies when using the CustomAsset style."

The atlases (`Blizzard_FrameXMLUtil/AuraUtil.lua:5-10`) are per-type colored art, for example
`basicAtlas = "ui-debuff-border-magic-noicon"`, with a neutral
`["None"] = { ..., basicAtlas = "ui-debuff-border-default-noicon" }`.

**Implication for our fix.**
- G-3 can apply the profile-wide dispel colors to icons. The options:
  - Pass `customDispelColorMap = Style.DispelColorMap(profile.dispelColors)` in `Icons.Bind`. This
    works today, but it tints colored art: a red over the blue Magic border is not red.
  - For a true recolor, use `style = CustomAsset` with a `customDispelAssetMap` that points every
    key (Magic … None) at the neutral `ui-debuff-border-default-noicon` atlas, plus the color map.
    CustomAsset's `SetVertexColor(1, 1, 1, 1)` (:455) runs before the color map (:472), so the map
    wins. That atlas's own tint (gray or white) is not in the source. **UNSETTLED — in-game check
    required:** CustomAsset plus the default-noicon atlas plus our map shows the chosen swatch
    color.
- Either way, the General → Dispel Colors tab need not say "bars only".
- **Decided 2026-09-13 (owner):** neither route. Icons show Blizzard's own dispel border art, with
  no `customDispelColorMap`; the Dispel Colors drive bars only, and the tab and each row say so.

---

## Q3 (I-1): where the `Border` style draws, and whether it shows for a harmful aura with no dispel type

**Answer.** The engine draws on **our** texture (`am.dispel`), at our layer and size. It sets an
atlas with `IgnoreAtlasSize`, so the art stretches to our points.
- `am.dispel` is a texture on the button itself at `OVERLAY`, `SetAllPoints(frame)`
  (`modules/Style_Icons.lua` `build`).
- With our options (`showWhenHarmful = true`, `showWhenHelpful = false`, `showWithoutDispelType`
  left at its default `false`), a **harmful aura with no dispel type is hidden**, and a helpful aura
  is hidden.
- It shows only on a harmful aura that has a dispel type.

`Interface/AddOns/Blizzard_FrameXMLUtil/Mainline/AuraUtil.lua`:

```lua
20 function AuraUtil.SetAuraBorderAtlas(borderRegion, dispelType, showDispelType)
21 	local info = DEBUFF_DISPLAY_INFO[dispelType] or DEBUFF_DISPLAY_INFO["None"];
22 	local atlas = showDispelType and info.dispelAtlas or info.basicAtlas;
23 	borderRegion:SetAtlas(atlas, TextureKitConstants.IgnoreAtlasSize);
```

`Blizzard_CustomAuraButton.lua:377-382` (the visibility rule quoted in Q1): harmful passes
`showWhenHarmful`; then `auraData.dispelName == nil and not options.showWithoutDispelType` →
`return false` → `texture:Hide()` (:475).

Defaults (`AuraContainerUtilDocumentation.lua:269-273`): `showWhenHarmful` Default `true`,
`showWhenHelpful` Default `false`, `showWithoutDispelType` Default `false`, and
`style` Default `"BorderWithIcon"`.

**Implication for our fix.**
- Suspect 1 ("the dispel texture covers our border on every harmful aura") is **wrong as stated**.
  - It shows only on harmful auras **with a dispel type**. The player-debuff starter includes
    typeless debuffs, which show no dispel border at all.
  - `am.dispel` is a region of the button, while `am.border` is a child **frame**
    (`CreateFrame("Frame", nil, frame, "BackdropTemplate")`). A child frame sits at a higher frame
    level than its parent's regions, so our border draws **above** the dispel atlas, not under it.
  - Where both show, a thick Blizzard atlas border fills the frame edge, with our thin line on top.
    A 1 px border in a custom color is easy to lose against it.
- Suspect 2 (frame-level order between `am.border` and `am.cd`): both are child frames of the button
  created in `build` (`am.cd` first). The source gives no frame levels, and `am.cd` is inset to
  `am.icon`, so it covers the border only when the inset is 0.
- Suspect 3 (B-5's error path, C-4's nil `cd`) is not in the engine and is still live.
- **UNSETTLED — in-game check required:** with `/fstack` on an icon showing a buff (no dispel
  border), check whether `am.border`'s color changes on write. If it does not, the cause is ours
  (B-5 / C-4 or the class-color path), not the engine.
- Target behavior (the dispel border replaces ours where a dispel type exists): hide `am.border`
  only when a dispel border shows. That condition is secret, so it cannot be decided in Lua. Instead,
  bind the dispel style over our border and let the dispel art (`OVERLAY`, full frame) draw over
  it. Our border frame's level would then need to sit **below** the dispel texture, which a child
  frame cannot. So move the dispel texture onto a child frame raised above `am.border`, for example
  a texture on a new `am.dispelHost` frame at `border:GetFrameLevel() + 1`.

---

## Q4 (I-2): rounding of the default duration text, of the Cooldown countdown, and `Enum.SecondsFormatterRounding`

**Answer.**
- **Enum members:** `RoundUp = 0` and `Truncate = 1` (only these two).
- **Engine default text (no `textFormatter`):** `SetDurationText` falls back to
  `DefaultAuraDurationFormatter`, which Blizzard configures with **`Truncate`**, plus
  `SetCanRoundUpLastUnit(true)` and a max-interval curve.
- **Cooldown countdown:** its rounding is not in the Lua source. It is C++. The API exposes
  `SetCountdownFormatter(NumericFormatter)`, which matters for the fix below.

`Interface/AddOns/Blizzard_APIDocumentationGenerated/SecondsFormatterSharedDocumentation.lua`:

```lua
53 { Name = "RoundUp", Type = "SecondsFormatterRounding", EnumValue = 0, Documentation = { "Round fractional seconds up to the next whole second when not displaying milliseconds." } },
54 { Name = "Truncate", Type = "SecondsFormatterRounding", EnumValue = 1, Documentation = { "Truncate fractional seconds to the current whole second when not displaying milliseconds." } },
```

`SecondsFormatterAPIDocumentation.lua:451-458`: `SetRounding` "Sets how fractional seconds are
rounded when not displaying milliseconds." `SetCanRoundUpLastUnit` (:341-345) "Configures the
formatter to round the last formatted unit up, rather than down."

`Blizzard_CustomAuraButton.lua`, `SetDurationText`:

```lua
169 	if options.binding then
170 		binding:Assign(options.binding);
171 	else
172 		binding:SetToDefaults();
173 		binding:SetFormatter(addonTable.DefaultAuraDurationFormatter);
174 	end
...
179 	if options.textFormat then
180 		binding:SetTextFormat(options.textFormat.formatString, options.textFormat.components);
181 	elseif options.textFormatter then
182 		binding:SetFormatter(options.textFormatter);
183 	end
```

`Blizzard_AuraContainerShared.lua`:

```lua
75 	local DefaultAuraDurationFormatter = C_StringUtil.CreateSecondsFormatter();
...
85 	local maxIntervalSecondsMultiplier = 1.5;
86 	local maxIntervalCurve = C_CurveUtil.CreateCurve();
87 	maxIntervalCurve:SetType(Enum.LuaCurveType.Step);
88 	maxIntervalCurve:AddPoint(0, Enum.SecondsFormatterInterval.Seconds);
89 	maxIntervalCurve:AddPoint(1 + (maxIntervalSecondsMultiplier * SECONDS_PER_MIN), Enum.SecondsFormatterInterval.Minutes);
90 	maxIntervalCurve:AddPoint(1 + (maxIntervalSecondsMultiplier * SECONDS_PER_HOUR), Enum.SecondsFormatterInterval.Hours);
91 	maxIntervalCurve:AddPoint(1 + (maxIntervalSecondsMultiplier * SECONDS_PER_DAY), Enum.SecondsFormatterInterval.Days);
93 	DefaultAuraDurationFormatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter);
94 	DefaultAuraDurationFormatter:SetRounding(Enum.SecondsFormatterRounding.Truncate);
95 	DefaultAuraDurationFormatter:SetCanRoundUpLastUnit(true);
96 	DefaultAuraDurationFormatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds);
97 	DefaultAuraDurationFormatter:SetMaxIntervalCurve(maxIntervalCurve);
98 	DefaultAuraDurationFormatter:SetDesiredUnitCount(1);
```

The Cooldown side (`FrameAPICooldownDocumentation.lua`):
- `SetCountdownFormatter` (:363-369) takes `{ Name = "formatter", Type = "NumericFormatter", Nilable = true }`.
- `GetCountdownFormatter` (:90-99) returns a `Nilable = true` formatter. When none is set, the
  countdown uses a C++ default whose rounding is not documented.
- `CooldownFrameConstantsDocumentation.lua`: `COOLDOWN_DEFAULT_COUNTDOWN_MILLISECOND_THRESHOLD_MS`
  `Value = 0` (no decimals by default), `COOLDOWN_DEFAULT_COUNTDOWN_ABBREV_THRESHOLD_MS`
  `Value = 120000`, `COOLDOWN_DEFAULT_COUNTDOWN_MINIMUM_DURATION_MS` `Value = 2000`.
- The engine drives our cooldown with
  `cooldown:SetCooldownFromDurationObject(auraDuration, clearIfZero)` where `clearIfZero = false`
  (`Blizzard_CustomAuraButton.lua:519-520`).

For reference only (not the C++ formatter): the older Lua `SecondsFormatterMixin:Format` in
`Interface/AddOns/Blizzard_SharedXML/TimeUtil.lua:217` always ceils: `seconds = math.ceil(seconds);`.

**Implication for our fix.**
- The "one second off" is confirmed on the text side:
  - Our `short` and `long` formatters truncate (`core/Compat.lua`
    `SetRounding(E.SecondsFormatterRounding.Truncate)`).
  - The `blizzard` format (`nil` → `DefaultAuraDurationFormatter`) truncates too (:94).
  - `SetCanRoundUpLastUnit(true)` does not undo it: the truncation applies to fractional seconds
    first, then the last unit is ceiled.
  - So 12.7 s reads "12", and our and Blizzard's texts agree with each other but not with a
    countdown that rounds up.
- Fix, as the spec says:
  - Use `SetRounding(E.SecondsFormatterRounding.RoundUp)` in every format.
  - Back `"blizzard"` with a formatter that copies the default: OneLetter; `RoundUp` instead of
    `Truncate`; `SetCanRoundUpLastUnit(true)`; `SetMinInterval(Seconds)`; the same step curve with
    points 0 / 91 / 5401 / 129601 through `SetMaxIntervalCurve`; `SetDesiredUnitCount(1)`.
  - Guard `SetMaxIntervalCurve` / `C_CurveUtil.CreateCurve` in Compat, with a fallback to
    `SetMaxInterval(Days)`.
- **Stronger option:** the countdown's rounding is C++ and undocumented. So when
  `icons.blizzardNumbers` is on, also call `am.cd:SetCountdownFormatter(sameFormatter)`. The two
  numbers then come from one formatter and cannot disagree. The call is guarded through
  `Style.Bind`-style pcall, and it must be made while auras are readable. It is a cooldown method,
  not an aura binding, and the doc marks it `SecretArguments = "AllowedWhenUntainted"`.
- **UNSETTLED — in-game check required:**
  - With Blizzard countdown numbers on and no countdown formatter set, the countdown shows "13"
    while 12.x s remain (i.e., it rounds up).
  - `SetCountdownFormatter` on `am.cd` is accepted and survives the engine's
    `SetCooldownFromDurationObject`.

---

## Q5 (B-3): a binding that shows or hides a region by whether the aura has a duration; `SetDurationBar` on a permanent aura

**Answer.**
- **No binding shows, hides or alpha-curves an arbitrary region by "has a duration".**
- The only per-region show/hide bindings are:
  - dispel-type textures, keyed on harmful/helpful, dispel type and stealable;
  - pandemic regions, shown only inside a refresh window, and so never on a timeless aura;
  - application count and dispel-type text, on font strings.
- The only curve binding is the duration text's `textColor`: a color curve on the duration font
  string alone.
- A zero duration disables the text binding, not a region.
- `SetDurationBar` neither hides nor resets the StatusBar for a permanent aura. It hands the zero
  duration to the C++ `SetTimerDuration`, and what value the bar then holds is **not in the Lua
  source**.

`Blizzard_CustomAuraButton.lua`:

```lua
532 function CustomAuraButtonPrivateMixin:ApplyDurationBar(_unitToken, _auraData, auraDuration, updateMode)
533 	local statusBar, options = UnpackDisplayElement(self.durationBar);
535 	if statusBar then
536 		local interpolation = GetStatusBarInterpolationForUpdateMode(options.interpolation, updateMode);
538 		statusBar:SetTimerDuration(auraDuration, interpolation, options.direction);
```

```lua
524 function CustomAuraButtonPrivateMixin:ApplyDurationText(_unitToken, _auraData, auraDuration)
525 	if self.durationText then
526 		local binding = self:GetDurationTextBinding();
527 		binding:SetDuration(auraDuration);
528 		binding:SetEnabled(not auraDuration:IsZero());
```

```lua
567 function CustomAuraButtonPrivateMixin:ApplyPandemicRegions()
568 	local isInPandemicTime = self:IsInPandemicWindow();
570 	for _index, pandemicRegion in ipairs(self.pandemicRegions) do
572 		region:SetShown(isInPandemicTime);
```

How a permanent aura's duration is built (`Blizzard_AuraButton.lua`):

```lua
166 	if auraData and auraData.expirationTime and auraData.expirationTime > 0 then
167 		auraDuration:SetTimeFromEnd(secretwrap(auraData.expirationTime, auraData.duration, auraData.timeMod));
168 	else
169 		auraDuration:SetTimeSpan(secretwrap(0, 0));
170 	end
```

Docs:
- `SimpleStatusBarAPIDocumentation.lua:334-342`: `SetTimerDuration(duration, interpolation = "Immediate", direction = "ElapsedTime")`.
- `SimpleStatusBarConstantsDocumentation.lua:51`: `ElapsedTime`, "Calculate status timer bar
  values using the elapsed time of a duration."
- `AuraContainerUtilDocumentation.lua:295-296`: `CustomAuraButtonDurationBarOptions` has only
  `interpolation` and `direction`, with no show/hide or permanent option.
- The one duration-aware filter is a **candidate filter**, not a display binding
  (`Blizzard_AuraContainerUtil.lua:111-113`: "Max duration filters implicitly always filter out
  permanent auras.").

**Implication for our fix.**
- Spec option 1 (an engine binding) is **not available** in this client's source. Go to option 2
  (geometry).
- The one conceivable engine route would be a font-string "spark" driven by the duration text
  binding, which is disabled on a zero duration (:528). It is not usable:
  - the button has exactly one `durationText` slot, and our time text occupies it;
  - what a disabled binding leaves in its font string is not documented.
- What option 2 relies on — that a timeless bar holds **zero elapsed** (a full fill in our inverted
  technique, per the `modules/Style_Bars.lua` header) and that the StatusBar texture's edge then
  sits at the start — lives in C++ `SetTimerDuration`.
- **UNSETTLED — in-game check required:**
  1. On a permanent buff, `am.bar:GetStatusBarTexture()` has zero width (or is hidden) at the start
     edge.
  2. A clip frame (`SetClipsChildren(true)`) anchored to the elapsed region hides a spark placed
     wholly on the elapsed side.
  3. On a timed bar that spark still reads as sitting on the edge. It is offset by half its width
     from today's centered position, which the spec asks to check.
  If (1) or (2) fails, stop and report (spec option 3).
- The preview side needs no engine: `aura.duration == 0` is readable there, so hide the spark
  directly when `bars.sparkTimeless` is off.

---

## Q6 (L-3): how a `CustomAuraButton` takes the mouse, and whether its tooltip could be the world's

**Answer.**
- **Mouse.**
  - `CustomAuraButtonTemplate` is an `AuraButton`, an intrinsic `Button` with `OnEnter`, `OnLeave`
    and `OnClick` scripts.
  - Neither template sets `enableMouse`, mouse motion, mouse click or a hit rect. No file in
    `Blizzard_AuraContainer/` calls `EnableMouse`, `SetMouseMotionEnabled`, `SetMouseClickEnabled`,
    `SetHitRectInsets` or `SetPropagate*` (grep: no matches).
  - The hit area is therefore the button's own rect, which is the size **we** set. The flow layout
    reads it back: `local width, height = element:GetSize()`
    (`Blizzard_CustomAuraContainer.lua`, `CustomAuraContainerFlowLayoutMixin:GetElementSize`).
  - Mouse state is whatever our `initializeFrame` / `Style.ApplyBehavior` sets.
- **Tooltip.**
  - The engine shows the aura tooltip on its **own** forbidden tooltip frame, `AuraButtonTooltip`,
    **not `GameTooltip`**, with `tooltip:SetOwner(self, self:GetTooltipAnchorPoint())`.
  - A world mouseover therefore cannot populate the aura tooltip, and the aura code never touches
    `GameTooltip`.
  - The two are independent frames, so both can be visible at once. The "bleed" is the world's
    `GameTooltip` appearing because **no mouse-enabled frame of ours is under the cursor**.

`Interface/AddOns/Blizzard_AuraContainer/Blizzard_CustomAuraButton.xml:5`:
`<AuraButton name="CustomAuraButtonTemplate" virtual="true" onUpdateMode="disabled">`, with only
mixins and an `OnUpdate` script.

`Interface/AddOns/Blizzard_AuraContainer/Blizzard_AuraButton.xml`:

```xml
5  		<Button name="AuraButton" intrinsic="true">
...
16 			<ForbiddenAspects>
17 				<ForbiddenAspect aspect="UntrustedScriptExecution"/>
...
19 				<ForbiddenAspect aspect="ScriptedInput"/>
20 				<ForbiddenAspect aspect="AlwaysPropagateInput"/>
21 				<ForbiddenAspect aspect="QueryFocus"/>
...
25 			<Scripts>
26 				<OnLoad method="OnLoad_Intrinsic"/>
27 				<OnEnter method="OnEnter_Intrinsic"/>
28 				<OnLeave method="OnLeave_Intrinsic"/>
29 				<OnClick method="OnClick_Intrinsic"/>
```

`Blizzard_AuraButton.lua`:

```lua
80  function AuraButtonPrivateMixin:OnEnter_Intrinsic(_isFromMouseMotion)
81  	if self:ShouldShowTooltip() then
82  		self:ShowTooltip();
...
185 function AuraButtonPrivateMixin:ShowTooltip()
186 	local tooltip = AuraContainerUtil.GetDefaultTooltip();
...
191 		tooltip:SetOwner(self, self:GetTooltipAnchorPoint());
...
196 		RaiseFrameLevelByTwo(tooltip);
```

`Blizzard_AuraContainerUtil.lua:313-315`: `function AuraContainerUtil.GetDefaultTooltip() return AuraButtonTooltip; end`.

`Interface/AddOns/Blizzard_AuraContainer/Mainline/Blizzard_AuraButtonTooltip.xml:3-4`:
`<ScopedModifier forbidden="true" hideFromGlobalEnv="true">`
`<GameTooltip name="AuraButtonTooltip" mixin="GameTooltipDataMixin,  AuraButtonTooltipMixin" inherits="SharedTooltipArtTemplate" parent="UIParent">`.

**Implication for our fix.**
- Strata cannot stop the bleed (confirmed: a separate tooltip frame, and the world is not a frame).
- The fix is to make sure a mouse-enabled frame of ours is under the cursor wherever an element is
  drawn:
  - **Preview frames:** `modules/Preview.lua` `factory` does `f:EnableMouse(false)`, so every
    placeholder is transparent to the mouse. The world under it is moused over and `GameTooltip`
    shows, and the placeholder has no tooltip at all.
    - Enable motion (not clicks) on preview frames while tooltips are on: `EnableMouseMotion(true)`
      or `SetMouseMotionEnabled(true)`, `SetMouseClickEnabled(false)`.
    - Give them an `OnEnter` / `OnLeave` that shows the placeholder's name on `GameTooltip`.
      Previews are our own frames, not engine frames, so this is plain Lua.
    - Keep the drag handle's own mouse handling on top.
  - **Live buttons:** `Style.ApplyBehavior` sets
    `SetMouseMotionEnabled(not through and b.tooltips ~= false)` and `SetMouseClickEnabled(cancel)`.
    With tooltips off or click-through on, motion is off and the world under the button is moused
    over by design. The row tooltips should say so. With tooltips on, the button should capture
    the cursor.
- `QueryFocus` is a forbidden aspect of `AuraButton` (xml :21). So `GetMouseFoci()`
  (`core/Compat.lua` `GetMouseFocus`) may not report an engine button, which matters to any
  frame-picker or diagnostics that expect to see it.
- **UNSETTLED — in-game check required:**
  1. A live button with motion on and clicks off is the mouse focus, so no world `GameTooltip`
     appears while hovering it (the engine's Button default for mouse enable, before
     `ApplyBehavior` runs, is not in the source).
  2. After the preview change, hovering a placeholder over a world unit shows only the placeholder
     tooltip.
  3. The world tooltip that was already up when the cursor enters a button fades instead of
     lingering beside `AuraButtonTooltip`.
  These three belong in `docs/smoke-tests.md` (task B7).

---

## Q7 (B-5, added in task F1): can a placeholder's time text use the formatter the engine is handed?

**Answer: yes.** A `SecondsFormatter` (what `C_StringUtil.CreateSecondsFormatter` returns, and what
we hand `SetDurationText` as `textFormatter`) has a `Format` method that turns a number of seconds
into the string the engine's text binding would write. A placeholder's remaining time is a plain
number of ours, so the call is untainted and legal.

`Interface/AddOns/Blizzard_APIDocumentationGenerated/SecondsFormatterAPIDocumentation.lua`
(fetched 2026-09-13):

```lua
{
	Name = "Format",
	Type = "Function",
	ConstSecretAccessor = true,
	SecretArguments = "AllowedWhenUntainted",
	Documentation = { "Formats a number of seconds and returns the resulting string." },
	Arguments = {
		{ Name = "seconds", Type = "DurationSecondsDouble", Nilable = false },
		{ Name = "abbreviation", Type = "SecondsFormatterAbbreviation", Nilable = true },
	},
	Returns = {
		{ Name = "formattedSeconds", Type = "string", Nilable = false },
	},
},
```

**Implication.** `Style.PreviewTime` writes a placeholder's time through `formatterFor(format)`, so
the preview reads in the chosen time format. With no `abbreviation`, the formatter's default
(`SetDefaultAbbreviation(OneLetter)`, `core/Compat.lua`) applies. It is guarded: a client without
the formatter, or one that refuses, writes whole seconds as before.

---

## Summary: what is settled, and what needs the client

| Q | Settled by source | UNSETTLED — in-game check required |
|---|---|---|
| 1 B-4 | Clear restores nothing, no update; every `Set*`/`Add*` re-runs the dispel tint; no-aura pass hides the texture | Tainted `SetVertexColor` on a secret-aspect fill is honored (static color shows after dispel) |
| 2 G-3 | `customDispelColorMap` applies to every style (tint over colored atlas for `Border`) | `CustomAsset` + `ui-debuff-border-default-noicon` + map gives a clean swatch color |
| 3 I-1 | `am.dispel` (OVERLAY, full frame, atlas stretched); hidden on typeless harmful and on helpful auras; our border frame draws above it | Why our border color does not change (`/fstack`); likely B-5/C-4, not the engine |
| 4 I-2 | Enum `RoundUp=0`, `Truncate=1`; the engine default text truncates; `SetCountdownFormatter` exists | Cooldown countdown's default rounding; `SetCountdownFormatter` accepted on `am.cd` |
| 5 B-3 | No duration-presence binding; `SetDurationBar` does not hide or reset; permanent = `SetTimeSpan(0, 0)` | Zero-duration `SetTimerDuration` value and texture edge; clip-frame spark hides on timeless bars |
| 6 L-3 | No mouse or hit-rect setup in the engine; tooltip is the separate `AuraButtonTooltip`; previews are `EnableMouse(false)` | Motion-only button blocks world mouseover; preview fix removes the bleed |
| 7 B-5 | `SecondsFormatter:Format(seconds, abbreviation?)` returns the formatted string, `AllowedWhenUntainted` | A placeholder's time text reads as the live text does in each format |
