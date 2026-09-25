# Feedback batch 8: investigation findings

Read-only investigation, 2026-09-25. One investigator per item, then an adversarial critic. This file keeps the critics' corrected records verbatim.
The spec (`../specs/2026-09-25-feedback-batch8-design.md`) records the owner's rulings. Where it differs from these findings, the spec wins.

## Item 1: ITEM 1 (bug): with "Show the spark on auras without a duration" unticked, bars for auras that have a duration show a large black-and-gold fake spark

### Root cause / design

The prior diagnosis is confirmed, and so is the batch-7 SP-1 fix (commit 0b4b0c9) as the cause.

The spark texture is Blizzard's "Interface\\CastingBar\\UI-CastingBar-Spark" (modules/Style_Bars.lua:56). That art is made to be drawn additively. It is a gold glow on a black field, and the black field has non-zero alpha. Blizzard's own casting bar draws it with alphaMode ADD.

With sparkTimeless false on a live bar (engine=true), wireSpark takes its clip branch (modules/Style_Bars.lua:144-150), which calls am.spark:SetBlendMode("BLEND") (line 150). With normal alpha blending, the black matte is painted as opaque-ish black around the gold core. The quad is sparkWidth (default 8, defaults/Profile.lua:198) by 2h (Style_Bars.lua:286), and the clip frame is padded h/2 above and below (lines 145-146). So the whole double-height quad shows as a black box with a gold streak sticking out above and below the bar. That is exactly what 17.png shows on Shining Light and Consecration.

With the option ticked, the else branch (lines 151-155) sets ADD. The black adds nothing, and the gold over the blue fill washes to near white, which matches 19.png.

The preview is unaffected: FillPreview (lines 360-369) never touches the blend mode, and a non-engine dress takes the ADD branch.

SP-1's original complaint (docs/superpowers/specs/2026-09-15-feedback-batch7-design.md:79-88) still has to be solved. That complaint was raw gold showing when an ADD spark sits over the dark, half-transparent elapsed side. The comment at lines 127-138 rests on a false premise: that under BLEND the art renders as "its own authored translucent texture". The art is glow-on-black, not translucent.

Fix design: keep the spark additive in every mode, and take the gold out of the art with SetDesaturated(true). The glow then becomes neutral, and its hue comes only from the player's sparkColor through SetVertexColor (default white at a=0.9). Blend mode no longer depends on sparkTimeless. The two modes differ only in geometry: B-3's clip frame puts the spark just inside the edge instead of centered on it. That geometry is load-bearing and stays as it is.

Correction to the prior sketch: do not move the blend and desaturate calls to build()-time only. The test helper dressed() (tests/test_style_bars.lua:20-28) swaps every region for a fresh recorder AFTER the first dress, so calls made in build() are never recorded. Also, a pinned ADD per dress is cheap and self-heals if anything else changes it. Put both calls in the per-dress path instead, in applySurfaces next to SetVertexColor. No schema change, no NS.L keys, no DB migration.

### Evidence

- modules/Style_Bars.lua:56-57: build() calls SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark") and then SetBlendMode("ADD")
- modules/Style_Bars.lua:144-150: the clip branch (engine and not sparkTimeless) pads the clip frame h/2 up and down, anchors the spark on the elapsed side and calls am.spark:SetBlendMode("BLEND"). This is the bug.
- modules/Style_Bars.lua:151-155: the centered branch uses SetBlendMode("ADD"), which is why the ticked case looks right (19.png)
- modules/Style_Bars.lua:286: am.spark:SetSize(sparkWidth, h * 2). The quad is double height, so under BLEND the black matte box sticks out above and below the bar (17.png).
- modules/Style_Bars.lua:224-225: applySurfaces runs SetShown and SetVertexColor(sparkColor) every dress. This is the right place for per-dress SetDesaturated and SetBlendMode.
- modules/Style_Bars.lua:127-138: the SP-1 comment claims BLEND gives an 'authored translucent texture' and says 'Do not simplify this back to one blend mode'. The premise is false for glow-on-black art.
- modules/Style_Bars.lua:360-369: FillPreview never sets the blend mode, and a preview dress goes through the ADD else-branch, so the preview is unaffected by the bug
- tests/test_style_bars.lua:20-28: dressed() dresses once, swaps frame.__am regions for fresh recorders, then dresses again, so calls made in build() are invisible to assertions
- tests/test_style_bars.lua:180-206: four SP-1 tests pin BLEND in clip mode and ADD elsewhere
- tests/region_recorder.lua: every PascalCase method is logged, so SetDesaturated needs no whitelist; __joined returns nil when the method was never called
- defaults/Profile.lua:198-199: sparkWidth 8, sparkColor white a=0.9, sparkTimeless true
- docs/known-limitations.md:186-191 and docs/smoke-tests.md:537-556 (check 85) describe the BLEND-in-clip-mode design. docs/ARCHITECTURE.md no longer mentions the spark blend (grep for spark/blend finds nothing), which contradicts the prior finding's '~line 438' citation. docs/midnight-quirks.md:147-153 covers only geometry and needs no change.
- 17.png: black rectangles with a gold core at the moving edge, taller than the bar. 19.png: whitish sparks, no box.

### Files

- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Style_Bars.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_style_bars.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/known-limitations.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/smoke-tests.md

### Implementation sketch

modules/Style_Bars.lua:
1. build() (lines 56-57): keep SetTexture. Add a comment: this art is a glow on a black field and must be drawn additively; BLEND paints its black matte (feedback batch 8, a regression from SP-1). The build-time SetBlendMode("ADD") can stay or go, since the per-dress call below is authoritative.
2. wireSpark(): delete am.spark:SetBlendMode("BLEND") (line 150) and am.spark:SetBlendMode("ADD") (line 155). wireSpark then only does geometry and clipping.
3. applySurfaces() (lines 224-225): next to SetVertexColor, add
     am.spark:SetDesaturated(true)   -- neutral glow; hue comes only from sparkColor
     am.spark:SetBlendMode("ADD")    -- the one blend for every mode; never BLEND
   These run every dress (live and preview), so the recorder-based tests can see them and the state self-heals.
4. Rewrite the comment at lines 127-138. The modes differ only in position and clip. The blend is ADD in both, because UI-CastingBar-Spark is additive art whose black field has alpha, and BLEND shows that field as a black box taller than the bar (batch 8). SP-1's raw gold over the dark elapsed side is fixed by desaturating the art, not by changing the blend. Remove the 'Do not simplify back to one blend mode' warning and replace it with 'Do not reintroduce BLEND'.
5. FillPreview needs no change, since it gets the same applySurfaces paint.
Optional: hoist the texture path to a named constant (C.SPARK_TEXTURE). Not required.
No new settings, schema keys, NS.L strings or migration.

Docs:
- known-limitations.md:186-191: replace 'blends the spark normally there instead of additively' with 'keeps the spark additive and desaturates its art, so over the elapsed side it reads as the player's spark color, not the art's native gold. Normal blending was tried (SP-1) and painted the art's black matte as a box (batch 8).'
- smoke-tests.md check 85: update the rationale lines 548-552, which talk about ADD vs normal blending, and add an explicit failure condition: 'no dark or black rectangle around the spark, and nothing sticking out above or below the bar with the option off'. Note the batch-8 regression.

### Tests

- tests/test_style_bars.lua: replace 'with the timeless spark off, the live clipped spark blends normally' with 'the live clipped spark stays additive': dressed(cfg({bars={sparkTimeless=false}}), true) gives am.spark:__joined("SetBlendMode") == "ADD". Red under the SP-1 BLEND line, which paints the art's black matte (batch 8).
- Add 'the spark's blend never depends on sparkTimeless or engine': for each (sparkTimeless true/false) x (engine true/false), every entry of am.spark:__calls("SetBlendMode") is "ADD" and there is at least one. The 'at least one' guard catches a move of the call into build(), which the recorder cannot see.
- Add 'the spark art is desaturated so its hue is the player's sparkColor': am.spark:__joined("SetDesaturated") == "true" for both a live dress and a preview dress. Red under raw gold casting-bar art over the dark elapsed side (the original SP-1 report). The call must be per-dress: dressed() swaps regions after the first build.
- Adjust 'the clip-mode blend switch leaves the player's own spark color alone': keep SetVertexColor == "0.1,0.2,0.9,0.4" and change the blend assertion to ADD. Rename it to reflect that there is no longer a switch.
- Keep the existing preview test (dress with engine=false gives ADD) and the geometry tests (clip padding h/2, LEFT/RIGHT anchors, clip off in preview) unchanged. The fix must not touch B-3 geometry.
- Run: lua tests/run.lua, and luacheck .

### Smoke

- Show spark on, 'Show the spark on auras without a duration' UNticked: timed bars (Consecration, Shining Light) show a thin whitish glow just inside their moving edge. No black or dark rectangle, no gold, nothing sticking out above or below the bar as a box.
- Same setting: permanent auras (Devotion Aura, Sign of the Skirmisher) still show no spark (checks 26/63). If they get one back, that is a B-3 regression.
- Tick the option: timed sparks sit centered on the edge and have the same color and brightness as when unticked (check 85). Compare with 19.png. They may read slightly more neutral white now that the gold is gone.
- Set Spark color to pure red, then enable class color: the spark takes that hue in both modes. Drop the spark color's alpha to about 25%: the spark is dimmer but still has no black box.
- Set Spark width to 32 with the option unticked: the glow is wider and there is still no black box.
- Open the preview: placeholder sparks are neutral, and with the option off the timeless placeholder has no spark.

Needs migration: False

### Risks

- Changes from the prior finding: (a) SetDesaturated and SetBlendMode("ADD") go in applySurfaces, run every dress, and not only in build(). tests/test_style_bars.lua dressed() swaps regions for fresh recorders after the first dress, so build-time calls are unrecordable, and the prior sketch's tests ('__joined("SetBlendMode") == "ADD"' and 'SetDesaturated == "true"') would have read nil and failed. (b) Dropped docs/ARCHITECTURE.md and docs/midnight-quirks.md from the file list: ARCHITECTURE.md no longer mentions the spark blend (grep finds nothing), and midnight-quirks covers only geometry. (c) Added an 'at least one call' guard to the blend-mode test.
- Desaturation also changes the centered (default) mode slightly: warm gold-over-blue becomes neutral white. The owner signed off on the old look. If that is unwanted, desaturate only in clip mode (SetDesaturated(clipMode) inside wireSpark), at the cost of the two modes not matching exactly.
- ADD with a dark sparkColor (e.g. navy) over the dark elapsed side is faint. That is inherent to additive glows.
- The SP-1 tests and smoke check 85 pin BLEND and warn against 'simplifying back'. The tests, the code comment and the docs must all be rewritten in the same change, or a later reader will reintroduce BLEND.
- SetDesaturated and SetBlendMode are stable Texture APIs on our own texture, not engine-bound, so no Compat shim and no secret-value concern. The per-dress cost is two C calls, which is negligible.

### Open questions (as raised)

- Should the spark be neutral white, tinted only by 'Spark color', in both modes? This is recommended, and it makes the ticked and unticked sparks match. Or should the ticked (centered) mode keep its current warm casting-bar look, with only the unticked mode desaturated?

## Item 3: ITEM 3 (feature): a close (X) button on each container's unlock-mode drag handle, to the left of the "?", that disables the container

### Root cause / design

VERIFIED: the prior finding's core analysis holds. I re-read every cited line on feat/2026-09-25-feedback-batch8. A few details are corrected below; see risks, item 1.

WHAT EXISTS TODAY. AuraMaster does not draw the strip or its "?".
- Anchors.BuildHandle (modules/Anchors.lua:413-429) calls LibKa0s-Widgets-1.0's KW.DragHandle(anchor, spec) and passes helpIcon = NS.Icon("help").
- The vendored libs/LibKa0s/WidgetsDragHandle.lua is identical to ../LibKa0s/LibKa0s/WidgetsDragHandle.lua (v1.58.0, DRAG_MINOR = 2, line 48). I confirmed this with diff.
- The widget owns these pieces:
  - The "?": dhBuildHelp, lines 330-366. It is an 18px HELP_HIT Button at RIGHT,-HELP_INSET(4), holding an 8px HELP OVERLAY texture at CENTER. The texture is tinted HELP_TINT {0.7,0.7,0.72} and turns HELP_TINT_OVER white on hover. The strip's drag scripts are copied onto it.
  - The label's bounds: dhBuildLabel, lines 396-409, LEFT +RESERVE / RIGHT -RESERVE.
  - The width: Measure(), lines 444-446, label + RESERVE*2.
  - RESERVE = HELP_INSET + HELP_HIT - HELP_GUTTER + HELP_CLEAR = 4+18-5+12 = 29.

THE STANDARD GLYPH. It comes from LibKa0s-Media-1.0's lib.ICONS catalog (libs/LibKa0s/Media.lua:92-). Its first entry is "close", and media/icons/close.tga ships. It is white-in-alpha by the file's contract (Media.lua:85-87), like "help", so the widget's vertex tint works on it unchanged. The addon reaches it with NS.Icon("close") (core/MediaSetup.lua:24-27).

DESIGN: an opt-in library extension, not a frame added by the host. A host-parented X can't work cleanly:
- The widget bounds the label at RESERVE on both sides and measures label + 2*RESERVE.
- A long name such as "Target Debuffs (All) TEST" would therefore run under an X the widget doesn't know about.
- Fixing that from the host means re-pointing handle.label, which is widget internals.

Five other strips use this widget: ConsumableMaster MacroBar, KickCD Castbar_Handle/IconGrid/Castbar, and AbsorbTracker Bar. A spec with no onClose must leave their geometry byte-for-byte unchanged.

LibKa0s WidgetsDragHandle, DRAG_MINOR 2 -> 3 (Widgets shell stays minor 10, so the API version is 10.3):
- New spec fields:
  - onClose (function|nil). Without it, no X is built.
  - closeIcon (resolved path|nil).
  - closeTooltip (descriptor|nil, the same shape as helpTooltip).
- lib.DRAG_HANDLE.CLOSE_GAP = 0. With a zero gap, the art-to-art spacing is 2*HELP_GUTTER = 10px.
- dhBuildClose builds a HELP_HIT Button holding a HELP texture, so it is the same size as the "?" as the owner asked. It anchors RIGHT to help's LEFT.
- Per-instance reserve: dhReserve(spec) = RESERVE + (onClose and HELP_HIT + CLOSE_GAP or 0). It is used by dhBuildLabel and Measure, and published as handle:Reserve().

AuraMaster side:
- BuildHandle passes closeIcon = NS.Icon("close"), onClose and closeTooltip.
- onClose goes through THE single write seam: NS.SetByPath("container.enabled", false, container.id) (settings/Schema.lua:821-838).
- The row at settings/Containers.lua:69-72 has effect = "visibility". So announceWrite (Schema.lua:548-562) sends CONFIG_CHANGED and runs H.RefreshScalars(), which updates an open Enabled checkbox live.
- ContainerManager.lua:579-580 then runs CM.ApplyVisibility().
- ContainerClass:ShouldShow (Container.lua:425-432) returns false because cfg.enabled is off.
- ApplyVisibility (Container.lua:493-515) then hides the preview and outline, calls ApplyLive(false) (engine SetEnabled plus our own blocker), calls UpdateHandle(self, false) and re-places attached followers. Nothing in that path touches the protected anchor, so it is combat-legal, the same as the Enabled checkbox, which the write seam does not gate on combat either.

NO SCHEMA CHANGE: container.enabled and its default already exist. No DB migration.

### Evidence

- modules/Anchors.lua:413-429 BuildHandle: KW.DragHandle(anchor, { label, moveFrame, helpIcon = NS.Icon and NS.Icon("help") or nil, canDrag, onDragStop, onRightClick, tooltip = tooltipSpec(container), tooltipOwner = "cursor", edge, number })
- modules/Anchors.lua:312-323 header comment names the widget 'minor 2' (must be updated to 3); KW/DRAG resolved at file load
- modules/Anchors.lua:348-368 tooltipSpec: function-valued title/body lines; cursor-owned because the anchor inherits DisableUntrustedLayoutScriptsTemplate (SetOwner on a frame under it errors)
- modules/Anchors.lua:475 placeHandle overhang = handle:ApplyWidth(w) - w; 493 clampToHandle uses it, so a wider strip widens the clamp reach automatically
- libs/LibKa0s/WidgetsDragHandle.lua:48 DRAG_MINOR = 2; 108-126 DRAG_HANDLE numbers, RESERVE = 4+18-5+12 = 29
- libs/LibKa0s/WidgetsDragHandle.lua:330-366 dhBuildHelp (HELP_HIT frame, HELP art CENTER, HELP_FALLBACK, dhTint, drag scripts copied, overTint only when onRightClick)
- libs/LibKa0s/WidgetsDragHandle.lua:302-311 dhSetClick registers only RightButtonUp; 396-409 dhBuildLabel bounds at +/-RESERVE; 444-446 Measure = label + RESERVE*2; 505-528 lib.DragHandle assembles, handle.help = dhBuildHelp
- diff of vendored vs ../LibKa0s/LibKa0s/WidgetsDragHandle.lua: identical; AuraMaster CLAUDE.md:36 says v1.58.0; LibKa0s newest tag v1.58.0
- ../LibKa0s/docs/api/Widgets/version-10.2-docs.md: 'Widgets.lua minor 10 · WidgetsDragHandle.lua minor 2', so the next doc is version-10.3-docs.md + members-10.3.json
- libs/LibKa0s/Media.lua:92-94 lib.ICONS starts with "close"; media/icons/close.tga ships; 85-87 every mark is white-in-alpha
- core/MediaSetup.lua:20-27 NS.Icon; the comment says the addon draws one mark, 'help'
- settings/Containers.lua:69-72 container.enabled bool, effect = "visibility"
- settings/Schema.lua:548-562 announceWrite (CONFIG_CHANGED + H.RefreshScalars); 821-838 NS.SetByPath; no InCombatLockdown gate in Schema.lua
- modules/ContainerManager.lua:577-580 visibility effect -> CM.ApplyVisibility()
- modules/Container.lua:425-432 ShouldShow gates on cfg.enabled; 446-449 ApplyLive = engine SetEnabled + own blocker; 493-515 ApplyVisibility -> UpdateHandle(self, false), PlaceAttached
- core/CoreSetup.lua:77,93 NS.Print / NS.Printf exist (use these, not bare print)
- locales/enUS.lua:28 L["Container"] exists; :30 the existing 'Attached -' key contains a non-ASCII em dash (a pre-existing locale ASCII deviation)
- tests/test_anchors.lua:225 RESERVE2 = 58 hard-coded; used at 337, 340, 352, 1256, 1270
- tests/test_anchors.lua:440-515 existing help-mark tests (tooltip, right-click, drag, fallback art) are the pattern for the X tests; ../LibKa0s/tests/test_widgets_draghandle.lua has 35 tests to extend

### Files

- /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s/LibKa0s/WidgetsDragHandle.lua (DRAG_MINOR 3: onClose/closeIcon/closeTooltip, CLOSE_GAP, CLOSE_FALLBACK, dhReserve, dhBuildClose, handle:Reserve(), spec doc block)
- /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s/tests/test_widgets_draghandle.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s/docs/api/Widgets/version-10.3-docs.md (new) + members-10.3.json (new); mark version-10.2-docs.md superseded
- /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s/CHANGELOG.md, README.md (release v1.59.0)
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/libs/LibKa0s/** and tests/_kit/** (re-vendor v1.59.0 via /wow-addon:revendor-libka0s) + CLAUDE.md:36 provenance line
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Anchors.lua (BuildHandle spec, disableContainer, closeTooltipSpec, header comment 'minor 2' -> 3)
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/core/MediaSetup.lua (comment :20-22 lists one mark; now two)
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/locales/enUS.lua (new keys)
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_anchors.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/smoke-tests.md, docs/ARCHITECTURE.md, docs/module-map.md (handle description), README.md (unlock-mode usage if it describes the strip)

### Implementation sketch

LIBRARY: LibKa0s/LibKa0s/WidgetsDragHandle.lua, DRAG_MINOR 2 -> 3.

1. Constants:
- lib.DRAG_HANDLE.CLOSE_GAP = 0. This is the px between the X frame and the "?" frame. Add a comment explaining it next to the other DRAG_HANDLE comments.
- local CLOSE_FALLBACK = "Interface\\Buttons\\UI-StopButton". It is the last rung, like HELP_FALLBACK. Confirm in-game that it reads as an X at 8px.

2. local function dhReserve(spec)
     local D = lib.DRAG_HANDLE
     return D.RESERVE + (spec.onClose and (D.HELP_HIT + D.CLOSE_GAP) or 0)
   end
- dhBuildLabel uses dhReserve(spec) in place of lib.DRAG_HANDLE.RESERVE.
- dhAttachMethods: Measure returns dhLabelWidth(spec, self.__label) + dhReserve(spec) * 2. Add function handle:Reserve() return dhReserve(spec) end.

3. local function dhBuildClose(handle, spec)
- Return nil if spec.onClose is not set.
- Build the button:
  - local D = lib.DRAG_HANDLE; local btn = CreateFrame("Button", nil, handle).
  - If not (btn and btn.SetSize), return nil.
  - btn:SetSize(D.HELP_HIT, D.HELP_HIT).
- Anchor it:
  - With handle.help: btn:SetPoint("RIGHT", handle.help, "LEFT", -D.CLOSE_GAP, 0).
  - Without it: btn:SetPoint("RIGHT", handle, "RIGHT", -D.HELP_INSET, 0).
- The art: an OVERLAY texture, HELP x HELP, at CENTER. SetTexture(spec.closeIcon or CLOSE_FALLBACK), then dhTint(HELP_TINT). Store it as btn.icon.
- Hover:
  - OnEnter: dhTint(btn.icon, HELP_TINT_OVER), then dhShowTooltip(btn, spec, spec.closeTooltip or spec.tooltip).
  - OnLeave: dhTint(btn.icon, HELP_TINT), then dhHideTooltip().
- Click:
  - btn:RegisterForClicks("LeftButtonUp").
  - btn:SetScript("OnClick", function(_, b) if b == "LeftButton" then spec.onClose() end end).
  - Optional, for consistency with the "?": if spec.onRightClick exists, also register RightButtonUp and route it to onRightClick.
- No RegisterForDrag.
- return btn.

4. lib.DragHandle: after handle.help = dhBuildHelp(handle, spec), add handle.close = dhBuildClose(handle, spec).
- dhBuildLabel runs before this, but it only needs spec, so the order is fine.

5. Docs and release:
- Update the spec doc block and the DRAG_HANDLE comment.
- Write docs/api/Widgets/version-10.3-docs.md and members-10.3.json.
- Add a CHANGELOG entry and tag v1.59.0.

ADDON: re-vendor via /wow-addon:revendor-libka0s. That copies libs/LibKa0s and tests/_kit together and rolls the CLAUDE.md:36 line. Then edit modules/Anchors.lua:

    local function disableContainer(container)
        local ok, err = NS.SetByPath("container.enabled", false, container.id)
        if not ok then
            if err then NS.Print(err) end
            return
        end
        -- optional (open question 1):
        -- NS.Printf(NS.L["%s disabled. Turn Enabled back on for it on the Containers page to bring it back."], name)
    end

    local function closeTooltipSpec(container)
        return {
            title = function()
                local cfg = container:Cfg()
                return cfg and cfg.name or NS.L["Container"]
            end,
            body = { NS.L["Click to disable this container. Its settings are kept; turn it back on with Enabled on the Containers page."] },
        }
    end

In the BuildHandle spec, add:
- closeIcon = NS.Icon and NS.Icon("close") or nil
- onClose = function() disableContainer(container) end
- closeTooltip = closeTooltipSpec(container)

tooltipOwner = "cursor" already covers the new descriptor, which matters under the untrusted-layout anchor.

Also update the header comment (minor 3, strip + X + "?") and the MediaSetup comment. placeHandle and clampToHandle need no change, because both go through ApplyWidth -> Measure.

Locale keys: add to locales/enUS.lua, ASCII only. Reuse L["Container"].
- "Click to disable this container. Its settings are kept; turn it back on with Enabled on the Containers page."
- The optional chat line above.

No schema key, no default change, no migration.

### Tests

- LibKa0s test_widgets_draghandle: a spec without onClose builds no handle.close. Measure(), handle:Reserve() and the label's LEFT/RIGHT offsets equal RESERVE (29), so existing consumers are unchanged.
- LibKa0s: with onClose, handle.close is HELP_HIT square and anchored RIGHT to handle.help's LEFT at -CLOSE_GAP. Its icon is HELP square at CENTER with texture spec.closeIcon (CLOSE_FALLBACK when nil) and tint HELP_TINT.
- LibKa0s: with onClose, Measure() = label + (RESERVE + HELP_HIT + CLOSE_GAP)*2, the label bounds are +/- that value, and handle:Reserve() returns it.
- LibKa0s: close OnClick('LeftButton') calls onClose exactly once; OnClick('RightButton') does not call onClose. Close has no OnDragStart script and no RegisterForDrag.
- LibKa0s: close OnEnter shows closeTooltip (falling back to tooltip) with HELP_TINT_OVER; OnLeave restores HELP_TINT and hides GameTooltip; tooltipOwner='cursor' owns by UIParent.
- LibKa0s: MODULES.WidgetsDragHandle == 3, and a second load of an older minor does not overwrite it (existing guard pattern).
- AuraMaster test_anchors: the X sits left of the help mark with the catalog close glyph at the help mark's size. h.close exists; its SetTexture is NS.Icon('close') (and non-nil); its SetSize matches h.help's; its RIGHT point is relative to h.help.
- AuraMaster: clicking the X disables THIS container through the write seam. Fire inst2.handle.close OnClick LeftButton. Then FindContainer(2).enabled == false, container 1 is untouched, CONFIG_CHANGED was sent with path 'container.enabled' and containerId 2, and after the visibility pass the handle, preview and outline are hidden.
- AuraMaster: with InCombatLockdown mocked true, clicking the X still stores enabled=false, hides the handle and raises nothing; no anchor Show/Hide/SetPoint is recorded.
- AuraMaster: replace RESERVE2 = 58 (test_anchors.lua:225, used at 337/340/352/1256/1270) with h:Reserve()*2, or assert the new 94 = 2*(29+18) explicitly with a comment.
- AuraMaster: with no media catalog, h.close's texture falls back to the library's Blizzard X (mirrors :507-515).
- AuraMaster: the close tooltip title follows a rename (the function-valued title), and it is cursor-owned (mirrors :466-480).

### Smoke

- /am unlock: every container's strip shows a gray X immediately left of the ?, the same 8px size, turning white on hover. The label stays centered and doesn't run under the X for a long name like 'Target Debuffs (All) TEST'.
- Hover the X: the tooltip names the container and explains disable and re-enable. There is no 'Anchoring disallowed' error, including on a container attached to another container.
- Left-click the X: that container's auras, preview, outline and strip disappear; no other container changes.
- /am config > Containers with that container selected: Enabled is unchecked. Tick it and the container and its strip come back at the same stored position.
- With the Containers page already open on that container, click its X: the Enabled checkbox updates live.
- Right-click on the strip and on the ? still opens the Containers page. A left-drag on the strip and on the ? still moves the container. A left-drag that starts on the X moves nothing, and releasing off the X does not disable it.
- In combat (unlocked, at a target dummy), click the X: the container hides with no Lua error, no taint and no ADDON_ACTION_BLOCKED; after combat nothing is left over.
- Close a container that others are attached to: the followers re-place exactly as when Enabled is unticked in the panel.
- With test mode on, the X still works and the TEST tag stays readable.
- A container flush against a screen edge on the handle's side: it is pushed in by the wider strip while unlocked and returns on lock.

Needs migration: False

### Risks

- What this review changed:
-   (1) The API docs file is version-10.3-docs.md + members-10.3.json, because the Widgets shell stays at minor 10 and DragHandle goes from 2 to 3. It is not a generic 'new versioned file'.
-   (2) Error output uses NS.Print/NS.Printf (core/CoreSetup.lua:77,93), not bare print.
-   (3) The Anchors.lua header comment explicitly says 'minor 2' and must be bumped.
-   (4) The RESERVE2 call sites are 337/340/352/1256/1270, not only 330-360.
-   (5) Optional: route right-click on the X to onRightClick, for parity with the '?'.
-   (6) The pre-existing non-ASCII em dash at locales/enUS.lua:30 is an existing locale-standard deviation. It is out of scope, but worth noting.
-   Everything else from the prior finding checked out against the code.
- Cross-repo change: it needs LibKa0s v1.59.0 (WidgetsDragHandle minor 3) and a re-vendor into AuraMaster before the addon change. The re-vendor carries tests/_kit too, per the kit pairing rule.
- The opt-in must be exact. A spec without onClose must keep RESERVE, the label bounds and Measure(), or the ConsumableMaster, KickCD and AbsorbTracker strips change width. A library test must pin this.
- The strip grows 36px (symmetric reserve, to keep the label centered). The clamp overhang (Anchors.lua:475/493) grows with it, so a container flush with the screen edge gets pushed further in while unlocked. The asymmetric alternative adds 18px but puts the label off center.
- Accidental disable: one click on an 18px target hides the container, and there is no in-place undo; recovery is only through the options panel or /am set. Mitigations are the tooltip, an optional chat line, or a confirm dialog.
- Click vs drag on the X: the X has no drag scripts, so a drag that starts on it does nothing. This is intended, but it differs from the '?'.
- Followers of a disabled container: this is the existing behavior when Enabled is unticked, but the X makes it one click away.
- CLOSE_FALLBACK art (UI-StopButton) is unverified at 8px under the gray tint. Only a client without LibKa0s media ever sees it.

### Open questions (as raised)

- Should clicking the X print a chat line saying the container was disabled and how to re-enable it, or stay silent?
- Should the X disable immediately (recommended, with the tooltip explaining recovery), or ask for confirmation with a StaticPopup?
- Spacing: symmetric (the label stays centered, the strip grows 36px) or asymmetric (the strip grows 18px, the label shifts left)?
- Should right-click on the X open settings like the strip and the '?' do, or should the X take left-click only?
- Should the other DragHandle hosts (ConsumableMaster, KickCD, AbsorbTracker) adopt the close option later? The change is opt-in either way; this only affects whether to schedule their re-vendors.

## Item 4: ITEM 4 (bug): in test mode, a debuff (HARMFUL) container shows buff placeholders. It should show debuffs covering several dispel types so the dispel border and colors can be tested.

### Root cause / design

ROOT CAUSE (confirmed on feat/2026-09-25-feedback-batch8): the addon has a single placeholder list, every entry on it is a buff, and the preview never reads the container's aura type.

1. core/Constants.lua:264-270 `C.PREVIEW_AURAS` is one flat list of five buffs: Power Word: Fortitude, Bloodlust (dispel="Magic"), Shield Wall (4/8, the running-out entry), Ignore Pain (3 stacks) and Well Fed (timeless). There is no HARMFUL variant.
2. modules/Preview.lua:115 (`placeholderCount`: `local count = #C.PREVIEW_AURAS`) and modules/Preview.lua:148 (`styler.FillPreview(f, C.PREVIEW_AURAS[i], cfg)`) are the only production readers, and neither reads `cfg.auraType` (default "HELPFUL" at defaults/Profile.lua:136; the "Player debuffs" and "Target debuffs (mine)" starters set "HARMFUL" at defaults/Profile.lua:266 and :271). So every container gets the same five buffs, which is exactly what screenshot 14 shows.
3. Precedent: `C.TEXT_SAMPLE_AURAS` (core/Constants.lua:258-261) is already keyed { HELPFUL, HARMFUL }. The test-mode placeholders never adopted that shape.

Two render gaps also block the owner's real goal of testing dispel colors, even once debuff data is in place:
4. Icons: `Icons.FillPreview` (modules/Style_Icons.lua:177-188) never touches `am.dispel`. The ring comes only from the engine binding `AddDispelTypeTexture` with style Border, showWhenHarmful=true and showWhenHelpful=false (Icons.Bind, modules/Style_Icons.lua:160-169). That binding runs only when engine=true (line 145), and preview frames are always dressed with engine=false. Line 143 only ever hides the ring.
5. Bars: `paintSurface` (modules/Style_Bars.lua:185-197) paints every PREVIEW surface in dispel mode with the profile's Magic color ("since no placeholder names a type", comment at 178-179), and `Bars.FillPreview` (351-369) never repaints per aura. The live binding is `showAlways=true, showWithoutDispelType=true` with `DispelColorMap(palette, CurveColor(surface color))` (Style_Bars.lua:298-329). So on a live bar, a typed aura takes its palette color and an untyped one keeps the surface color, on buff and debuff containers alike. The preview's all-Magic stand-in is wrong for both.
6. Text is already correct per aura. `Text.FillPreview` calls `previewTints`, and the `PIECE_TEXT.dispel` word (modules/Style_Text.lua:604-608, 626-658) reads `aura.dispel` through `tintColorMap`, the same map the live engine gets. The live Text tint is showWhenHelpful=true (Style_Text.lua:482), so the buff-side Bloodlust tint is also correct. It only needs debuff data.

DESIGN
(a) Data: make the placeholder set depend on aura type, like TEXT_SAMPLE_AURAS: `C.PREVIEW_AURAS = { HELPFUL = { the current five, unchanged apart from spellId }, HARMFUL = { the six below } }`. Add `Preview.AurasFor(cfg)`, which returns `C.PREVIEW_AURAS[cfg and cfg.auraType] or C.PREVIEW_AURAS.HELPFUL`. Both production readers (Preview.lua:115 and :148) go through it.
(b) Optional but recommended: each entry gains a `spellId`, and at Show time the name and icon come from `NS.Compat.GetSpellInfo(spellId)`. The shim at core/Compat.lua:325 wraps LibKa0s lib.GetSpellInfo (libs/LibKa0s/Compat.lua:162-175), which returns `name, iconID` first, so the second return really is the icon. The literals are the fallback. Memoize a plain field copy (no metatable) per entry for the session, and never write it back into the constant. A secret name can't reach this code: `ShouldShow` previews only while `NS.State.testMode` is on (modules/Container.lua:430), and test mode refuses to start in combat and ends on PLAYER_REGEN_DISABLED (Preview.lua SetTestMode, core/AuraMaster.lua:94). The `type(name)=="string" and name ~= ""` check is enough and matches the existing `named()` in modules/CastAura.lua:71-77. Dropping (b) and keeping hand-entered English literals, as today, is a valid simpler fix (see open questions).
(c) HARMFUL sample list: one debuff per C.DISPEL_TYPES palette entry (core/Constants.lua:169) plus one typeless. It includes one entry under the default 5 s running-out threshold, one with stacks and one timeless, mirroring the buff list:
  1. Shadow Word: Pain, spellId 589, icon 136207, dispel "Magic", 11/16, stacks 0 (same values as TEXT_SAMPLE_AURAS.HARMFUL)
  2. Hex, 51514, icon 237579, "Curse", 42/60, 0
  3. Frost Fever, 55095, icon 237522, "Disease", 18/24, 0
  4. Deadly Poison, 2818, icon 132290, "Poison", 9/12, stacks 3. Invented like Ignore Pain's 3 today: retail Deadly Poison does not stack.
  5. Rupture, 1943, icon 132302, "Bleed", 4/24, 0 (under expiringThreshold 5)
  6. Mortal Wounds, 115804, icon 132355, no dispel, 0/0 (timeless and typeless: exercises the None fallback color, a missing ring and the timeless spark/time)
  Enrage is left out: it is an enemy-buff dispelName, it is not in the palette, and live icons never ring a helpful aura. See the open questions.
(d) Icon ring in preview: at the end of `Icons.FillPreview`, show the ring only when dispelBorder is on (`Style.OrTemplate(ic.dispelBorder, D.icons.dispelBorder)`), `cfg.auraType == "HARMFUL"`, `aura.dispel ~= nil`, and a new `NS.Compat.SetAuraBorderAtlas(am.dispel, aura.dispel)` returns true. In every other case hide it. The wrapper calls `_G.AuraUtil.SetAuraBorderAtlas(region, type, false)`, which is what the engine's Border style calls (research notes 2026-09-13-aura-engine-notes.md:189-199, 257-260), then `SetVertexColor(1,1,1,1)`. When AuraUtil is missing it falls back to `region:SetAtlas("ui-debuff-border-"..lower(type).."-noicon", true)`, and if that returns false it tries "ui-debuff-border-default-noicon", which mirrors DEBUFF_DISPLAY_INFO's "None" fallback. That matches the live rules: a helpful aura (Bloodlust with Magic included) gets no ring, a typeless harmful aura gets no ring, and a typed harmful aura gets the colored art.
(e) Bars dispel color in preview: add a local `previewDispelPaint(tex, stored, useClass, aura)` that indexes `Style.DispelColorMap(Style.ProfileDispelColors(), Style.CurveColor(stored, useClass))[aura.dispel or "None"]` and sets `SetVertexColor(c.r, c.g, c.b, 1)`, leaving the region alpha that paintSurface already set. Call it from `Bars.FillPreview` for am.fill when `b.colorMode=="dispel"` and for am.bg when `b.bgColorMode=="dispel"`. The map is the same object the engine is handed, so preview and live can't disagree. Enrage and None take the surface color, like live. paintSurface keeps its Magic stand-in only as the pre-fill value, and its comment changes to say so. This changes buff containers too: PW:F, Shield Wall and the other untyped buffs now paint the bar color instead of Magic, and only Bloodlust paints Magic. That is correct, because live bars use showAlways.
No schema change and no new saved keys, so NO DB MIGRATION. No new locale keys: spell names stay code constants, like the current list and TEXT_SAMPLE_AURAS.

### Evidence

- core/Constants.lua:264-270: C.PREVIEW_AURAS is a flat list of 5 buffs, with no HARMFUL variant
- modules/Preview.lua:115 (#C.PREVIEW_AURAS) and :148 (C.PREVIEW_AURAS[i]) are the only production readers (grep over core/modules/settings); neither reads cfg.auraType
- defaults/Profile.lua:136 default auraType HELPFUL; :266 'Player debuffs' and :271 'Target debuffs (mine)' starters are HARMFUL
- core/Constants.lua:258-261 C.TEXT_SAMPLE_AURAS already keyed HELPFUL/HARMFUL (precedent)
- modules/Style_Icons.lua:177-188 Icons.FillPreview never sets/shows am.dispel; :143 only hides it; :145 Bind (with AddDispelTypeTexture Border, showWhenHelpful=false, :160-169) runs only when engine=true
- modules/Style_Bars.lua:178-197 paintSurface: preview in dispel mode always paints the profile's Magic color; :351-369 FillPreview never repaints per aura
- modules/Style_Bars.lua:298-329 live bar dispel tint is showAlways=true, showWithoutDispelType=true, map = DispelColorMap(palette, CurveColor(surface)), so live untyped auras keep the surface color on HELPFUL containers too
- modules/Style.lua:621-667 ProfileDispelColors / DispelColorMap: CreateColor entries with .r/.g/.b, None and EXTRA types (Enrage) = fallback; tests/_kit/mock_base.lua:1152 CreateColor mock returns {r,g,b,a}
- modules/Style_Text.lua:604-608, 626-658 (and live tint options :478-486, showWhenHelpful=true): text preview already follows aura.dispel
- libs/LibKa0s/Compat.lua:162-175 lib.GetSpellInfo returns info.name, info.iconID first; core/Compat.lua:325-329 wraps it
- modules/Container.lua:430 previewing == NS.State.testMode; core/AuraMaster.lua:94 test mode ends on PLAYER_REGEN_DISABLED; Preview.SetTestMode refuses in combat, so no secret spell names can reach the preview
- docs/superpowers/research/2026-09-13-aura-engine-notes.md:189-199, 257-260: Border style = AuraUtil.SetAuraBorderAtlas(tex, dispelName, false) + SetVertexColor(1,1,1,1); unknown type falls to DEBUFF_DISPLAY_INFO.None (ui-debuff-border-default-noicon)
- modules/Container.lua:386 Apply sets previewDirty, so an auraType switch re-dresses with the new set
- tests/test_render_coverage.lua:196-205 rig picks the FIRST starter of each style: icons = 'Player debuffs' (HARMFUL), so the icons.dispelBorder row's preview signature changes under this fix
- docs/test-cases.md:803 lists the retiring 'Magic color' test name; the file is generated (lua tests/run.lua --list) and checked by tests/test_docs.lua
- docs/data-flow.md:207 cites modules/Preview.lua:135 (Preview.Show). Adding AurasFor/resolve above it shifts the line, and test_docs checks file:line citations
- Screenshot 14: Target Debuffs (Mine) TEST shows the same five buff placeholders as the buff containers

### Files

- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/core/Constants.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Preview.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Style_Icons.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Style_Bars.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/core/Compat.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_preview.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_container.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_style.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_style_bars.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_style_icons.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_style_text.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_compat.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_render_coverage.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/test-cases.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/data-flow.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/smoke-tests.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/module-map.md

### Implementation sketch

1. core/Constants.lua (replace lines 263-270):
   -- Placeholder auras for preview mode (preview-mode), per aura type: real render path, invented data.
   -- name/icon are fallbacks; Preview resolves the client's own from spellId. HARMFUL covers every
   -- C.DISPEL_TYPES entry plus one typeless, so the dispel ring, bar tint and text word can be checked.
   C.PREVIEW_AURAS = {
     HELPFUL = {
       { spellId = 21562,  name = "Power Word: Fortitude", icon = 135987,  remaining = 3540, duration = 3600, stacks = 0 },
       { spellId = 2825,   name = "Bloodlust",   icon = 136012,  remaining = 28, duration = 40, stacks = 0, dispel = "Magic" },
       { spellId = 871,    name = "Shield Wall", icon = 132362,  remaining = 4,  duration = 8,  stacks = 0 },
       { spellId = 190456, name = "Ignore Pain", icon = 1377132, remaining = 11, duration = 12, stacks = 3 },
       { spellId = 19705,  name = "Well Fed",    icon = 136000,  remaining = 0,  duration = 0,  stacks = 0 },
     },
     HARMFUL = {
       { spellId = 589,    name = "Shadow Word: Pain", icon = 136207, remaining = 11, duration = 16, stacks = 0, dispel = "Magic" },
       { spellId = 51514,  name = "Hex",               icon = 237579, remaining = 42, duration = 60, stacks = 0, dispel = "Curse" },
       { spellId = 55095,  name = "Frost Fever",       icon = 237522, remaining = 18, duration = 24, stacks = 0, dispel = "Disease" },
       { spellId = 2818,   name = "Deadly Poison",     icon = 132290, remaining = 9,  duration = 12, stacks = 3, dispel = "Poison" },
       { spellId = 1943,   name = "Rupture",           icon = 132302, remaining = 4,  duration = 24, stacks = 0, dispel = "Bleed" },
       { spellId = 115804, name = "Mortal Wounds",     icon = 132355, remaining = 0,  duration = 0,  stacks = 0 },
     },
   }

2. modules/Preview.lua:
   local resolved = {}   -- [entry] = a plain copy with the client's name and icon, once per session
   local function resolve(a)
     local r = resolved[a]; if r then return r end
     local name, icon = NS.Compat.GetSpellInfo(a.spellId)
     r = { name = (type(name) == "string" and name ~= "") and name or a.name,
           icon = (type(icon) == "number") and icon or a.icon,
           remaining = a.remaining, duration = a.duration, stacks = a.stacks, dispel = a.dispel }
     resolved[a] = r; return r
   end
   --- The placeholder set for `cfg`'s aura type (HELPFUL when unknown).
   function Preview.AurasFor(cfg) return C.PREVIEW_AURAS[cfg and cfg.auraType] or C.PREVIEW_AURAS.HELPFUL end
   placeholderCount: `local count = #Preview.AurasFor(cfg)`.
   Show: `local auras = Preview.AurasFor(cfg)` before the loop; `styler.FillPreview(f, resolve(auras[i]), cfg)`.
   Update the header and the placeholderCount docstring ("every placeholder aura of its type").

3. core/Compat.lua (Everything else section):
   --- Blizzard's debuff border art for `dispelType` on `region`, as the engine's Border style sets it
   --- (AuraUtil.SetAuraBorderAtlas, then white). False when no route draws it.
   function Compat.SetAuraBorderAtlas(region, dispelType)
     local AU = _G.AuraUtil
     if AU and AU.SetAuraBorderAtlas then
       AU.SetAuraBorderAtlas(region, dispelType, false)
     elseif region.SetAtlas then
       if not region:SetAtlas("ui-debuff-border-" .. string.lower(dispelType) .. "-noicon", true)
          and not region:SetAtlas("ui-debuff-border-default-noicon", true) then return false end
     else return false end
     region:SetVertexColor(1, 1, 1, 1)
     return true
   end
   (Read it as `_G.AuraUtil`. Do NOT add AuraUtil to .luacheckrc read_globals: test_lintconfig holds that list to globals read bare.)

4. modules/Style_Icons.lua Icons.FillPreview, after the cooldown block:
   local ic = (cfg and cfg.icons) or {}
   local ring = Style.OrTemplate(ic.dispelBorder, D.icons.dispelBorder) and cfg and cfg.auraType == "HARMFUL"
       and aura.dispel ~= nil and NS.Compat.SetAuraBorderAtlas(am.dispel, aura.dispel)
   am.dispel:SetShown(ring and true or false)
   Update the Icons.Bind comment and docstring: a placeholder takes the same art from FillPreview.

5. modules/Style_Bars.lua:
   --- A placeholder surface colored by dispel type, repainted in ITS aura's color from the map the engine is handed.
   local function previewDispelPaint(tex, stored, useClass, aura)
     local c = Style.DispelColorMap(Style.ProfileDispelColors(), Style.CurveColor(stored, useClass))[aura.dispel or "None"]
     if c then tex:SetVertexColor(c.r or 1, c.g or 1, c.b or 1, 1) end
   end
   In Bars.FillPreview after previewText:
     if b.colorMode == "dispel" then previewDispelPaint(am.fill, b.barColor, b.useClassColorBar, aura) end
     if b.bgColorMode == "dispel" then previewDispelPaint(am.bg, b.bgColor, b.useClassColorBg, aura) end
   Rewrite the paintSurface comment (178-179): the Magic stand-in holds only until FillPreview repaints per aura.

6. Docs: module-map.md Preview row (per-type placeholder sets, Preview.AurasFor) and the Compat row (SetAuraBorderAtlas). data-flow.md:207 (re-point the Preview.Show line citation, "invented names per aura type"). smoke-tests.md: add the checks below. Regenerate docs/test-cases.md with `lua tests/run.lua --list > docs/test-cases.md` and bump any count badge that test_docs ties to its totals.
No schema, version or migration change; no locale keys.

### Tests

- tests/test_preview.lua: 'preview: a HARMFUL container draws the HARMFUL placeholder set' uses cfg({auraType='HARMFUL', style='icons'}) and Preview.Show, then asserts active == #C.PREVIEW_AURAS.HARMFUL and placeholder 1's icon SetTexture == HARMFUL[1].icon (GetSpellInfo answering nil in the harness). Red under the current code.
- tests/test_preview.lua: 'Preview.AurasFor falls back to HELPFUL' checks that AurasFor({}) and AurasFor({auraType='BOGUS'}) are C.PREVIEW_AURAS.HELPFUL and AurasFor({auraType='HARMFUL'}) is HARMFUL
- tests/test_preview.lua: 'a placeholder's name and icon come from its spell id when the client answers' stubs NS.Compat.GetSpellInfo to return 'Localized', 999 and asserts FillPreview got name 'Localized' and icon 999. A nil or empty answer falls back to the literals, and the constant table is left unmodified.
- tests/test_preview.lua: 'switching auraType re-dresses the placeholders' calls Show, sets cfg.auraType='HARMFUL' and previewDirty=true (as Apply does), then calls Show again: the icons match the HARMFUL set and the count is 6
- Constants invariant (test_preview.lua): HARMFUL's dispel values cover every C.DISPEL_TYPES entry and include one nil. Every entry in both sets has a numeric spellId, icon, remaining, duration and stacks. HARMFUL has an entry with 0 < remaining < D.bars.expiringThreshold, one with stacks >= 2 and one with duration 0. test_style.lua:958 (the B-5 running-out case) iterates both sets.
- Update the flat-list readers to the keyed shape: test_preview.lua 39/61/83/89/112/126/128/154/247/261/286/335 (default buff cfg, so .HELPFUL; the extent test at 335 keeps 5), test_container.lua:154, test_style_bars.lua:879/890/897, test_style_icons.lua:425
- tests/test_compat.lua: SetAuraBorderAtlas calls _G.AuraUtil.SetAuraBorderAtlas(region,'Poison',false) and SetVertexColor(1,1,1,1) when AuraUtil exists. Without AuraUtil it calls SetAtlas('ui-debuff-border-poison-noicon', true), falls back to default-noicon when that returns false, and returns false for a region without SetAtlas.
- tests/test_style_icons.lua: 'a HARMFUL placeholder shows Blizzard's ring for its type' fills a Poison aura on an auraType=HARMFUL cfg; am.dispel got the atlas and is shown. Hidden cases: a typeless debuff, Bloodlust (dispel=Magic) on a HELPFUL cfg, and icons.dispelBorder=false. Red under the current code (no SetAtlas and no Show).
- tests/test_style_bars.lua: replace 'a dispel-colored preview paints the Magic color, since no real aura names a type' with 'a dispel-colored placeholder paints its own type's palette color'. A Poison aura gives fill SetVertexColor == dispelColors.Poison rgb,1. A typeless aura gives barColor's rgb (the None fallback). bgColorMode='dispel' behaves the same on am.bg. colorMode static is left untouched by FillPreview. Region alpha is still opacity x the color's alpha.
- tests/test_style_text.lua: 'a HARMFUL placeholder's dispel word and tints follow its own type': a Curse entry gives the Curse word and the Curse backdrop tint, and Mortal Wounds gives no word and no tint
- tests/test_render_coverage.lua: no edit expected. Run it to confirm the icons rig ('Player debuffs', HARMFUL) still sees icons.dispelBorder reach the placeholders (on shows the ring, off hides it), and that no row's coverage exemption goes stale
- Run lua tests/run.lua in full plus luacheck. Regenerate docs/test-cases.md, because test_docs enforces the generated inventory and file:line citations such as data-flow.md:207.

### Smoke

- /am test on the default profile: 'Target debuffs (mine)' and 'Player debuffs' show Shadow Word: Pain, Hex, Frost Fever, Deadly Poison (3), Rupture (running out, 4 s) and Mortal Wounds (no timer), all with real icons. The buff containers still show PW:F, Bloodlust, Shield Wall, Ignore Pain and Well Fed.
- Icons debuff container with Border > Color the border by dispel type ON: Blizzard's colored ring on SW:P (Magic), Hex (Curse), Frost Fever (Disease), Deadly Poison (Poison) and Rupture (Bleed art, or the default art if the client has none), and no ring on Mortal Wounds. Turn it OFF and every ring goes at once. An icons buff container never shows a ring, Bloodlust included.
- Bars container with Color by = dispel type: on a debuff container each bar takes its type's color from General > Dispel Colors and Mortal Wounds keeps the bar color. Change the Poison swatch and the Deadly Poison bar recolors during test mode. On a buff container only Bloodlust is Magic-colored and the others keep the bar color (before this fix every bar was Magic). Repeat with Background color = dispel type.
- Text debuff container using the name-type-time template with dispel backdrop and edge on: each line shows its type word, tinted when 'Color the dispel type' is on. Mortal Wounds shows no type and no tint.
- Switch a container's Shows between Buffs and Debuffs during test mode: the placeholder set swaps without a /reload, and a container attached to it still sits right past the 6 debuff placeholders (5 for buffs)
- Set Max auras = 3 on a debuff container during test mode: only SW:P, Hex and Frost Fever show
- Verify ids and icons once: /dump C_Spell.GetSpellInfo(51514) (and 55095, 2818, 1943, 115804): each returns a name and an iconID, and no placeholder shows a question-mark icon

Needs migration: False

### Risks

- CHANGED vs the prior finding: the secret-name risk is moot. The preview only runs while testMode is on (Container.lua:430), and test mode can't start or stay on in combat (Preview.SetTestMode, core/AuraMaster.lua:94). The resolve step uses the same string/non-empty check as CastAura.named().
- CHANGED: the resolved placeholder is a plain field copy, not a setmetatable __index proxy, so it has no hidden inheritance and can't mutate the constant
- CHANGED: the Compat.SetAuraBorderAtlas fallback now also tries 'ui-debuff-border-default-noicon' when the per-type atlas is missing (SetAtlas returns false), which mirrors DEBUFF_DISPLAY_INFO's None fallback. Without that, a Bleed ring could silently draw nothing on a client without AuraUtil.
- CHANGED: noted that the Bars fix also changes buff containers. Untyped buffs now paint the bar color and only Bloodlust paints Magic. That is correct, because the live binding is showAlways with the surface color as the None fallback (Style_Bars.lua:298-329), but it will look different to the owner.
- ADDED missed files: tests/test_render_coverage.lua (its icons rig is the HARMFUL 'Player debuffs' starter, so the dispelBorder row's preview signature changes), tests/test_compat.lua (new wrapper), docs/test-cases.md (generated and enforced by test_docs; one test name retires) and docs/data-flow.md:207 (a Preview.lua:135 line citation that test_docs checks and that shifts)
- ADDED: read AuraUtil as _G.AuraUtil and do not add it to .luacheckrc read_globals, because tests/test_lintconfig.lua requires every read_globals entry to be read bare somewhere
- C.PREVIEW_AURAS changes shape. A missed reader would get #tbl == 0 and silently draw nothing. Grep finds only Preview.lua:115/148 in production plus about 20 test sites. Alternatively, rename it (C.PREVIEW_AURA_SETS) so a stale reader errors loudly.
- Spell ids and icon fileIDs are hand-picked and not verified in this session (no client or wowhead access). With (b), a stale fileID matters only when C_Spell fails. Without (b), check each one in game. Deadly Poison's 3 stacks and Mortal Wounds being timeless are invented values, as Ignore Pain's 3 stacks are today.
- The HARMFUL set has 6 entries and HELPFUL has 5, so the preview extent differs by container type. Any test that hard-codes 5 must use a HELPFUL cfg.
- AuraUtil.SetAuraBorderAtlas is FrameXML and could be renamed. The Compat wrapper's literal-atlas fallback covers that.

### Open questions (as raised)

- Enrage: you listed 'Bleed/Enrage/none'. Enrage is a dispel type found on enemy BUFFS, so it can't appear in a debuff container. It isn't in the Dispel Colors palette either: bars treat it as the surface color, Text leaves it untinted, and live icons never ring a buff. Should the buff placeholder set gain an Enrage entry (e.g. Enrage 184362) so the Text '(Enrage)' word can be previewed on a target-buffs container, or should Enrage stay out?
- Is this debuff roster OK: Shadow Word: Pain (Magic), Hex (Curse), Frost Fever (Disease), Deadly Poison (Poison), Rupture (Bleed), and Mortal Wounds (no type, no timer)? Or would you rather see spells from your own class?
- Should placeholder names and icons come from the game client by spell id (localized, and icons always current)? Or should they stay fixed English names and icon numbers, as the buff placeholders are today? The fixed version is simpler.

## Item 7: ITEM 7 (feature): a "Size to fit" option for Text-style containers. It sizes the element's width and height from its content. It is on for new profiles and new containers, and a v8 migration sets it off for existing containers.

### Root cause / design

WHAT IS POSSIBLE (I checked this and agree with it). A true live autosize, where each aura's box follows its own text, cannot be built. There are three reasons:
(a) Every engine-written piece is a secret, auto-sized font string. Its width is never readable (modules/Style_Text.lua:9-15).
(b) The engine flow layout takes ONE elementWidth/elementHeight per group (modules/Container.lua:98-107). The same size feeds FlowSettings.maxLineSize (Container.lua:84-96), the anchor (Anchors.lua:218), the outline (Container.lua:477), the handle floor (Anchors.lua:469), the preview (Preview.lua:47,178), and Text.Apply's frame:SetSize (Style_Text.lua:549-553).
(c) No addon code may touch a button in combat.

So "content size" means a size derived at dress time from the settings (template, font, icon, justify, animation). The width is measured on the addon's own hidden measuring string, which is never secret. This is the approach already shipped for B4 (Style.TimeTextWidth, Style.lua:190-240) and item 8 (Style.PiecePadding, Style.lua:252-296). The owner must be told this plainly.

DESIGN. Add a new leaf, text.autoSize (bool). When it is on, Style.ElementSize (modules/Style.lua:669-676) replaces the stored width and height with Style.Text.AutoSize(s, cfg.auraType). ElementSize is the single size source every consumer reads, so no other call site changes.

HEIGHT (no measuring; computed in this order because the icon depends on it):
1. lineH = fontSize + 2*C.TEXT_AUTOSIZE_PAD. With PAD = 2, a 12pt font gives 16, the current default height, so a default container does not change height.
2. A LEFT or RIGHT icon with iconSize > 0 raises lineH to at least iconSize. iconSize 0 means "element height" (Style.IconSizeFor, Style.lua:153-156) and adds no height.
3. base = max(lineH, Text.StackHeight(s)) (Style_Text.lua:256-261).
4. Bounce headroom, when anim == "bounce". The Translation moves up by animBounce (Style_Text.lua:103-106,366), and the clip frame cuts anything above the element. The headroom depends on justifyV. MIDDLE adds 2*animBounce: centering gives the text only half the added space above it. BOTTOM adds animBounce. TOP cannot be helped by extra height, because the text is pinned to the top edge; that clipping already happens today, so it is noted and not fixed.
5. h = base + headroom.

WIDTH (measured). A correction to the first finding: the icon inset has to use the FINAL h.
- layoutIconAndArea sizes a non-stacked icon from the element height h (Style_Text.lua:215-217: `lineHeight = Stacked and fontSize or h`).
- So inset = IconSizeFor(s, D, stacked and fontSize or h) + iconGap, with h computed after the bounce headroom. The first finding used lineH before the bounce. With iconSize 0 and bounce on, its width came out animBounce short, and the text area would be cut early.
- textW = the widest string over the sample set, measured on Style.__measurer in the line's font with the FALLBACK_FONT retry. Stacked lines are split on newline and each row is measured. The chain pulls pieces back by PiecePadding, so one concatenated string measures the same as the chain.
- w = clamp(ceil(textW + inset + abs(x) + 2), 40, 600). The + 2 covers the outline and shadow.

SAMPLE SET (a refinement over the first finding):
- Use Text.PreviewLine (Style_Text.lua:664-676) over C.PREVIEW_AURAS plus C.TEXT_SAMPLE_AURAS[auraType].
- ALSO add one synthetic worst-case aura: the longest preview name, stacks 99, and remaining set to each of Style.lua's TIME_SAMPLES (59..863999), duration = remaining.
- Reason: the preview's largest remaining is 3540 s ("59 m"), but live auras show hours and days, and some timeFormats write those wider. This matches exactly what TimeTextWidth does for bars. Expose TIME_SAMPLES as Style.TIME_SAMPLES rather than duplicating it.
- Strip or double a stray literal "|" before measuring.

FAILURE HANDLING:
- If any measure fails (not readable, <= 0, or the font has not loaded yet), return nil. ElementSize then keeps the stored width AND height.
- A failed measure is never cached (the TimeTextWidth rule). The stored width and height therefore still matter as the fallback, so they are dimmed, not hidden.
- Cache a good result by a key of: font path|size|flags|template|justifyH|justifyV|timeFormat|icon|iconSize|iconGap|x|anim|animBounce|auraType.
- The memo is mandatory. ElementSize runs for every button dressed (Text.Apply, Style_Text.lua:549), plus FlowSettings, groupLayout, Anchors.Place, the handle, the outline and the preview.

KNOWN LIMIT: a live name longer than "Power Word: Fortitude" is still cut at the text area's clip edge (Style_Text.lua:139-140). This is the same behavior as today's fixed width.

DEFAULTS AND MIGRATION (DB migration needed):
- CONTAINER_TEMPLATE.text.autoSize = true (defaults/Profile.lua:232-252). Starters (seedStarters, Database.lua:161-176) and new containers (NewContainerData, Database.lua:118) copy the template, so they get true. Duplicate and "Copy settings from" preserve the stored value.
- Recommendation: existing containers stay OFF, because hand-sized layouts must not move.
- backfillContainers (Database.lua:183-195, which calls Backfill at 33-50) would stamp the template's true into every stored container. So a v8 SCHEMA_STEPS row (after Database.lua:955-962) must first stamp false in every stored profile (eachProfile):
  - where c.text is not a table, set c.text = {};
  - where c.text.autoSize == nil, set it to false.
- It is stamped on every container, not only text-style ones: a bars or icons container switched to Text later stays off, which is conservative.
- On a fresh install the ladder runs before PrepareProfile (Database.lua:1003-1024), so v8 walks no containers and the starters get true. A profile created later is seeded by PrepareProfile (AuraMaster.lua:159) after the stamp is already 8, so it also gets true.
- The page Defaults and Reset write the template value (true).
- I considered and rejected an alternative with no migration: template false, with autoSize = true injected only into the starter specs and CM.Create's overrides. It needs no ladder row, but the schema default would then say false while the product default is on, and Defaults/Reset would turn it off. That contradicts "on by default". The migration is small and follows the standard's ladder convention.

UI (settings/Text.lua):
- A bool row "Size to fit" goes first in General > Size, with onChange = structural. structural is the panel refresh at Text.lua:66, needed so the dim state updates.
- Width and Height get disabledIf = sizedToFit.
- A gray note goes under Size while the option is on.
- The schema row is the one write seam, so /am set container.text.autoSize also works. Any container.* write re-applies the container, and the engine re-lays out so attached containers follow.

INTERACTION WITH ITEM 9 (image 11: two chained text containers whose handles and outlines overlap):
- Autosize does NOT fix item 9. The size comes from the settings and placeholders, not from live auras, so an empty container keeps a full-size anchor.
- The overlap comes from targetFor (Anchors.lua:80-96) attaching to target.engine, whose rect collapses when the target is empty.
- The item 9 fix must read sizes only through Style.ElementSize. It must not assume the 16px/220px defaults: autosize can make an 11pt line 15 tall and narrower than 220. It must also let the handle strip (Anchors.lua:469-478) be wider than a narrow element.
- Implement item 9 with or before item 7, and smoke-test them together.

### Evidence

- modules/Style_Text.lua:9-15 - pieces are secret, auto-sized, engine-written font strings, so their widths are never readable
- modules/Style.lua:669-676 - Style.ElementSize is the single size source and already grows text height to StackHeight
- modules/Style_Text.lua:549-553 - Text.Apply calls ElementSize for EVERY dressed button and SetSizes the frame (why the memo is mandatory)
- modules/Container.lua:84-107 - FlowSettings.maxLineSize and groupLayout elementWidth/elementHeight come from ElementSize (one size per engine group)
- modules/Anchors.lua:218, :469 - the anchor SetSize and the handle floor come from ElementSize
- modules/Container.lua:477; modules/Preview.lua:47,178 - the outline and the preview are sized from ElementSize
- modules/Style_Text.lua:210-228 layoutIconAndArea - a non-stacked icon with iconSize 0 is sized from the ELEMENT height h (line 215), so the width inset must use the final autosized h, including bounce headroom
- modules/Style.lua:153-156 Style.IconSizeFor - iconSize 0 means use the passed height
- modules/Style_Text.lua:103-106, :366 - bounce is an upward Translation of animBounce inside the clip frame (Style_Text.lua:135-140), so headroom depends on justifyV
- modules/Style.lua:207-240 - Style.__measurer, TIME_SAMPLES, widestSample and TimeTextWidth: the measuring precedent, with failed measures never cached
- modules/Style.lua:252-296 - PiecePadding: the chain is pulled flush, so a concatenated measure equals the chain width
- modules/Style_Text.lua:256-261 - StackHeight is fontSize per row plus C.TEXT_ROW_GAP
- modules/Style_Text.lua:664-676 - Text.PreviewLine joins stacked rows with a newline (split before measuring)
- core/Constants.lua:258-270 - C.TEXT_SAMPLE_AURAS and C.PREVIEW_AURAS; the largest remaining is 3540 s, so the preview never samples hour or day durations
- defaults/Profile.lua:232-252 - CONTAINER_TEMPLATE.text (width 220, height 16, font 12, x 2, animBounce 3)
- core/Database.lua:33-50, 183-195 - Backfill/backfillContainers would stamp a template true onto existing containers without a v8 step
- core/Database.lua:118, 161-176 - NewContainerData and seedStarters copy the template
- core/Database.lua:906-970, 986-1024 - SCHEMA_STEPS ends at v7; climbLadder runs before PrepareProfile
- core/AuraMaster.lua:159 - PrepareProfile on profile change or new profile seeds starters after the stamp is current
- settings/Text.lua:66 structural(), :99-101 unlessOn, :106-110 Width/Height rows, :355-365 renderGeneral size bucket
- modules/Style.lua:732-736 StructureKey - autosize does not change the shape, so no engine rebuild is needed; a normal apply suffices
- modules/Anchors.lua:80-96 targetFor - item 9's overlap source (target.engine rect), which autosize does not change
- tests/test_style_text.lua:122-138 padded() installs a measurer (6 px per char + 2) and merges the full template, so autoSize would be on there
- docs/schema.md:212 - the 'Text 36' row-count claim; :503 and :659 - the Migration path section ends at v7

### Files

- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/defaults/Profile.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/core/Constants.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/core/Database.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Style.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Style_Text.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/settings/Text.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/locales/enUS.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/schema.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/settings-panel.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/smoke-tests.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/midnight-quirks.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_style_text.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_migrations.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_database_categories.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_render_coverage.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_pages_text.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_docs.lua

### Implementation sketch

1. defaults/Profile.lua, CONTAINER_TEMPLATE.text: add `autoSize = true,` beside width and height, with a comment. Starters and new containers get true; existing containers get false from v8.

2. core/Constants.lua: add C.TEXT_AUTOSIZE_PAD = 2, C.TEXT_WIDTH_MIN = 40, C.TEXT_WIDTH_MAX = 600. The Width row imports min and max from these, so the clamp and the row cannot drift apart.

3. modules/Style.lua:
- Rename the local TIME_SAMPLES to Style.TIME_SAMPLES, or add an accessor.
- Add Style.WidestLine(t, tdef, lines). It resolves path, size and flags as TimeTextWidth does. A pcall-guarded local measures each string on Style.__measurer with the FALLBACK_FONT retry. It returns the widest width, or nil when any width is not NS.Secrets.IsReadableNumber or the widest is <= 0. Nothing is cached here; Text.AutoSize memoizes the whole result.
- ElementSize becomes:
  local w, h = stored
  if key == "text" and Style.Text then
    local on = s.autoSize; if on == nil then on = sdef.autoSize end
    if on then local aw, ah = Style.Text.AutoSize(s, cfg.auraType); if aw then return aw, ah end end
    h = math.max(h, Style.Text.StackHeight(s))
  end
  return w, h

4. modules/Style_Text.lua, add Text.AutoSize(s, auraType), which returns w, h or nil.
- key = concat of: font path/size/flags, template, justifyH, justifyV, timeFormat, icon, iconSize, iconGap, x, anim, animBounce, auraType. Return memo[key] if present.
- compiled = Text.Compiled(s); stacked = Text.Stacked(s, compiled); fs = fontSize(s).
- Height:
  - lineH = fs + 2*C.TEXT_AUTOSIZE_PAD
  - pos = s.icon or D.icon; iconSet = number(s.iconSize, D.iconSize)
  - if (pos == 'LEFT' or pos == 'RIGHT') and iconSet > 0 then lineH = max(lineH, iconSet) end
  - h = max(lineH, Text.StackHeight(s))
  - if (s.anim or D.anim) == 'bounce' then b = number(s.animBounce, D.animBounce); jv = s.justifyV or D.justifyV; h = h + (jv == 'MIDDLE' and 2*b or jv == 'BOTTOM' and b or 0) end
- Width:
  - inset = 0; if pos is LEFT/RIGHT then inset = Style.IconSizeFor(s, D, stacked and fs or h) + number(s.iconGap, D.iconGap) end. This uses the FINAL h, mirroring layoutIconAndArea:215.
  - lines = {}. For each aura in C.PREVIEW_AURAS, plus C.TEXT_SAMPLE_AURAS[auraType or 'HELPFUL'] (HELPFUL fallback), plus worst-case auras {name = longest preview name, stacks = 99, remaining = r, duration = r} for each r in Style.TIME_SAMPLES: split Text.PreviewLine(s, a) on '\n' and append each row, with '|' doubled.
  - textW = Style.WidestLine(s.font or {}, D.font, lines); if not textW then return nil (not cached).
  - w = clamp(ceil(textW + inset + abs(number(s.x, D.x)) + 2), C.TEXT_WIDTH_MIN, C.TEXT_WIDTH_MAX)
  - memo[key] = {w, h}; return w, h.
- The memo is a plain table capped by clearing it when it passes 64 entries. Update the header comment: the size comes from placeholders at dress time, never from live text.

5. core/Database.lua:
- Add Database.MigrateV8(p). Return 0 unless p.containers is a table. For each container c that is a table: if type(c.text) ~= 'table' then c.text = {} end; if c.text.autoSize == nil then c.text.autoSize = false; n = n + 1 end. Return n.
- Append { to = 8, apply = function(db) eachProfile(db, function(p, name) local n = Database.MigrateV8(p); NS.Debug('Migrate', "v8 profile '%s': Size to fit stamped off on %s existing container(s)", name, n) end) end }.
- It is idempotent and runs zero times on a fresh default profile. NS.SCHEMA_VERSION becomes 8 automatically.

6. settings/Text.lua:
- Add `local function sizedToFit() return textBlock().autoSize == true end`.
- Insert before width: { path = P..'autoSize', page = PAGE, group = G_GENERAL, subgroup = L['Size'], type = 'bool', startsLine = true, label = L['Size to fit'], desc = L[<desc>], onChange = structural }.
- The width row gets disabledIf = sizedToFit, min = C.TEXT_WIDTH_MIN, max = C.TEXT_WIDTH_MAX. The height row gets disabledIf = sizedToFit.
- renderGeneral: after the Size rows, draw a gray SMALL note when sizedToFit(): L['Width and height follow the font, the icon and the template while Size to fit is on. They still apply if the size cannot be measured.'].
- Update the header ASCII map.

7. locales/enUS.lua, ASCII only (no em dash):
- L['Size to fit'] = true
- L["Size each line's box to its content: the height from the font, the icon, a stacked Center's rows and the bounce, the width from the widest line the placeholders draw. A live aura name longer than those is cut off at the edge. Turn off to set the size by hand."] = true
- plus the note key above.

8. Docs:
- docs/schema.md: the text block gets autoSize (default true; existing containers false via v8). Add a v8 entry to the Migration path. Change the Text row count from 36 to 37.
- docs/settings-panel.md: the General > Size rows.
- docs/midnight-quirks.md: why autosize cannot be live.
- docs/smoke-tests.md: the new checks.
- Check that no other doc states "schema v7" as current: ARCHITECTURE.md only cites v5 historically.

### Tests

- tests/test_style_text.lua: with autoSize=false, ElementSize returns the stored width/height (plus StackHeight growth) unchanged; a regression guard for migrated containers
- tests/test_style_text.lua: under padded() (6 px per char + 2) with autoSize=true, width = the widest sampled line + |x| + 2, clamped to 40..600; a bigger fontSize or a longer template widens it
- tests/test_style_text.lua: autoSize height = fontSize + 4 (12pt gives 16); icon LEFT with iconSize 24 gives height 24 and adds 24 + iconGap to the width
- tests/test_style_text.lua: icon LEFT, iconSize 0, anim=bounce, justifyV MIDDLE: height = 16 + 2*animBounce AND the width inset = that FINAL height + iconGap (the corrected ordering; it goes red if the inset uses the pre-bounce height)
- tests/test_style_text.lua: bounce headroom is 2*b for MIDDLE, b for BOTTOM, and 0 for TOP
- tests/test_style_text.lua: a stacked Center: height = StackHeight, and the width is the widest ROW, not the newline-joined string
- tests/test_style_text.lua: the worst-case duration samples are measured (the recorder's SetText log includes a TIME_SAMPLES formatting such as the 863999 s string)
- tests/test_style_text.lua: a failed measure (0, then a secret width) keeps the stored width AND height and is not memoized; a later successful measure autosizes
- tests/test_style_text.lua: the memo is hit, so a second ElementSize with the same settings does no SetText on the measurer, and a changed fontSize misses
- tests/test_style_text.lua: the Text.Apply frame SetSize, Container.FlowSettings maxLineSize, groupLayout elementWidth/Height and Anchors.Place anchor SetSize all see the autosized size
- tests/test_style_text.lua: audit the existing padded() tests; any that assert a SetSize must pass autoSize=false in textCfg
- tests/test_migrations.lua: MigrateV8 stamps false on every container of every stored profile (inactive profiles included), creates a missing or non-table text, keeps a stored true, is idempotent, and walks zero containers on a fresh profile; NS.SCHEMA_VERSION == 8
- tests/test_migrations.lua: a v7-stamped account with containers loads with autoSize=false and ElementSize = stored; a fresh install's seeded starters carry autoSize=true; a new profile created after migration seeds starters with true
- tests/test_containermanager.lua: CM.Create in a migrated profile yields autoSize=true; Duplicate keeps the source's false
- tests/test_pages_text.lua: the Size to fit row renders first in Size; Width/Height are disabled while it is on and enabled while it is off; the note shows only while it is on
- tests/test_render_coverage.lua: the baseline sets text.autoSize=false so Width/Height still reach SetSize; install a measurer so toggling autoSize visibly changes SetSize
- tests/test_docs.lua: the Text row count (37) and any schema-version claim match
- test_defaults / test_schema_paths / test_locale: the new leaf has a schema row and locale keys, ASCII only; these run automatically

### Smoke

- Existing profile after update: every text container keeps its width and height, and Size to fit is unchecked. `/am set container.text.autoSize true` resizes it at once, and the handle and outline follow.
- New profile (Profiles > new): the starter text container has Size to fit checked. Its box is about as wide as 'Power Word: Fortitude' plus the widest time string, and 16 px tall at 12pt.
- New container created in an existing profile and set to Style Text: Size to fit is on.
- With Size to fit on: changing the font size, the template, the timeFormat, Icon Left size 24, and Justify Center with a 3-field template each resize the box. Width and Height are grayed, and the note shows.
- Icon Left with size 0 plus Bounce: the icon and the text are not clipped at the right, and at MIDDLE/BOTTOM the bounce is not clipped at the top. At TOP it is still clipped (pre-existing).
- A live buff with a long name (e.g. Incarnation: Chosen of Elune) is cut at the box edge and never overlaps its neighbor in a horizontal layout.
- A long-duration aura (hours or days) shows its full time string without being cut.
- Combat: gain and lose auras; no errors, and the size does not change. Toggling Size to fit in combat defers and applies on leaving combat.
- Login with a custom SharedMedia font: at worst a one-apply fallback to the stored size, then autosized on the next apply. No persistent wrong size.
- Item 9 together (image 11): chain two text containers with the first one empty, with Size to fit on and off. The handles and outlines must not overlap.

Needs migration: True

### Risks

- CHANGED vs the first finding: the icon inset must use the FINAL height (after bounce headroom). layoutIconAndArea sizes a non-stacked iconSize-0 icon from the element height (Style_Text.lua:215). The first sketch computed the inset from lineH before bounce, so its width came out animBounce too short and cut the text.
- CHANGED: the bounce headroom now depends on justifyV. MIDDLE needs 2*animBounce, because centering gives only half the added space above the text. BOTTOM needs animBounce. TOP cannot be fixed by height; that clipping already exists. The first finding added a flat animBounce, which still clips at MIDDLE for animBounce > about 4.
- CHANGED: the width sample set adds a worst-case aura over Style.TIME_SAMPLES. The preview's largest remaining is 3540 s, so live hour and day durations could be wider than the budget and get cut. This reuses the B4 sample list rather than inventing one.
- CHANGED: the early-return shape of ElementSize. The autosized height already includes StackHeight, and the stored-size path keeps the StackHeight growth.
- CHANGED: I recorded and rejected the alternative without a migration (template false, overrides for starters and Create). The owner may prefer it if an extra ladder row is unwelcome.
- Owner expectation: this is not a per-aura live autosize. Secret widths, one element size per engine group and combat lockdown make that impossible. Names longer than the placeholders are clipped.
- Without v8, backfillContainers silently turns autosize ON for every existing container and moves hand-tuned layouts. The migration is load-bearing, and the ladder already runs before PrepareProfile.
- Defaults/Reset on the Text page now turns Size to fit ON (the template value). This is a visible change for players who reset.
- A font that is not loaded yet measures 0 on the first dress. The code falls back to the stored size and re-measures later, so there may be a one-apply size flicker at login (as with TimeTextWidth).
- Autosized boxes can be narrower or shorter than 220x16. This changes the pitch in layouts and container chains, and the handle strip can be wider than its element. Item 9's fix must not assume the old defaults.
- Performance: ElementSize runs per dressed button plus 5+ layout call sites, so the memo is mandatory. Building the key string allocates per call; this is acceptable at dress time, which is never per frame.
- Tests: padded() in test_style_text installs a measurer and merges the full template, so existing padded tests that check SetSize may change and should pass autoSize=false. The bars measuring() helper is unaffected (bars style). test_render_coverage needs its baseline set to autoSize=false.

### Open questions (as raised)

- Existing containers: I recommend OFF, set by the v8 migration, so hand-sized layouts do not move. Confirm, or should existing text containers be switched ON too?
- Should a NEW container in an EXISTING profile also start with Size to fit on? The template default gives yes, and I recommend yes.
- Width budget: (a) the widest placeholder line plus worst-case durations (recommended); (b) (a) plus extra room for longer live names; or (c) autosize the height only and keep Width manual, or use Width as a maximum while Size to fit is on?

## Item 8: ITEM 8 (feature): an optional per-container name label that sits where the unlock-mode drag handle sits and stays visible while locked (modeled on KickCD's "Text Label")

### Root cause / design

VERIFIED MODEL (KickCD). KickCD's "Text Label" (settings/Label.lua, drawn by modules/UnitLabel.lua) is a per-unit identity label: one FontString on a 1x1 holder. The holder is created on UIParent and reparented to the unit's icon grid (UnitLabel.lua:146-155), so it follows the grid's General visibility and alpha. It does not depend on lock state. While unlocked, the drag strip is stacked ABOVE the label rather than replacing it (IconGrid.lua:675-691 anchorHandle -> UnitLabel:FrameAbove). KickCD has no "placeholder" feature by that name. The owner's "placeholder text" is this label.

AURAMASTER TODAY (verified). The drag handle is LibKa0s-Widgets' DragHandle, and its text is already cfg.name, with a TEST tag in test mode (modules/Anchors.lua:390-395 handleText). placeHandle (Anchors.lua:466-478) sets the handle to SetPoint(away, anchor, toward, 0, +/-DRAG.GAP), outside the anchor on the side the auras do not grow into. The effective (follower-inherited) growth is used, and the width is floored at Style.ElementSize. The handle shows only while unlocked (Container.lua:508-510 -> Anchors.UpdateHandle :514-526). A locked container has no on-screen identity.

DESIGN (the previous agent's design holds, with the corrections below):
1. Per-container, default OFF. There is no global master toggle (open question). Text is always cfg.name.
2. Placement shares the handle's geometry. Add an Anchors.StripPoints(cfg) helper that returns away, toward, yOff, growH, growV. Both placeHandle and a new Anchors.PlaceLabel use it. The label host is a plain frame, one element wide and STRIP_H tall, in the handle's exact spot, plus label.x/label.y offsets. The FontString is justified toward the growth start and has word wrap off.
3. Lock behavior. The label shows while locked. While unlocked it hides, and the handle shows the same name in the same spot. CORRECTION: this applies only when a handle actually exists. On a degraded install without LibKa0s-Widgets, BuildHandle returns nil (Anchors.lua:414), so there is nothing to take the label's place. In that case the label must stay shown while unlocked. The rule becomes: show = show and label.show and (locked or no handle).
4. When auras are present, the label always shows. It sits outside the anchor, so it never covers the container's own auras. "Hide while empty" is infeasible because engine contents and geometry are secret (Anchors.lua:5-9, and ARCHITECTURE: the addon reads no aura).
5. Visibility follows the show ladder. The host is a child of container.anchor, so it inherits scale, alpha (container x Master) and the stand-down anchor hide. SetShown is decided in ContainerClass:ApplyVisibility (Container.lua:493-516), the same pass as the handle and outline, and is combat-legal because it is our own non-secure child, as the handle already is. SetPoint, SetSize and SetFont run only in Apply, which MustDefer keeps out of lockdown and secrecy. The one exception is a first show under lockdown, which places the label once, mirroring UpdateHandle's `not handle.placed` rule.
6. Taint and secret safety. Use a plain frame (never BackdropTemplate), EnableMouse(false), no size reads, and width from the stored element size.
7. Settings. A fifth Layout tab, "Name label": Show, X offset, Y offset, then the composed H.FontGroup (6 rows). That makes 9 rows, taking Layout from 26 to 35 and the schema from 242 to 251. CORRECTION: FontGroup's emit() (libs/LibKa0s/OptionsCompose.lua:156-175) sets only path/page/group/subgroup/order. disabledIf is honored if we post-process the returned rows before RegisterSchemaRows, the same way settings/Bars.lua:109-111 post-processes a tooltip. So the font rows CAN be disabled while Show is off.
8. Apply routing. Label rows carry no `effect`, so a write falls through to CM.RequestApply(containerId) (ContainerManager.lua:577-584). That is a full container Apply, deferred in combat, and it is correct: the label restyle is done inside Apply. The rename row has effect 'none', so NotifyRenamed must refresh the text itself.
9. Font defaults: Friz Quadrata TT 12, gold {1,0.82,0,1}, OUTLINE, no shadow, class color off. CORRECTION on class color: Style.Color reads the module-local dressClass, which is set only inside Style.Element and nil'd right after it (Style.lua:778-780). Calling Style.ApplyFont outside Element therefore resolves useClassColorFont to the PLAYER's class (NS.ResolveColor(stored, useClass, "player")). ApplyFont needs an explicit classColor argument, or a Style.ColorWith(classColor, stored, useClass) helper that Style.Color delegates to. Style.UsesClassColor (Style.lua:90-100) is what sets self.usesClass in SnapshotClass (Container.lua:166). It must also count cfg.label.font.useClassColorFont when label.show is on, or a unit swap never re-applies.

MIGRATION: none. `label` is an added CONTAINER_TEMPLATE key, which PrepareProfile backfills. There is no SCHEMA_VERSION bump.

### Evidence

- modules/Anchors.lua:390-395 handleText returns cfg.name (+TEST tag): the handle already shows the name the label will show
- modules/Anchors.lua:466-478 placeHandle: SetPoint(away, anchor, toward, 0, +/-DRAG.GAP) using NS.Container.Growth(Anchors.EffectiveLayout(cfg)); the geometry to share
- modules/Anchors.lua:324 `local DRAG = KW and KW.DRAG_HANDLE` (nil without LibKa0s-Widgets); :413-414 BuildHandle returns nil without KW, so no handle exists on a degraded install
- modules/Anchors.lua:514-526 UpdateHandle: placement only out of lockdown; show/hide in combat; first-time placement allowed under lockdown
- modules/Container.lua:493-516 ApplyVisibility: `unlocked = show and p and not p.locked`; outline and handle decided here, so the label's SetShown belongs here
- modules/Container.lua:457-483 ApplyOutline: the lazy plain-frame child pattern to copy
- modules/Container.lua:527-545 Park/Destroy hide the outline and handle by hand; the label must be added
- modules/Container.lua:350-393 Apply: SnapshotClass(cfg) at :366, before which no class-colored dress may run; ApplyVisibility at :390. ApplyLabel goes between them, outside the HasAuraContainer branch
- modules/Container.lua:162-166 SnapshotClass sets self.classColor and self.usesClass = tracked and Style.UsesClassColor(cfg)
- modules/Style.lua:58-65 Style.Color uses dressClass; :778-780 dressClass is set and cleared around Style.Element only
- modules/Style.lua:90-100 UsesClassColor scans only the active style block
- modules/Style.lua:113-127 Style.ApplyFont(fs, t, tdef): the six-leaf font painter, with no classColor parameter today
- modules/ContainerManager.lua:466-471 NotifyRenamed refreshes only shown handles; the label text must be refreshed here
- modules/ContainerManager.lua:572-584 CONFIG_CHANGED: rows with no effect -> CM.RequestApply(containerId)
- modules/ContainerManager.lua:489 CM.COPY_SECTIONS; COPY_ALL built from it at :493-497
- settings/Schema.lua:603-613 SECTIONS whole-section map
- settings/Containers.lua:153-157 SECTION_KEYS / SECTION_LABELS, rendered through L[] at :182
- settings/Layout.lua:29 G_FRAME..G_MOUSE declare the tab order; :70 `structural` onChange = panel refresh only
- libs/LibKa0s/OptionsCompose.lua:156-175 emit() does not carry disabledIf; :317-343 FontGroup rows and defaults (Friz 12 OUTLINE)
- settings/Bars.lua:109-111 precedent for post-processing composed rows before RegisterSchemaRows
- tests/test_pages_layout.lua:97-102 pins the tab list; tests/test_pages_tabs.lua:52 ALSO pins 'Frame=Frame | Anchor=Anchor | Growth=Growth | Mouse=Mouse' (missed by the first pass)
- docs/ARCHITECTURE.md:79 '242 rows ... Layout 26'; docs/settings-panel.md:4 and :518 carry the same counts
- KickCD modules/UnitLabel.lua:146-155 holder reparented to the grid; KickCD modules/IconGrid.lua:675-691 anchorHandle puts the strip above the label (stacked)

### Files

- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/defaults/Profile.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Container.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Anchors.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Style.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/ContainerManager.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/settings/Layout.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/settings/Containers.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/settings/Schema.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/locales/enUS.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_container.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_anchors.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_pages_layout.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_pages_tabs.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_pages_containers.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_containermanager.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_style.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_schema.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_database.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_defaults.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/schema.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/settings-panel.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/ARCHITECTURE.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/module-map.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/smoke-tests.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/README.md

### Implementation sketch

1) defaults/Profile.lua, in NS.CONTAINER_TEMPLATE after `behavior`, add:
   label = { show = false, x = 0, y = 0, font = <font(12) with fontColor = color(1, 0.82, 0, 1), fontFlags "OUTLINE", fontShadow false, useClassColorFont false> }
   Add a comment saying the text is always cfg.name and the label is off by default. STARTER_CONTAINERS are untouched.

2) modules/Anchors.lua.
   (a) Fallback constants: `local STRIP_H = DRAG and DRAG.HEIGHT or 18; local STRIP_GAP = DRAG and DRAG.GAP or 2`.
   (b) `function Anchors.StripPoints(cfg)`: get growH, growV from NS.Container.Growth(Anchors.EffectiveLayout(cfg) or {}); toward = AnchorPoint(growH, growV); away = AnchorPoint(growH, flip(growV)); yOff = growV == "down" and STRIP_GAP or -STRIP_GAP; return away, toward, yOff, growH, growV. placeHandle calls it, with identical behavior.
   (c) `function Anchors.PlaceLabel(container, cfg)`:
       - host = container.label, fs = container.labelText; lc = cfg.label.
       - host:SetFrameLevel(levelOf(container.anchor, cfg) + 1).
       - host:ClearAllPoints(); host:SetPoint(away, container.anchor, toward, (tonumber(lc.x) or 0), yOff + (tonumber(lc.y) or 0)).
       - host:SetSize(NS.Style.ElementSize(cfg), STRIP_H).
       - fs:ClearAllPoints(); for growH "left": fs:SetPoint("RIGHT", host, "RIGHT", -4, 0) and SetJustifyH("RIGHT"); otherwise LEFT at +4 and SetJustifyH("LEFT"). fs:SetWordWrap(false).
       - host.placed = true.

3) modules/Style.lua.
   - `function Style.ColorWith(classColor, stored, useClass)`: when useClass and classColor, use the classColor branch (falling back to the swatch when classColor.r == nil); otherwise NS.ResolveColor(stored, useClass, "player"). Style.Color becomes `return Style.ColorWith(dressClass, stored, useClass)`.
   - Style.ApplyFont(fs, t, tdef, classColor): when classColor ~= nil use ColorWith(classColor, ...), else Style.Color(...). Existing callers are unchanged.
   - Style.UsesClassColor(cfg): add an early `local lb = cfg.label; if lb and lb.show and lb.font and lb.font.useClassColorFont then return true end`, allocation-free.

4) modules/Container.lua.
   - ContainerClass:ApplyLabel(cfg). It is called in Apply after SnapshotClass and before ApplyVisibility, outside the HasAuraContainer branch, so it also works on a client without the engine. If not (cfg.label and cfg.label.show), return. Otherwise build lazily: host = CreateFrame("Frame", nil, self.anchor); host:EnableMouse(false); fs = host:CreateFontString(nil, "OVERLAY"); self.label, self.labelText = host, fs. Then NS.Style.ApplyFont(fs, cfg.label.font, D.label.font, self.classColor or false), where passing false still selects the explicit path so the player class is not assumed for tracked NPC units. Then fs:SetText(tostring(cfg.name or "")) and NS.Anchors.PlaceLabel(self, cfg).
   - In ApplyVisibility, after the `unlocked` line:
     `local lab = cfg and cfg.label; self:ApplyLabelShown(cfg, (show and lab and lab.show and (not unlocked or not self.handle)) and true or false)`
   - ContainerClass:ApplyLabelShown(cfg, on): if there is no self.label, return. If on and not self.label.placed (only possible when it was never placed), call PlaceLabel. Then self.label:SetShown(on). It is allocation-free.
   - ContainerClass:RefreshLabelText(): if self.labelText then SetText(tostring(cfg.name or "")) end.
   - Park and Destroy: `if self.label then self.label:Hide() end`.

5) modules/ContainerManager.lua.
   - In CM.NotifyRenamed's loop, add `inst:RefreshLabelText()` for every instance.
   - CM.COPY_SECTIONS gains "label"; COPY_ALL follows automatically.

6) settings/Schema.lua: SECTIONS["container.label"] = "layout".

7) settings/Containers.lua: SECTION_KEYS gains "label" (after "behavior"); SECTION_LABELS.label = "Name label" (already rendered through L[] at :182).

8) settings/Layout.lua.
   - `local G_LABEL = L["Name label"]`, first used after the G_MOUSE rows so it becomes the fifth tab.
   - `local function labelOff() local c = NS.ActiveContainer(); return not (c and c.label and c.label.show) end`.
   - Rows:
     container.label.show (bool, L["Show name label"], desc as below);
     container.label.x and container.label.y (number, -200..200, step 1, L["X offset"] / L["Y offset"], disabledIf = labelOff).
   - `local fontRows = H.FontGroup({ prefix = "container.label.font.", page = PAGE, group = G_LABEL, subgroup = L["Font"], classColor = { source = "unit" } })`; set each row's disabledIf = labelOff; NS.RegisterSchemaRows(fontRows). Use the same classColor spec as Bars.lua's UNIT constant.
   - Update the header diagram.

9) locales/enUS.lua, ASCII-only, key == value:
   - "Name label"
   - "Show name label"
   - "Show this container's name where its drag handle sits, even while locked. It sits outside the container, on the side its auras do not grow into. While unlocked, the drag handle takes its place."
   - "Move the name label left or right, in pixels."
   - "Move the name label up or down, in pixels."
   "X offset", "Y offset" and "Font" already exist.

10) Docs:
   - schema.md: the label block.
   - settings-panel.md: :4 and :518 counts to 251 / 35, the Name label tab, and the Copy list.
   - ARCHITECTURE.md:79: 251, Layout 35.
   - module-map.md: Container, Anchors and Style rows.
   - smoke-tests.md: new rows.
   - README: a feature line.

### Tests

- test_defaults.lua: CONTAINER_TEMPLATE.label == { show=false, x=0, y=0, font = six canonical leaves, Friz 12, gold, OUTLINE, no shadow, class off }; every STARTER_CONTAINER backfills label.show == false
- test_database.lua: a stored container missing `label` gains the whole block on PrepareProfile; a stored label.show=true and custom fontColor survive the backfill; NS.SCHEMA_VERSION unchanged
- test_container.lua: label.show false -> inst.label == nil after Apply (never built)
- test_container.lua: label.show true + locked -> label shown, text == cfg.name, font set; flipping label.show to false and applying hides it
- test_container.lua: label.show true + unlocked with a handle -> label hidden, handle shown (red under: both drawn)
- test_container.lua (degraded_env, no LibKa0s-Widgets): label.show true + unlocked -> label STAYS shown because there is no handle; placement uses the fallback 18/2 constants
- test_container.lua: test mode while locked still shows the label; visibility 'never' hides it; cfg.enabled=false hides it; stand-down hides the anchor and stand-up restores it
- test_container.lua: Park() and Destroy() hide the label
- test_container.lua: ApplyVisibility under mocked InCombatLockdown records no SetPoint/SetSize on an already-placed host; a never-placed host is placed exactly once on first show
- test_container.lua: the host is a plain frame (no SetBackdrop / BackdropTemplate), EnableMouse(false), and survives a secret anchor size (reuse the border_strips / secret-size harness from the outline test)
- test_anchors.lua: Anchors.StripPoints matches placeHandle's recorded SetPoint for down+right, down+left, up+right, up+left; the label host SetPoint equals the handle's plus label.x/label.y; fs justified LEFT for growH right and RIGHT for growH left; a follower (attach.mode container) uses its root's growth
- test_containermanager.lua: SetByPath('container.name','Foo',id) updates labelText with no apply queued, also under mocked lockdown; CopyFrom(src,dst,'label') copies label and not name; CopyFrom with nil section includes label
- test_schema.lua: NS.IsSection('container.label') is true; a whole-section write announces 'layout'; every container.label.* row resolves
- test_style.lua: UsesClassColor true when only label.show and label.font.useClassColorFont are on, false when label.show is off; ApplyFont with an explicit classColor paints that class; classColor.r == nil falls back to the swatch; Style.Color behaves the same as before (regression)
- test_pages_layout.lua: tab order Frame, Anchor, Growth, Mouse, Name label (update :97-102); the Name label rows write the SELECTED container's label.*; the offset AND font rows are disabled while Show name label is off
- test_pages_tabs.lua:52: update the Layout tab signature to include Name label=Name label
- test_pages_containers.lua: the Copy settings 'what' dropdown lists Name label
- test_docs.lua / test_locale.lua: run automatically; count claims (251 / 35) and new L keys must pass
- test_perf.lua: the visibility pass with a label built stays allocation-free, if such a guard exists

### Smoke

- Layout -> Name label: tick Show name label on 'Player buffs' while locked. The gold name appears just above the first element (growth down), left-aligned, and nothing else moves.
- /am unlock: the label hides and the drag handle shows in the same spot with the same name. /am lock: the label returns.
- Grow vertically = Up: the label moves below the first element. Grow horizontally = Left: the label right-aligns.
- X/Y offsets and each font leaf (face, size, flags, shadow, color) apply live out of combat. With Show off, the offset and font rows are greyed.
- Visibility 'Out of combat only': entering combat hides the container and label together, and they return after combat. No ADDON_ACTION_BLOCKED; taint log clean.
- Rename a container in combat: the label text changes immediately.
- Target container with the label font's class color on: target a warrior, then a mage. The color follows (after combat if the swap happened in combat). An NPC target falls back to the swatch.
- /am test while locked: placeholders and the label, not overlapping. While unlocked: the handle with the TEST tag, and no label.
- A follower (attached to another container) with the label on: check for overlap with the parent's last line; the offsets fix it.
- Scale 2.0 and Opacity 0.5, plus Master alpha: the label scales and fades with the container.
- /am disable hides the label; /am enable restores it. Deleting the container removes the label.
- Copy settings from, What = Name label: the label settings are copied and the name is untouched.
- A container flush with the top screen edge with its label above it: note whether the label is clipped (it is not clamped).

Needs migration: False

### Risks

- CHANGES FROM THE FIRST PASS: (1) Unlocked-hide rule changed to `locked OR no handle`. BuildHandle returns nil without LibKa0s-Widgets (Anchors.lua:414), so the first pass would have left a degraded install with no name at all while unlocked. (2) Added tests/test_pages_tabs.lua:52 (also pins the Layout tab list) and test_pages_containers.lua (Copy dropdown) to files and tests. (3) FontGroup's emit() does not propagate disabledIf, but post-processing the returned rows (the Bars.lua:109-111 precedent) makes the font rows disable-able, so the 'leave font rows live' fallback is not needed. (4) Stated precisely why class color breaks outside Style.Element: dressClass is cleared at Style.lua:780, so ApplyFont there resolves the PLAYER class. ApplyLabel must also run after SnapshotClass (Container.lua:366) and outside the HasAuraContainer branch. (5) StripPoints' signature was unified to (cfg); the first pass listed both (container, cfg) and (cfg). (6) Noted that label rows route through the default CONFIG_CHANGED -> RequestApply path (a full, combat-deferred container Apply), which is correct but means label edits made in combat wait for combat to end.
- Followers: a container attached to another faces its 'away' side toward the parent, so its label can overlap the parent's last line. The handle has the same geometry today. It is off by default and has offsets; consider noting it in known-limitations.
- Screen-edge clamp covers the strip only while unlocked (clampToHandle). A locked label outside the anchor can sit partly off-screen when the container is flush with an edge. Clamping it would shift the container when the label is toggled, so it is left unclamped and documented.
- The rename path has effect 'none'. Without RefreshLabelText in CM.NotifyRenamed, the label keeps the stale name until an unrelated apply.
- Combat: PlaceLabel (SetPoint/SetSize/SetFont) must never move into ApplyVisibility beyond the one-time first placement. That would be layout work beside the engine's parent in combat (events-frames-taint-§2).
- Count and doc drift: the schema goes 242 -> 251 and Layout 26 -> 35 in ARCHITECTURE.md:79, settings-panel.md:4 and :518, and README. test_docs and sync-docs will flag misses.
- Long names (maxLetters 40) at size 12 overflow a small icon's width toward the growth side. Acceptable because word wrap is off. The host is one element wide; the FontString is single-point anchored and not clipped.
- Style.ApplyFont signature change: existing callers pass 3 args, so the new 4th arg must be optional and the old path must be byte-identical (covered by the Style.Color regression test).

### Open questions (as raised)

- While UNLOCKED: hide the label and let the drag handle (which shows the same name) take its spot, which is recommended and is the literal 'in place of'? Or show both, with the handle pushed further out past the label as KickCD does?
- Per-container only (recommended), or also a profile-wide 'Show name labels on every container' toggle on General?
- Text is always the container name. Do you also want KickCD's free-text override (label.text, falling back to the name when empty)?
- Default look: gold Friz 12 OUTLINE (matches the handle and KickCD), or white / smaller?
- Do you accept 'always shown regardless of auras'? Hiding the label only while the container is empty is impossible, because engine contents are secret and the addon reads no auras.
- Are X/Y offsets from the handle's spot enough, or do you want KickCD's full point / relative point / justify / rotation set (about 4-5 more rows)?

## Item 9: ITEM 9 (bug): when unlocked and not in test mode, empty containers overlap. A container attached to another hangs from that container's empty aura engine, so an attached chain collapses into about 5px steps.

### Root cause / design

ROOT CAUSE (confirmed; it matches the screenshot geometry).

The anchor never collapses. Anchors.Place always sizes a container's anchor to exactly one element (modules/Anchors.lua:218-219, Style.ElementSize).

What collapses is the frame an ATTACHED container hangs from. targetFor (modules/Anchors.lua:81-87) returns `(target.previewShown and target.previewExtent) or target.engine or target.anchor`. So outside test mode a follower is SetPoint'ed to its parent's aura ENGINE, with the DerivedPoints (Anchors.lua:160-173): TOPLEFT to BOTTOMLEFT for the default vertical, down-growing flow.

The engine is pinned at the anchor's start corner (Container.lua:226-227) with a provisional SetSize(1,1) (Container.lua:228-231). Only a layout pass over real auras gives it any other size. With no auras, the child's top therefore lands at parent-top - 1 + at.y (-4, defaults/Profile.lua:162-165), about 5px below the parent's top. Every link of a chain repeats that.

Screenshot 11 shows exactly this. The "Text (Defensive Cooldowns)" and "Text (Raid Cooldowns)" handle strips are stacked about 5-7px apart, and the outlines' edges are piled up at about 5px spacing. Two screen containers could not produce it: newContainerData staggers new screen containers 30px apart (ContainerManager.lua:406-409), and Duplicate staggers its copy 20px down and 20px right (:480-483).

The unlocked OUTLINE (ContainerClass:ApplyOutline, Container.lua:466-482) is already the owner's "single white-border placeholder". It is one element, at Preview.Offset(cfg,1)'s corner of the anchor, the same size as the anchor, so its rect IS the anchor's rect. But nothing hangs from it. And Anchors.PlaceAttached (Anchors.lua:244-259) memoizes only on `previewShown`, so lock and unlock never re-target followers.

DESIGN (corrected: simpler than the earlier proposal). While a container is unlocked and not previewing, its followers hang from its ANCHOR. The anchor is already exactly one element at the flow's start corner, which is the outline's rect. There is no new frame and no new Preview.Extent(1) call. Preview.Extent needs no memo, and there is no extra lockdown path, because the anchor is placed only by Anchors.Place, which already never runs under lockdown.

The hang target becomes a three-state mode per container, recorded in ApplyVisibility as `self.hangMode`:
- "preview" (test mode): the previewExtent (L-4, unchanged).
- "slot" (unlocked, shown, not previewing): the target's anchor.
- "engine" (everything else, i.e. locked): the engine, so smoke check 41's grow/shrink follow is unchanged.

PlaceAttached memoizes on that string instead of the boolean.

Second part, needed for the result not to still read as overlap. Place a vertical follower one handle-reach further along its growth while its parent's handles show (hangMode "slot" or "preview"). The follower's drag strip is DRAG.HEIGHT 18 + GAP 2 (libs/LibKa0s/WidgetsDragHandle.lua:106-107), placed on the side away from growth, i.e. toward the parent (placeHandle, Anchors.lua:462-476). Without the reach, with the default Text size 220x16 and at.y -4, the child's strip spans exactly the parent's one-slot outline (parent top-18 .. parent top). The owner would see two handle strips back to back and no parent outline.

No schema change, no new setting, no DB migration.

### Evidence

- modules/Anchors.lua:81-87 targetFor: `return (target.previewShown and target.previewExtent) or target.engine or target.anchor, "container"`. Outside test mode the follower hangs from the engine, whether locked or unlocked.
- modules/Container.lua:224-231 Build: `engine:SetPoint(flow.anchorPoint, anchor, flow.anchorPoint, 0, 0)` then a provisional `engine:SetSize(1, 1)`. Only a layout pass over real auras resizes it, so with no auras the rect is about 1px at the start corner.
- modules/Anchors.lua:160-173 DerivedPoints (vertical, down: TOPLEFT to BOTTOMLEFT) and defaults/Profile.lua:162-165 attach.y = -4. Each child's top sits about 5px under its parent's top, which matches the about 5px steps between the stacked strips and outline edges in screenshot 11.
- modules/ContainerManager.lua:406-409 staggers new screen containers 30px apart (`c.position.y = -((id - 1) % 8) * 30`), and :480-483 staggers a duplicate 20px down and 20px right. Two screen containers therefore would not stack about 5px apart, so the screenshot is an attached chain.
- modules/Anchors.lua:218-219 Place: `anchor:SetSize(w, h)` from Style.ElementSize, so the anchor is always one element. modules/Container.lua:478-481 ApplyOutline puts the outline at `Preview.Offset(cfg,1)`'s point of the anchor, at the same size: the outline's rect equals the anchor's rect.
- modules/Preview.lua:175-189 Preview.Extent with count=1 gives farX=farY=0, i.e. the same corner and ElementSize. Hanging from target.anchor is geometrically identical and needs no new frame placement.
- modules/Anchors.lua:244-259 PlaceAttached: `local previewing = target.previewShown == true; if target.attachedPlacedFor == previewing or InCombatLockdown() then return end`. Lock and unlock never re-place followers.
- modules/Container.lua:494-515 ApplyVisibility: Preview.Show/Hide, then ApplyOutline(cfg, unlocked and not previewing) at :510, then UpdateHandle, then PlaceAttached at :513. This is the hook point. settings/General.lua:74 maps `locked` to the "visibility" effect, so lock and unlock drive CM.ApplyVisibility (ContainerManager.lua:580).
- modules/Anchors.lua:462-476 placeHandle: strip at `away` point with DRAG.GAP offset, i.e. above a down-growing anchor, toward its parent. libs/LibKa0s/WidgetsDragHandle.lua:106-107 HEIGHT 18, GAP 2. The child strip covers the parent's 16px outline when at.y is -4.
- modules/Anchors.lua:452-460 handleLevel already raises a follower's strip above its parent's anchor level, so the stacking level needs no change.
- tests/test_anchors.lua:1133-1199 previewPair unlocks (`locked`=false). The tests at :1167-1183 (`lastTarget(rec) == one.engine` after test mode off) and :1185-1199 (`combat over: onto the engine`) run UNLOCKED and will turn red under the fix. They must be re-scoped. defaults/Profile.lua:40 `locked = true`, so the locked-state tests at :643-664 and :1099-1124 stay valid.

### Files

- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Anchors.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Container.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_anchors.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_container.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/known-limitations.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/data-flow.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/module-map.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/smoke-tests.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/test-cases.md

### Implementation sketch

1. modules/Container.lua, ApplyVisibility (:509-513). Record the hang mode before PlaceAttached:
```lua
local unlocked = (show and p and not p.locked) and true or false
self:ApplyOutline(cfg, unlocked and not previewing)
NS.Anchors.UpdateHandle(self, unlocked)
-- What a container attached to this one hangs from: the placeholder block in test mode (L-4),
-- the one-element anchor the outline marks while unlocked (item 9), else the engine.
self.hangMode = (show and previewing and cfg) and "preview" or ((unlocked and cfg) and "slot") or "engine"
NS.Anchors.PlaceAttached(self)
```
Park and Destroy set `self.hangMode = "engine"`. This is harmless: PlaceAttached never runs under lockdown, and the next pass re-evaluates.

2. modules/Anchors.lua, targetFor (:81-87):
```lua
if target then
    local mode = Anchors.HangMode(target)
    if mode == "preview" and target.previewExtent then return target.previewExtent, "container" end
    if mode == "slot" then return target.anchor, "container" end   -- = the outline's rect (item 9)
    return target.engine or target.anchor, "container"
end
```
Add a small local/exported helper:
```lua
function Anchors.HangMode(t)
    return t.hangMode or (t.previewShown and "preview") or "engine"
end
```
The fallback covers instances that have not had a visibility pass yet.

3. PlaceAttached (:244-259):
```lua
local mode = Anchors.HangMode(target)
if target.attachedPlacedFor == mode or InCombatLockdown() then return end
target.attachedPlacedFor = mode
```
Update its doc comment to cite item 9 beside L-4.

4. Handle reach. In Anchors.Place, when `mode == "container"` and the target's HangMode is "slot" or "preview", add the handle reach along the follower's effective growth on a vertical axis only:
```lua
local reach = handleReach()   -- DRAG and DRAG.HEIGHT + DRAG.GAP or 0
local L = Anchors.EffectiveLayout(cfg) or {}
if L.axis == "vertical" then
    y = y + ((L.growV == "up") and reach or -reach)
end
```
DRAG is already resolved in this file for placeHandle and clampToHandle, so reuse it. The stored at.y is untouched; the offset is display-only. Horizontal chains get no reach (the strip is above or below, not toward the parent). Whether "preview" also gets it is the second open question. The default recommendation is yes, because the handles show in both modes.

5. No schema keys, no locale strings, no migration.

Docs:
- data-flow.md "Where a container sits": the three-state hang target.
- known-limitations.md: while unlocked, a follower sits one slot plus a handle reach past its parent, so the parent's 2nd+ live auras draw under it until lock. Followers shift on lock and unlock.
- module-map.md: the Container instance field `hangMode`, and Anchors.HangMode.
- smoke-tests.md: amend check 14's attached paragraph and check 41, and add a new check for unlocked empty chains.
- test-cases.md: the new rows.

### Tests

- test_anchors (new, red first): 'unlocked, not in test mode, an attached container hangs from its parent's one-element anchor, not its empty engine (item 9)'. fresh(); attach 2 to 1; SetByPath locked false; fireTimers. Assert lastTarget(recordAnchor(two) after Place) == one.anchor, points TOPLEFT/BOTTOMLEFT. Red under the current targetFor, which answers one.engine.
- test_anchors: 'a chain 3->2->1 unlocked: 3 hangs from 2's anchor, 2 from 1's'.
- test_anchors: 'locking re-anchors followers onto the parent's engine; unlocking puts them back on its anchor; a visibility pass that changes nothing re-places nothing' (assert #rec.points unchanged after CM.ApplyVisibility()).
- test_anchors: 'unlocked, turning test mode off moves followers from the preview extent to the parent's anchor (preview to slot); turning it on returns them to the extent'.
- test_anchors: 'under lockdown a lock or unlock leaves a follower where it is; the pass after PLAYER_REGEN_ENABLED moves it'.
- test_anchors: 'unlocked, a vertical follower is offset by DRAG.HEIGHT+DRAG.GAP along its growth (down: y = at.y - 20; parent growing up: y = at.y + 20); a horizontal follower gets its stored offsets unchanged; locked, the stored offsets only'.
- UPDATE the existing test_anchors.lua:1167-1183: previewPair is unlocked, so test mode off now lands on one.anchor (slot), not one.engine. Either assert one.anchor, or SetByPath locked true, fireTimers and assert one.engine. Better, cover both.
- UPDATE the existing test_anchors.lua:1185-1199 (lockdown L-4): after combat the unlocked follower goes to one.anchor. Adjust the assertion.
- test_container: 'ApplyVisibility records hangMode preview / slot / engine for test mode, unlocked, and locked', and Park and Destroy reset it to engine.

### Smoke

- Chain three Text containers (B attached to A, C attached to B), none with a matching aura. /am unlock with test mode off. Each faint outline sits in its own slot below the previous one, each handle strip sits just above its own outline, and no strip covers another container's outline.
- Same chain, /am lock. Nothing shows (empty), and there is no Lua error. Give A real auras while locked: B starts right past A's last aura (check 41 unchanged).
- Unlocked, give A two or more real auras. Expected (documented limitation): B stays one slot past A's first element, so A's extra auras draw under B until lock. On lock, B jumps past A's last aura.
- Unlocked, then /am test. B's placeholders start past A's placeholder block (L-4). /am test off while still unlocked: B moves back to A's one slot, with no error.
- Drag A while unlocked. B and C follow. /reload: positions persist and the chain re-forms.
- Icons row chain (horizontal). B's outline sits one icon plus spacing to the right of A's. Note whether A's handle label, wider than an icon, overlaps B's strip.
- Enter combat while unlocked and /am lock during combat. Nothing re-anchors in combat, and there is no ADDON_ACTION_BLOCKED or taint. Leaving combat snaps followers onto the engines.
- Grow-up vertical chain: B sits above A, and its strip lies below B, clear of A's outline.

Needs migration: False

### Risks

- CHANGED vs the prior finding: the slot target is the parent's existing ANCHOR (the same rect as the outline and as Preview.Extent(c,1)) instead of a re-sized previewExtent. This removes the Preview.Extent memo work, the extra layout per visibility pass, and a second lockdown path for the extent, and it drops Preview.lua/test_preview.lua from the change set.
- CHANGED: the prior finding did not notice that the existing tests test_anchors.lua:1167-1183 and :1185-1199 run UNLOCKED (previewPair sets locked=false) and assert the engine target after test mode ends. They will go red and must be re-scoped. Added to tests.
- CHANGED: the handle reach is promoted from optional to part of the recommended fix. Without it, the default Text follower's 18+2px strip lies exactly over the parent's 16px outline, and the owner would still read that as overlap. It is implemented as a display-only offset in Anchors.Place (vertical axis only), not by resizing an extent.
- CHANGED: the screen-container alternative is resolved. ContainerManager.lua:406-409 staggers new containers 30px apart and Duplicate staggers its copy 20px down and right, so the about 5px stacking in screenshot 11 can only come from an attached chain.
- While unlocked, a follower no longer tracks its parent's LIVE aura count. A parent with 2+ real auras has them drawn under its follower until lock. max(slot, live extent) is not achievable: engine geometry can read secret, and re-anchoring on count changes is layout work that is illegal under lockdown. This is an owner decision.
- Followers visibly shift on lock and unlock (engine vs slot), as test mode already shifts them. Document it in known-limitations.md.
- The PlaceAttached memo changes from a boolean to a string. Only Anchors.lua reads attachedPlacedFor (grep confirms).
- Anchoring a follower's anchor to the parent's anchor is an existing fallback path in targetFor (used when there is no engine), so it adds no new taint surface. Still smoke it around combat.

### Open questions (as raised)

- While unlocked, should a follower always sit one slot past its parent (predictable; recommended), accepting that the parent's extra live auras run under it until lock?
- Should the handle reach (18+2px on vertical chains) also apply in test mode (L-4), for consistency? The recommendation is yes, since the handles show in both modes, but it changes today's test-mode layout slightly.

## Item 10: ITEM 10 (bug): icon border shape changes when "Color the border by dispel type" is on

### Root cause / design

WHICH IMAGE IS WHICH: 24.png is the Border tab with the dispel toggle ON, and 25.png shows the icons in that state. 26.png is the tab with the toggle OFF, and 27.png shows those icons. I re-viewed 25 and 27. In 25 the second aura (the red-flame Magic debuff) is framed by a blue ring with rounded, beveled corners. The ring sits outside the icon and reaches into the gap next to its neighbours, while every other icon keeps the square 1 px black Solid border. In 27 the same aura (now first) has the plain square border like the rest. The first agent's reading is correct.

ROOT CAUSE (confirmed): the two states draw two different kinds of border.
- Toggle OFF: our Solid border is four flat strips, square and exactly `borderSize` thick, anchored to the frame corners. See BORDER_STRIPS and drawStrips at modules/Style.lua:318-379, called through Style.ApplyBorder at :442-455 from Icons.Apply (modules/Style_Icons.lua:132-133).
- Toggle ON: Icons.Bind (modules/Style_Icons.lua:160-169) binds a separate texture, `am.dispel`, with `style = Compat.DispelStyle("Border")`. For that style the engine calls `AuraUtil.SetAuraBorderAtlas(texture, dispelName, false)`, which sets Blizzard's per-type `ui-debuff-border-<type>-noicon` atlas with IgnoreAtlasSize (docs/superpowers/research/2026-09-13-aura-engine-notes.md:196-199, 257-260). That atlas is beveled debuff-frame art: a ring inside transparent padding.
- layoutDispel (modules/Style_Icons.lua:93-106, DISPEL_ART_DIVISOR = 6) then stretches the atlas a sixth of the icon past each edge, anchored to am.icon, so the ring lands near the icon's edge. On a roughly 26 px icon that is about 4 px of outset, into the icon spacing.
- The texture lives on am.dispelHost, one frame level above am.border (Style_Icons.lua:42-44, 61-64). It is drawn on top of our strips; it does not replace them in the same shape.
- The ring's apparent thickness comes from the art and the icon size. The user's Border thickness has no effect on it.
- The owner decided on 2026-09-13 to keep the stock art, and that decision is what introduced the mismatched shape.

DESIGN (corrected): draw the dispel border as the same four-strip shape as our Solid border, with white textures, and let the engine only recolor them with style PreserveAsset.

The main correction to the first finding is the color source: pass NO customDispelColorMap. With PreserveAsset and no map, the engine calls `AuraUtil.SetAuraBorderColor(texture, dispelName)`, which does `SetVertexColor(AuraUtil.GetAuraBorderColor(dispelType))`. That is Blizzard's own per-type color taken straight from the client (engine notes :135-147, Blizzard_CustomAuraButton.lua:450-451). The custom map is then skipped, because GetCustomDispelTypeTextureColor returns nil (notes :406-408, 459-463). This:
- keeps the owner's "Blizzard's own colors" rule exactly, including Bleed and any future type;
- avoids copying the colors from C.DEFAULT_DISPEL_COLORS, which is our profile default and is not guaranteed to equal Blizzard's values (Bleed 0.8/0.1/0.1 in particular);
- keeps the existing locale strings true without rewording (enUS.lua:115, 124, 313);
- keeps the existing "no customDispelColorMap" test green.

The typeless and helpful rules are unchanged: showWhenHarmful = true, showWhenHelpful = false, and showWithoutDispelType = false (the default, now passed explicitly). The strips are hidden on typeless debuffs and on buffs, so our own border shows there.

The strips cover our border exactly, so a typed debuff shows a square edge of `borderSize` in Blizzard's type color, and nothing is drawn into the spacing. This is the same mechanism Text lines already use for their dispel edge (modules/Style_Text.lua:112-121, 339-351, 479-496), which works in-game.

No schema change, so no migration.

### Evidence

- modules/Style_Icons.lua:160-169: Icons.Bind binds am.dispel with style = Compat.DispelStyle("Border") (Blizzard's atlas art) and no color map
- docs/superpowers/research/2026-09-13-aura-engine-notes.md:196-199, 257-260: the Border style calls AuraUtil.SetAuraBorderAtlas, which sets ui-debuff-border-<type>-noicon with IgnoreAtlasSize (a beveled ring inside transparent padding)
- docs/superpowers/research/2026-09-13-aura-engine-notes.md:135-147: PreserveAsset keeps our asset and calls AuraUtil.SetAuraBorderColor(texture, dispelName), which is Blizzard's own per-type color, and :406-408/:459-463 show the custom map is applied only when one is passed. So PreserveAsset with no map equals Blizzard's colors on our own shape
- modules/Style_Icons.lua:93-106: DISPEL_ART_DIVISOR = 6. The atlas is outset by icon/6 per side, anchored to am.icon, into the icon spacing
- modules/Style_Icons.lua:42-44, 61-64: am.dispel sits on dispelHost, one frame level above am.border, so it draws over our border
- modules/Style.lua:318-379: the Solid border is four strips (BORDER_STRIPS), with the sides stopping a thickness short of each end and square corners. drawStrips paints with SetColorTexture and Show()s the strips
- modules/Style.lua:327-338 (borderStrips) and :342-346 (Style.NewBorder): a reusable builder for the same four strips on any plain frame
- modules/Style_Text.lua:112-121, 339-351, 479-496: the same pattern is already live for text lines: white strips, hidden every dress, bound with AddDispelTypeTexture + PreserveAsset
- core/Constants.lua:170-176: C.DEFAULT_DISPEL_COLORS is our profile default palette, not a verified copy of Blizzard's (Bleed 0.8,0.1,0.1), so routing icons through it would not strictly be 'Blizzard's own colors'
- tests/test_style_icons.lua:159-270 and tests/test_style.lua:187-192: the existing tests pin the Border style (31), am.dispel, the icon/6 outset, and a single AddDispelTypeTexture
- docs/smoke-tests.md:60, 61, 71 and docs/module-map.md:86 describe the Blizzard atlas art and the sixth-of-icon outset
- Screenshots: 25.png (toggle ON) shows a rounded, beveled blue ring round the 2nd aura, outset past the 1 px black squares; 27.png (toggle OFF) shows the same aura (1st) with the plain square border

### Files

- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Style_Icons.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Style.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_style_icons.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_style.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/smoke-tests.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/module-map.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/ARCHITECTURE.md

### Implementation sketch

1. modules/Style.lua: one layout, two painters.
- Split the layout loop out of drawStrips into `local function layStrips(frame, size)`. It uses borderStrips(frame) and, for each BORDER_STRIPS entry, calls ClearAllPoints, sets the two SetPoints (with the side offsets -size/+size), then calls SetHeight or SetWidth(size). It returns the strips.
- drawStrips calls layStrips, then SetColorTexture(r,g,b,a) and Show() on each strip. The Solid border's behavior is unchanged.
- Add `function Style.TintEdge(frame, size)`. It calls `local strips = layStrips(frame, size)`, then for each strip calls `SetTexture(C.WHITE_TEXTURE)`, `SetVertexColor(1,1,1,1)` and `Hide()`, and returns strips.
- Doc comment for Style.TintEdge: the four strips are the same shape as a Solid border, left white and hidden, for the engine to show and tint (PreserveAsset). They are hidden on every dress because the engine's Clear restores nothing (B-4).
- SetTexture(WHITE) is used, not SetColorTexture, to mirror the Text path that is proven in-game.

2. modules/Style_Icons.lua:
- In build: `am.dispelHost = Style.NewBorder(frame); am.dispelHost:SetAllPoints(frame)`, keeping level + 2. Then alias the strips onto their own keys so the style suites can see them: `local s = am.dispelHost.__amStrips; am.dispelTop, am.dispelBottom, am.dispelLeft, am.dispelRight = s[1], s[2], s[3], s[4]`, and add `local DISPEL_EDGES = { "dispelTop", "dispelBottom", "dispelLeft", "dispelRight" }` at file scope.
- Delete am.dispel, DISPEL_ART_DIVISOR and layoutDispel, and the layoutDispel call in Icons.Apply.
- In Icons.Apply, replace line 143 with an unconditional `Style.TintEdge(am.dispelHost, dispelSizeOf(ic))` on every dress. Every strip is then hidden before the bind (B-4 holds whether the option is on or off).
- `local function dispelSizeOf(ic) local s = borderSizeOf(ic); return (s and s > 0) and s or 1 end`. The minimum of 1 depends on the open question about a hidden border.
- In Icons.Bind, when dispelBorder is on: `local opts = dispelOptions(Compat)` and `for _, k in ipairs(DISPEL_EDGES) do Style.Bind(frame, "AddDispelTypeTexture", am[k], opts) end`.
- dispelOptions is memoized once per module (the options table holds no per-look data): `{ showWhenHarmful = true, showWhenHelpful = false, showWithoutDispelType = false, style = Compat.DispelStyle("PreserveAsset") }`. No customDispelColorMap, which means the engine's AuraUtil.SetAuraBorderColor gives Blizzard's own color.
- Build the memo lazily, because Compat.DispelStyle can be nil before Enum exists.
- Rewrite the header diagram comment (line 5), the comment at 37-41 and the comment at 161-164: the dispel border is our Solid shape on a frame above ours, tinted by the engine in Blizzard's own colors.

3. Settings and locales: no change. settings/Icons.lua:44-45 and enUS.lua:115, 124 and 313 stay accurate.

4. Docs:
- docs/module-map.md:86: "the dispel border: our strip shape on its own frame above ours (dispelHost), tinted by the engine in Blizzard's own colors".
- docs/smoke-tests.md: rewrite 60 ("shows a square edge in Blizzard's dispel color over yours"), 61 ("untinted Blizzard blue, the same shape as your border") and 71 (replace the sixth-of-icon outset check with a same-shape and same-thickness check).
- docs/ARCHITECTURE.md: update it if it describes the icon dispel art (grep shows no direct mention; confirm during sync-docs).

5. No schema or DB change, so no migration.

### Tests

- test_style_icons.lua: rewrite 'the dispel border is the engine's debuff art' as 'the dispel border is our four strips, tinted by the engine (PreserveAsset), on harmful auras only'. Assert 4 AddDispelTypeTexture calls whose arg[1] are am.dispelTop/Bottom/Left/Right, each with style == 32 (PreserveAsset in the mock enum), showWhenHarmful true, showWhenHelpful false and showWithoutDispelType false. It is red under the old Border (31) single binding.
- test_style_icons.lua: keep the G-3 test with its assertion updated. With db.profile.dispelColors.Magic set to red, every binding's opts.customDispelColorMap is nil and style is PreserveAsset. That means Blizzard's own colors through AuraUtil.SetAuraBorderColor. It is red under a map from the profile or from C.DEFAULT_DISPEL_COLORS.
- test_style_icons.lua: 'the dispel strips take our border's exact shape'. Use the tagged-texture environment already in the frame-level test (or the tests/border_strips.lua helper), with borderSize = 3 on a 32x32 icon. Each dispel strip's SetPoint anchors are the dispelHost corners with the side offsets -3/+3, plus SetHeight/SetWidth(3), identical to am.border's strips. This replaces the two 'reaches past the icon by a sixth' tests, and is red under the icon/6 outset anchored to am.icon.
- test_style_icons.lua: 'thickness follows Border thickness'. Re-dress with borderSize 1 then 4, and the strips re-lay at 4.
- test_style_icons.lua: update the frame-level test to use am.dispelTop.__owner (the dispelHost). It sits above am.border and below am.text, and is a child of the button.
- test_style_icons.lua: update the B-4 tests. With the option off, all four strips are hidden (Hide called on each) and AddDispelTypeTexture is called 0 times. On a live button with the engine recorder, turning the option off leaves all four hidden.
- test_style.lua (new): Style.TintEdge lays the same anchors as Style.DrawEdge and leaves the strips white, with vertex color 1,1,1,1, and hidden. DrawEdge's own geometry is unchanged, which guards the layStrips refactor.
- test_style.lua:187-192: change assertEqual(b:__count("AddDispelTypeTexture"), 1) to 4
- Run lua tests/run.lua, luacheck and tests/perf.lua (4 bindings per icon instead of 1)

### Smoke

- Target a mob carrying a Magic, Curse or Poison debuff plus a typeless one. Use Target Debuffs (All) as icons, with a Solid 1 px black border and the dispel toggle on. The typed icon shows a square 1 px edge in Blizzard's type color, in the same place and the same shape as its neighbours' black edge. No beveled corners and nothing drawn into the icon spacing.
- Border thickness 1, then 4, then 8: the colored edge always matches the black edge's thickness on typeless auras
- General -> Dispel Colors, set Magic to pure red: the icon's Magic edge stays Blizzard blue (the owner's 2026-09-13 rule)
- Toggle dispel on and off live, in and out of combat: the colored edge appears and disappears, and the black border shows again with no stale tint (B-4)
- Use class color on: typeless auras keep the class-colored border, and typed auras show the dispel color
- A bleed debuff: check the color Blizzard's AuraUtil gives it (it may be none, since Bleed may have no Blizzard border color) and report it
- Border style non-Solid (textured) with the dispel toggle on: the flat colored strip over the textured edge; report whether it is acceptable
- Show border off, or style None, with the dispel toggle on: a thin edge still shows over the icon art's outer pixels; report whether it is acceptable
- Helpful-aura container (player buffs) with the toggle on: no colored edge on buffs
- In-game perf run on a large raid-debuff icon container with the toggle on (4 tinted strips per icon)

Needs migration: False

### Risks

- CHANGED vs the first finding: the colors. The first finding passed customDispelColorMap = Style.DispelColorMap(C.DEFAULT_DISPEL_COLORS, ...). With PreserveAsset and no map, the engine already paints Blizzard's own color through AuraUtil.SetAuraBorderColor (notes :135-147). That is simpler and literally Blizzard's colors, whereas C.DEFAULT_DISPEL_COLORS is our profile default and is not verified against Blizzard (Bleed in particular). It also needs no memo work, no fallback color and no test churn on the G-3 test.
- CHANGED: construction. The first finding added a separate Style.LayEdgeStrips with caller-owned textures. This version reuses Style.NewBorder's strip builder and a shared layStrips, so the dispel strips and the Solid border cannot drift apart. The strips are also aliased to am.dispelTop/Bottom/Left/Right so the tests can see them.
- CHANGED: missed files. docs/smoke-tests.md entries 60, 61 and 71 and docs/module-map.md:86 describe the atlas art and the outset, and must be rewritten. No locale or settings change is needed.
- Behavior for an untyped harmful aura depends on showWithoutDispelType = false, which is now passed explicitly. If Blizzard's GetAuraBorderColor gives an unexpected color for a type such as Bleed, that shows only in-game.
- Four AddDispelTypeTexture bindings per icon instead of one: four tint and show passes per aura update. Text lines already do this, but confirm with tests/perf.lua and an in-game perf run.
- The engine permanently marks each bound strip's VertexColor aspect as secret (notes Q1 point 4). That is fine here, because we never read the strips' colors back and repaint them white with SetVertexColor on every dress, exactly as the Text path does.
- Non-Solid (backdrop) border styles: a flat colored strip over a textured edge is a different look again. The old atlas also mismatched these.
- With the border hidden (Show border off, or style None), the dispel edge covers the icon art's outer pixels, since the inset is 0. The old atlas overlapped the icon too.
- This drops Blizzard's beveled atlas art, which the owner kept on 2026-09-13. The colors stay Blizzard's but the shape becomes ours, and that shape is what the owner is now asking for.

### Open questions (as raised)

- When the icon's own border is hidden (Show border off, style None, or thickness 0), should the dispel edge still draw? If yes, at the stored Border thickness or a fixed 1 px? And should it inset the icon art as a shown border does, rather than cover the art's outer pixels?
- Should icons keep Blizzard's fixed dispel colors (the recommendation, which is today's rule), or follow General -> Dispel Colors now that a white strip can take the palette cleanly (Style.DispelColorMap(Style.ProfileDispelColors(), Style.CurveColor(ic.borderColor, ic.useClassColorBorder)))? Following the palette means rewording enUS strings 115, 121 and 124 and the Style.ProfileDispelColors comment.
- For non-Solid border styles, is a flat colored strip acceptable, or should the dispel option apply only with Solid?

## Item 11: ITEM 11 (bug): An Icon-type (row-filling) container attached to "Another container" sits beside its parent (TOPLEFT to TOPRIGHT). It should stack below it (TOPLEFT to BOTTOMLEFT).

### Root cause / design

I confirmed the earlier finding against the code on feat/2026-09-25-feedback-batch8. This is not a stray bug. The code does exactly what the batch-5 L-6 design asked for, and that design is wrong for icon rows.

When a container is attached to another container, its anchor points are never read from storage. `attachPoints` (modules/Anchors.lua:205-208) returns `Anchors.DerivedPoints(Anchors.EffectiveLayout(cfg) or {})`. `EffectiveLayout` (Anchors.lua:145-153) copies the chain root's axis, growH and growV into the child's layout (FLOW_KEYS, line 107). `DerivedPoints` (Anchors.lua:160-170) then branches on that axis:
- A vertical (column) parent stacks the child below it, TOP{H} to BOTTOM{H}, or above it when growing up.
- A horizontal (row) parent puts the child beside it: `v.."LEFT", v.."RIGHT"` (line 168), and the mirror for growing left (line 169).

Icon containers get axis "horizontal" (core/Constants.lua:54 `STYLE_FILL_AXIS.icons = "horizontal"`, applied at creation in modules/ContainerManager.lua:403-404 and when the Style row changes). So the default right/down icon row always yields TOPLEFT to TOPRIGHT, which is what screenshot 12 shows: 'Target Debuffs (All)' starts at the right edge of 'Target Buffs (All)', 4px lower. Bars and text are vertical, which is why only icon parents misbehave.

The read-only label (settings/Layout.lua:245-252 `attachedText`, locale key "Attached by its %s to the %s of '%s'") formats the same `DerivedPoints` result. That is why screenshot 13 reads "Top left to the Top right". The same fix corrects it.

Design of the default fix: make `DerivedPoints` ignore the axis. The child always stacks on the parent's vertical growth side, aligned to the horizontal edge the parent's lines start from:
- growV down: TOP{H} to BOTTOM{H}
- growV up: BOTTOM{H} to TOP{H}
- H is LEFT unless growH is "left", then RIGHT.

This is exactly the current column branch, so bars and text parents are unchanged. The inherited flow (axis, growth, engine start corner, preview offsets, handle side, clamp) is untouched; only the two attach points change.

The target frame is the parent's engine, or its preview extent while previewing (Anchors.lua:86). Both span the parent's whole block, so a row that wraps (perLine > 0) puts the child below the last line.

No DB migration is needed: in container mode the points are derived on every placement and never stored or read (`attach.point`/`attach.relativePoint` are read only in frame mode). The template's `attach.y = -4` (defaults/Profile.lua:164) already assumes a below placement. Richer, user-chosen points stay with GitHub issue #22.

### Evidence

- modules/Anchors.lua:160-170 DerivedPoints: vertical branch lines 163-166; horizontal branch line 167-169 returns v..'LEFT', v..'RIGHT' -> TOPLEFT/TOPRIGHT for a right/down row
- modules/Anchors.lua:205-208 attachPoints: container mode always DerivedPoints(EffectiveLayout(cfg) or {}); stored points used only in frame mode
- modules/Anchors.lua:224-226 Place: pcall(anchor.SetPoint, anchor, point, target, relativePoint, at.x, at.y)
- modules/Anchors.lua:86 targetFor: target is previewExtent while previewing, else engine, else anchor
- modules/Anchors.lua:107 FLOW_KEYS {axis, growH, growV}; 145-153 EffectiveLayout copies them from FlowRoot
- core/Constants.lua:54 STYLE_FILL_AXIS icons='horizontal', bars/text='vertical'; modules/ContainerManager.lua:403-404 applies it to new containers
- settings/Layout.lua:245-252 attachedText formats the label from the same DerivedPoints (the screenshot-13 text)
- defaults/Profile.lua:162-165 attach template: point TOPLEFT, relativePoint BOTTOMLEFT, x 0, y -4 (the below intent; unused in container mode)
- Only callers of DerivedPoints: Anchors.lua:206, settings/Layout.lua:249, tests/test_anchors.lua:930 (checked with grep)
- Screenshot 12: the debuff row starts at the buff row's right edge, 4px lower, and its unlocked strip overlaps the parent's strip; screenshot 13: label 'Top left to the Top right', X 0 / Y -4
- tests/test_anchors.lua:914-934 DERIVED table encodes the beside rows (lines 922-925); its red-under comment says a table ignoring the axis is the bug
- tests/test_pages_layout.lua:419-420 asserts want:format(PL.TOPLEFT, PL.TOPRIGHT, 'Target debuffs (mine)') '2 continues beside it'
- docs/settings-panel.md:562-566 'a row parent puts it beside it'; docs/smoke-tests.md:400-406 check 67 covers columns only; docs/smoke-tests.md:207-211 check 41
- libs/LibKa0s/WidgetsDragHandle.lua:105-107 DRAG_HANDLE HEIGHT 18, GAP 2; modules/Anchors.lua:462-474 placeHandle puts the strip above a down-growing anchor

### Files

- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Anchors.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_anchors.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_pages_layout.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/settings-panel.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/smoke-tests.md

### Implementation sketch

1. modules/Anchors.lua, `Anchors.DerivedPoints(L)` (lines 155-170). Drop the axis branch and keep the signature, because Layout.lua:249 and attachPoints call it:
```lua
--- The points that attach a child to a parent laid out by `L`: the child's point and the parent's
--- relative point. The child stacks below the parent (above, when it grows up), on the side the
--- parent's lines start from, whether the parent fills rows or columns. Chosen points: issue #22.
function Anchors.DerivedPoints(L)
    local h = (L.growH ~= "left") and "LEFT" or "RIGHT"
    if L.growV ~= "up" then return "TOP" .. h, "BOTTOM" .. h end
    return "BOTTOM" .. h, "TOP" .. h
end
```
Also reword the L-6 block comment at lines 102-103 ("its anchor points are derived so it picks up where the parent's auras end") to "...so it stacks below the parent (above, growing up)". The attachPoints doc (lines 203-204) stays accurate.

2. settings/Layout.lua: no change. `attachedText` becomes correct on its own. No new locale keys (POINT_LABELS already has Bottom left, Bottom right and so on), no schema keys, no defaults change, no migration.

3. Docs:
- docs/settings-panel.md:564-565: replace "a column parent stacks the child below it (above, when growing up), and a row parent puts it beside it" with "the child stacks below its parent (above, when growing up), on the side the parent's lines start from, whether the parent fills rows or columns".
- docs/smoke-tests.md check 67: add the row case (below).
- docs/smoke-tests.md check 41 ("B's placeholders start just past A's last placeholder") still holds; optionally add "below A's block".
- docs/ARCHITECTURE.md:66 and docs/module-map.md:88 only name the function and need no edit.
- Leave the frozen batch-5 spec untouched.

### Tests

- tests/test_anchors.lua:914-925 DERIVED table: change the header comment to 'the child stacks below (or above) its parent whatever it fills'. Change the four horizontal rows to right/down TOPLEFT->BOTTOMLEFT, right/up BOTTOMLEFT->TOPLEFT, left/down TOPRIGHT->BOTTOMRIGHT, left/up BOTTOMRIGHT->TOPRIGHT. Line 931's red-under comment is now backwards; change it to 'red under: the old axis branch putting a row parent's child beside it'
- tests/test_anchors.lua new: 'anchors: derived points do not depend on the parent's fill axis'. For each growH x growV pair, DerivedPoints({axis='horizontal',...}) equals DerivedPoints({axis='vertical',...}), and a layout with no axis gives the same answer. Red under: the old axis branch
- tests/test_anchors.lua new, integration through Place with the existing recordAnchor helper (line 607): attach container 2 to 3 ('Target debuffs (mine)', icons, horizontal/right/down) with x=0, y=-4, run Anchors.Place, and assert the recorded SetPoint is ('TOPLEFT', 3's engine, 'BOTTOMLEFT', 0, -4). Second case: a growH='left' row parent gives TOPRIGHT->BOTTOMRIGHT. Red under: rows placing the child beside the parent
- tests/test_pages_layout.lua:419-420: expected label becomes want:format(PL.TOPLEFT, PL.BOTTOMLEFT, 'Target debuffs (mine)'), message '3 fills rows growing right and down: 2 stacks below it'. The first assertion (line 410, the columns-growing-up parent -> BOTTOMLEFT/TOPLEFT) is unchanged
- Run lua tests/run.lua (baseline 1363 passed) and luacheck. DerivedPoints' CCN drops, so lizard stays clean

### Smoke

- Screenshot scenario: 'Target Debuffs (All)' (icons) attached to 'Target Buffs (All)' (icons, rows right/down), X 0, Y -4. The debuff row starts directly under the buff row's first icon, 4px below, with left edges aligned. The line beside the Container dropdown reads "Attached by its Top left to the Bottom left of 'Target Buffs (All)'"
- Parent row with Per row set so it wraps to 2+ lines: the child sits below the parent's LAST line. When the parent gains a line in-game, the child moves down
- Parent grows left (the 'Player debuffs' starter): the child is right-aligned under it, and the label says Top right to Bottom right
- Parent Grow vertically = up: the child sits above the parent (Bottom left to Top left)
- Bars/text (column) parent regression: check 67 still passes unchanged
- Test mode on: the child hangs below the parent's placeholder block, and returns under the live engine after /am test off (check 41)
- Unlocked (/am unlock): the child's 18px strip now sits over the bottom of the parent's last icon line and draws above it (the L-4 handle level). Confirm this is acceptable, and that dragging the parent still works, since the parent's icons stay hittable except under the strip

Needs migration: False

### Risks

- My review confirmed the root cause, the file:line citations, the fix and the no-migration call. Corrections: the attachedText line range is 245-252 and DerivedPoints is 160-170 (the doc comment starts at 155). The DERIVED test's red-under comment (line 931) explicitly calls the axis-ignoring rule the bug, so it has to be inverted, not only edited. The integration test should use the existing recordAnchor helper at line 607. docs/ARCHITECTURE.md and docs/module-map.md need no edit and were dropped from the files list. The unlocked-strip risk was understated (next item)
- Unlocked overlap, understated in the previous record: the child's drag strip is DRAG.HEIGHT 18 + GAP 2 = 20px above the child's anchor (Anchors.lua:462-474), and the default gap is only 4px. So when unlocked, the strip covers about 16px of the parent's last icon line, and handleLevel deliberately draws it above the parent. Column parents already do this, but icon rows will now hit it too. It is cosmetic and only happens while unlocked
- Behavior change for existing profiles: anyone who attached a container to an icon-row parent and tuned attach.x/y to sit beside it will see the child jump below, still carrying those offsets. Nothing can be migrated because the points are derived. Mention it in the release notes
- With a growing-up parent, the default y=-4 pulls a stacked-above child 4px into the parent. This already happens for columns and is not new
- Empty parent engine (no auras, no preview): its rect may collapse, so the child sits at the parent's top edge. This already happens for columns
- Children inherit the root's axis, so a bars child attached to an icon row still fills horizontally. That is unchanged and out of scope

### Open questions (as raised)

- When the parent grows up, should the attached child stack ABOVE it (the proposal, matching the current column behavior), or always go below? Issue #22 would let the owner choose points explicitly

## Item 13: ITEM 13 (bug): the gap between a parent container's last aura and an attached child container's first aura does not match the spacing between auras inside a container, locked or unlocked

### Root cause / design

ROOT CAUSE (confirmed on re-read). In "Another container" mode the gap across the seam never comes from the layout. It is the stored named-frame offset (attach.x/attach.y, default 0/-4), applied as a fixed screen-space nudge whichever way the chain grows.

1. modules/Anchors.lua:224-226 (Anchors.Place). attachPoints (Anchors.lua:205-208) derives only point and relativePoint from the effective flow (DerivedPoints, :156-169). The offsets are always `tonumber(at.x) or 0, tonumber(at.y) or 0`, the same as for a named frame.
2. defaults/Profile.lua:164 sets `attach = { point="TOPLEFT", relativePoint="BOTTOMLEFT", x = 0, y = -4 }` on every container. The -4 means "a little below a named frame" and has nothing to do with layout.spacing (default 2).
3. The target rect is the auras' block with no trailing margin. Locked, the child hangs from the parent's engine (Anchors.lua:86-88), which is anchored at its flow corner at 0,0 (Container.lua:227) with flow padding 0 (Container.lua:117). While previewing, it hangs from Preview.Extent (Preview.lua:170-186), sized farX+w by farY+h from Preview.Offset, whose inter-element step is w/h + spacing (Preview.lua:61-67). So the whole gap is the offset:
   - vertical, growing down: the gap is 4px, but bars inside a container sit `spacing` (2) apart.
   - vertical, growing up (the screenshot: both strips sit below their blocks): child BOTTOMLEFT goes to parent TOPLEFT at y -4, which pushes the child 4px down INTO the parent. The blocks overlap.
   - horizontal: the x gap is 0 (the elements touch), and the child's line drops 4px below the parent's.
4. Unlocked (screenshot 14). Nothing moves the auras. placeHandle (Anchors.lua:462-475) puts the child's strip (DRAG.HEIGHT 18, DRAG.GAP 2) on the side away from its growth. For a column child, that side faces the parent. handleLevel (:443-452) deliberately raises it above the parent's placeholders (L-4). So the "Target Debuffs (Mine) TEST" strip covers the parent's top "Well Fed" bar. This is the documented L-4 behaviour (smoke-tests.md checks 14/41/68), but it is what the owner sees as a wrong seam.

DESIGN.
(a) When Anchors.FlowRoot(cfg) is not nil (container mode with a usable target), the seam gap is the CHILD's own layout.spacing, along the inherited fill axis, in the direction the chain grows. Only spacing is used, not lineSpacing, because DerivedPoints always attaches past the end of the block along the fill axis. Four reasons for the child's spacing:
   (i) SetPoint offsets are in the positioned frame's (the child anchor's) scale. The child's spacing is in that same scale, so the seam matches the child's internal gaps exactly even when the two containers use different Scale values. The parent's spacing would be off by the scale ratio.
   (ii) EffectiveLayout already keeps spacing as the child's own (Anchors.lua:101-104).
   (iii) Container:Apply re-places the child's anchor (Container.lua:364), so no new FLOW_PATHS entry is needed.
   (iv) It is edited on the child's own page.
   Offsets from L = EffectiveLayout(cfg), s = max(0, tonumber(L.spacing) or 0): vertical/down (0,-s), vertical/up (0,+s), horizontal/right (+s,0), horizontal/left (-s,0).
(b) Container mode stops reading attach.x/attach.y. The Offset rows become Named-frame-only. The stored values are kept, so switching back to Named frame restores them. No schema change and NO MIGRATION.
(c) Unlocked: the aura gap is identical to the locked one (it comes from the same Place). The child's strip moves off the seam. For a container-following child whose effective axis is vertical, the strip sits BESIDE the child's first element, on the side opposite growH:
   - edge-aligned with the seam: TOP when the chain grows down, BOTTOM when it grows up. That way the 18px strip runs into the child's own area and never into the parent.
   - label-width (ApplyWidth(0)).
   The clamp gets a left/right reach instead of top/bottom. Horizontal-axis children keep the above/below strip, which does not cover the parent's elements. This replaces the "handle draws over the parent's placeholders" part of L-4. If the owner rejects (c), (a)+(b) still fix the aura gap in both states. The strip would then still hide the parent's last aura while unlocked.

### Evidence

- modules/Anchors.lua:205-208 attachPoints: container mode derives only the points
- modules/Anchors.lua:224-226 Place: `pcall(anchor.SetPoint, anchor, point, target, relativePoint, tonumber(at.x) or 0, tonumber(at.y) or 0)`, which applies the stored offsets in container mode
- modules/Anchors.lua:156-169 DerivedPoints: vertical+up gives BOTTOM*->TOP*, so y=-4 pushes the child into the parent
- defaults/Profile.lua:164 `point = "TOPLEFT", relativePoint = "BOTTOMLEFT", x = 0, y = -4`
- modules/Anchors.lua:86-88 target is previewExtent while previewing, else the engine
- modules/Container.lua:117 SetFlowLayoutPadding 0,0,0,0; :227 engine SetPoint(flow.anchorPoint, anchor, flow.anchorPoint, 0, 0)
- modules/Preview.lua:46-71 Offset step = size + spacing; :170-186 Extent sized farX+w by farY+h, with no trailing margin
- modules/Container.lua:361 anchor:SetScale(layout.scale*profile.scale), so offsets are in the child's scale (why the child's spacing is correct)
- modules/Anchors.lua:443-452 handleLevel lifts an attached child's strip above the target's anchor level (L-4); :462-475 placeHandle puts the strip on the side away from growth
- modules/Anchors.lua:382-385 canDrag: only screen mode drags, so no SavePosition path writes attach.x/y
- modules/Anchors.lua:360-366 tooltipSpec shows 'Attached - set its offsets on the Layout page.' for both attached modes; locales/enUS.lua:30 (the key has an em dash)
- settings/Layout.lua:39 ATTACHED_ONLY is used only by the Offset rows at :145-154; :118 the Container desc
- tests/test_anchors.lua:991-1002 asserts the stored 6,-2 pass through in container mode; :1004-1015 frame test checks the points but not the offsets; :861 tooltip line test
- docs/schema.md:86 and docs/settings-panel.md:533 say the offsets apply to both attached modes; docs/smoke-tests.md:57-59, :128, :206-210, :407 describe the current behaviour
- Screenshot 14.png: the chain grows up; the child's strip covers the parent's top 'Well Fed' bar

### Files

- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Anchors.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/settings/Layout.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/locales/enUS.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_anchors.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_pages_layout.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/smoke-tests.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/schema.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/settings-panel.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/ARCHITECTURE.md

### Implementation sketch

modules/Anchors.lua
1. Add next to DerivedPoints:
   --- The offset that leaves one of the child's Spacing between its parent's block and itself.
   function Anchors.DerivedOffset(L)
     local s = math.max(0, tonumber(L.spacing) or 0)
     if L.axis == "vertical" then return 0, (L.growV == "up") and s or -s end
     return (L.growH == "left") and -s or s, 0
   end
2. Replace attachPoints with attachSpec(cfg, at, mode), which returns point, relativePoint, x, y:
   - container: L = EffectiveLayout(cfg) or {}; return DerivedPoints(L) and DerivedOffset(L).
   - frame: return the stored points and tonumber(at.x) or 0, tonumber(at.y) or 0.
   Place calls pcall(anchor.SetPoint, anchor, p, target, rp, x, y). The screen fallback is unchanged. Update the L-6 header comment (Anchors.lua:100-105): "Its offsets" become "one Spacing".
3. (Part c) Add `local function sideHandle(cfg) return Anchors.FlowRoot(cfg) ~= nil and (Anchors.EffectiveLayout(cfg) or {}).axis == "vertical" end`.
   In placeHandle, when sideHandle(cfg):
     local v = (growV == "down") and "TOP" or "BOTTOM"
     local right = (growH ~= "left")
     handle:SetPoint(v .. (right and "RIGHT" or "LEFT"), container.anchor, v .. (right and "LEFT" or "RIGHT"), right and -DRAG.GAP or DRAG.GAP, 0)
     return a side reach: handle:ApplyWidth(0) + DRAG.GAP, flagged as side.
   Keep handle.placed, handleLevel and the lockdown rules unchanged.
   In clampToHandle, when sideHandle(cfg): the reach goes on the left for growH right and on the right for growH left (left = -reach / right = reach), with top = bottom = 0.
   Update the placeHandle/handleLevel L-4 comments. The level raise can stay, since it is harmless.
4. tooltipSpec: in container mode return NS.L["Attached - it follows its container, one Spacing past its last aura."]. Frame mode keeps the existing line.
settings/Layout.lua
5. The Offset rows (:145-154) change shownWhen from ATTACHED_ONLY to FRAME_ONLY. Delete ATTACHED_ONLY (:39), which would otherwise be an unused local for luacheck. Optionally reword the offset descs to "from the named frame's attachment point".
6. Container row desc (:118): new key "The container to attach to when 'Another container' is chosen. This one continues its flow: fill and growth follow it, the attachment points are set for you, and the gap to it is this container's Spacing. A chain that would loop falls back to the screen." Remove the old key.
locales/enUS.lua
7. Add the two new keys (ASCII, key == value) and remove the retired desc key. Keep the em-dash offsets key for frame mode. Do not copy its em dash.
Schema/defaults: unchanged. NO MIGRATION.
Docs: schema.md:86 ("offsets for the frame mode; ignored in container mode, which leaves one Spacing"), settings-panel.md:533, ARCHITECTURE.md L-4/L-6 placement paragraph, smoke-tests checks 14, 41, 68 and the :128 note.

### Tests

- tests/test_anchors.lua: table-driven 'DerivedOffset leaves one Spacing along the inherited flow': 8 axis/growH/growV combos with spacing 3. Expect vertical down (0,-3), up (0,3), horizontal right (3,0), left (-3,0). Also spacing 0 gives (0,0), and nil or negative gives (0,0).
- tests/test_anchors.lua: rewrite the test at :991-1002. oddParent (vertical/left/up), child stored x=6,y=-2, child layout.spacing=5: assert p[4]==0, p[5]==5. It must fail against the current Place, which gives 6,-2.
- tests/test_anchors.lua: 'the seam is the child's spacing': parent spacing 9, child spacing 2, so the offset magnitude is 2.
- tests/test_anchors.lua: extend the frame-mode test at :1004-1015 to assert rec.points[1][4]==1 and [5]==2 (frame mode keeps its stored offsets).
- tests/test_anchors.lua: a container attached to a missing or looping target falls back to toScreen with position x,y and gets no derived offset.
- tests/test_anchors.lua: while the parent previews (target = previewExtent), the offset equals the locked one.
- tests/test_anchors.lua: the tooltip test at :861 splits in two. Container mode shows the new 'follows its container' line; frame mode keeps 'set its offsets on the Layout page'.
- tests/test_anchors.lua (part c): a vertical-axis attached child's strip, across growH right/left x growV down/up. For right/down: SetPoint TOPRIGHT to anchor TOPLEFT, x=-2, y=0. The clamp insets carry a left/right reach and top=bottom=0. Horizontal-axis children and screen containers keep the existing above/below cases (the existing strip tests stay green).
- tests/test_pages_layout.lua: the Offset subgroup (:47) is drawn only in Named frame mode. container.attach.x is hidden in container mode but still answers /am get.
- Locale/ASCII checks: the new keys are ASCII and the retired desc key is gone (luacheck: no unused ATTACHED_ONLY).

### Smoke

- Locked, real auras, B attached to A, A growing down in columns: the gap from A's last bar to B's first bar equals the gap between B's bars (2px at Spacing 2, not 4).
- Set A's vertical growth to up (the screenshot case): B sits above A with one B-Spacing gap and no overlap.
- Set A's Fill to rows, growing right, with icons: B's first icon is one Spacing to the right of A's block, on the same top line (no 4px drop).
- Set B's Spacing to 10: B's internal gaps and the A-B seam change together, and A does not move. Change A's Spacing: only A's internal gaps change.
- Set B's Scale to 1.5 and A's to 1: the seam still equals B's on-screen inter-bar gap.
- /am test with A and B previewing: the seam between placeholders equals the locked seam.
- /am unlock, test mode on, column chain: B's strip sits beside B's first element, on the side away from growth, and covers none of A's placeholders or bars. Right-click on B's strip opens B's settings, and B cannot be dragged.
- Unlocked, B flush against the left screen edge (growH right): the strip stays on screen. After /am lock, B returns to its place.
- Layout > Anchor with Another container: the X/Y offset rows are hidden and the Container desc mentions Spacing. Switch to Named frame: the offsets reappear with their stored values, and the frame-attached container sits where it did before.
- Hover the strips: B (container mode) shows the new tooltip line, and a frame-attached container shows the old one.
- Enter combat while unlocked: no re-place, no Lua or taint errors. After combat, the strips and seams catch up.
- An empty parent (no auras, locked): note where B sits. The engine rect may be stale or 1x1, which is pre-existing behaviour.

Needs migration: False

### Risks

- Reviewer corrections to the prior finding: (1) Added the scale argument for choosing the child's spacing. SetPoint offsets are in the child anchor's scale (Container.lua:361), so the child's spacing matches its own gaps exactly under mixed Scale, and the parent's spacing would not. (2) Added missed doc files: docs/schema.md:86, docs/settings-panel.md:533, docs/smoke-tests.md:128. (3) Added the tooltip test at tests/test_anchors.lua:861, which must split per mode. (4) The frame-mode test was cited at :1005-1016; it is actually :1004-1015. (5) Made explicit that ATTACHED_ONLY becomes an unused local and must be deleted for luacheck. (6) The side strip must be edge-aligned at the seam (TOP when growing down, BOTTOM when growing up), so the 18px strip, which can be taller than a short element, runs into the child and never back over the parent. The root cause and the core fix (a)+(b) were verified as correct.
- Behaviour change: anyone who tuned attach.x/y in container mode loses that nudge. The values stay stored and still work in Named frame mode. Keeping a nudge would need a new key (for example attach.gap) with a schema bump and a migration.
- The engine rect being exactly the aura block (padding 0 plus the flow container sizing to its children) cannot be checked headlessly. If Blizzard's flow layout leaves a trailing margin or a stale rect, the seam drifts. Smoke must confirm.
- Part (c) is new geometry beside a protected engine's parent. It must keep the lockdown rules (placeHandle only out of combat, except the first placement). A column chain at a screen edge will be clamped sideways instead of vertically while unlocked.
- L-4 docs and smoke checks 14/41/68 assert the strip-over-parent behaviour. Rewrite them in the same change.
- Horizontal chains keep the above/below strips. A parent strip wider than its block can still overhang next to the child's strip. This is a pre-existing, minor issue.

### Open questions (as raised)

- Seam = the CHILD's Spacing (recommended: it matches the child's own gaps under any scale, and needs no new follower wiring), or the PARENT's Spacing? At the default of 2 on both, the two look the same.
- Drop X/Y offsets in 'Another container' mode (recommended, no migration), or keep an extra 'gap' nudge (new key, schema bump and migration)?
- Unlocked: move an attached column child's drag strip beside its first element, off the seam (recommended)? Or keep today's L-4 strip over the parent's last aura and fix only the aura gap?

## Item 16: ITEM 16 (feature): /am debug diag. Dumps into the debug console the auras on player, target, focus and pet, every container with its filters, config and applied plan, the queue state, and what each container is drawing.

### Root cause / design

DESIGN. The earlier design is sound in outline and has been verified against the code. The corrections are listed in risks.

**Verb.** `diag` becomes a sub-verb of the existing reserved `debug` verb.
- The standard allows it: WowAddonStandards standards/standards/debug-logging.md:59 says "MAY support structured dump verbs (`/<slash> debug <topic>`)".
- `debug` is already a live verb while the addon is disabled (settings/Slash.lua:122-131), so no gate change is needed.
- NS.COMMANDS stays at 22 (docs/slash-dispatch.md:3).
- runDebug (settings/Slash.lua:340-347) lowercases through firstWord and sends every other word to Toggle(), so a `diag` branch placed before the on/off test is safe.

**Sink.** Output goes through the UNGATED `NS.DebugLog:Add(tag, msg)` (libs/LibKa0s/DebugLog.lua:624).
- debug-logging-§12 (debug-logging.md:212) requires that output from an explicit user-initiated diagnostic run is not gated on the debug flag.
- There is precedent: core/PerfSetup.lua:76-78.
- Add runs every msg through safeToString (:630).
- The host reveals the console itself (§12 makes that the host's call) and prints one L-routed chat line.
- The body lines are English diagnostics, not L-routed, like every existing trace and the [Init] summary (core/DebugLogSetup.lua:95-107).

**Size.** The buffer is `lib.MAX_BUFFER = 1500` (DebugLog.lua:57), and CopyText copies only the newest MAX_BUFFER lines (:732). The report:
- builds its lines into an array first;
- caps them at MAX_LINES = min(1200, MAX_BUFFER - 100);
- caps each unit/filter pass at 100 auras and each inline id list at 40;
- ends with `[Diag] truncated: N line(s) omitted` when a cap is hit.

The config for pages other than Filters prints non-default rows only, because a full per-container dump of every schema row would overflow at about 6 containers. The Filters block always prints in full.

**Midnight.** Measured on 12.1, `GetAuraDataByIndex` / `GetUnitAuras` / `GetAuraSlots` raise on every call while auras are secret, and `ShouldAurasBeSecret` is true in every combat context (docs/midnight-quirks.md:30-38). So:
- The aura section is gated on `NS.Compat.AurasAreSecret()` (core/Compat.lua:46) and each read is also pcall'd, copying modules/TimedSpells.lua:69-78.
- When auras are secret, each unit prints one "unreadable" line and no API call is made.
- Every field goes through `NS.SafeToString`.
- `left` is computed only when `Secrets.IsReadableNumber(expirationTime)` and GetTime is readable.
- helpful/harmful comes from the filter string that was queried, never from a boolean test of a possibly-secret `isHelpful`.
- In combat, touching engine button objects raises too: `Region:IsShown`, `IsAnchoringSecret` and more "raise" per midnight-quirks.md:169-171, and buttons lock per midnight-quirks.md:61-65. So while secret, the [Shown] section makes NO per-button calls. It prints only the pcall'd `GetAuraGroupFrameCount` per group, or `?`.

**What a container shows.** Blizzard's AuraContainer owns gathering and drawing (midnight-quirks.md:40-54). The addon holds only the button tables, through `engine:GetAuraGroupFrameCount(key)` / `GetAuraGroupFrame(key,i)` (modules/Container.lua:327-346). The aura behind a button is `CustomAuraButtonPrivateMixin:GetAuraInstance()`, a Blizzard source line quoted in docs/superpowers/research/2026-09-13-aura-engine-notes.md:46-47. `initializeFrame` receives `auraFrame:GetObjectTable()` (notes :75), so a public identity getter is unconfirmed. The report gives three layers, each labeled:
1. Engine truth: frames created per group and how many are shown, both pcall'd.
2. Best-effort identity, out of combat only:
   - First it probes `frame.GetAuraInstance` / `GetAuraInstanceID` under pcall.
   - Failing that, it reads our own regions: `frame.__am.name:GetText()` and `frame.__am.icon:GetTexture()`. Those regions are bound by the engine through `SetSpellName` / `SetIcon` at modules/Style_Bars.lua:315-316, Style_Icons.lua:155 and Style_Text.lua:508,521.
   - The name region is absent for Icons, and for Bars with the name hidden. That case prints `id=?`.
3. A PREDICTED verdict per readable aura on the container's unit and aura type, from `FC.ExplainSpell(cfg, spellId, FC.ProfileContext())` (modules/FilterCompiler.lua:916). It is labeled "predicted", because ExplainSpell reasons only about spells-kind categories and uncategorized (:896-903).

**Staleness: the key signal for "my settings did not apply".** Two independent inputs:
- (a) The manager queue, through a new read-only `CM.QueueSnapshot()`: pending ids, pendingAll, scheduled, shownReason and MustDefer (file locals at modules/ContainerManager.lua:30-36, :196). This covers EVERY deferred change, layout and style included.
- (b) A plan comparison: `FC.Signature(inst.plan)` against `FC.Signature(FC.Compile(cfg, FC.ProfileContext()))`, the same call Apply makes (Container.lua:355). This covers the filter/plan dimension only. No label stripping is needed: plan group labels are the RAW def.label (FilterCompiler.lua:566-575, 637-641), which is deterministic, and both plans come from the same pure Compile.

The two combine into one verdict:
- plan equal: "plan in sync".
- plan differs and the id is queued (or pendingAll): "PENDING (combat|secret|scheduled)".
- plan differs and nothing is queued: "DRIFT: settings changed but no apply was requested". This is a real bug signal, and the most valuable line in the report.
- `inst.plan` nil: "not built". This covers a missing engine (Compat.HasAuraContainer false), a parked or retired instance, and a disabled one.

Per-instance flags are also reported: parked, staleData, classStale, `#inst.retired`, `#inst.enchantFrames`, `ShouldShow()` (pcall'd), and `inst.warnings`. warnings are English locale keys, so they print raw.

**OUTPUT FORMAT.** The library renders each line as `HH:MM:SS | [Tag] msg` (FormatPlain, DebugLog.lua:125). Tags are single short words: Diag, Unit, Aura, Cont, Filt, Plan, Cfg, Shown.
```
[Diag] ==== Aura Master diagnostic begin ====
[Diag] Aura Master v1.x.y, schema v7, profile 'Default', client 12.1.0 (120100)
[Diag] state: enabled=true stoodDown=false disabledHold=false locked=true testMode=false visibility=always combat=false lockdown=false aurasSecret=false selected=#2
[Diag] apply queue: all=false ids=[] scheduled=false notice=- mustDefer=false
[Diag] timed spells learned=14, category spell edits +3 -1, user categories=2, enchant slots=mainHand,offHand
[Cfg]  profile non-default: scale=1.1, visibility=inCombat
[Unit] player HELPFUL: 7 aura(s)
[Aura] player+ #1 inst=1234 id=1459 "Arcane Intellect" dispel=Magic src=player mine=true dur=3600 left=3412.5 stacks=0 boss=false steal=false
[Unit] player HARMFUL: 0 aura(s)
[Unit] target: none
[Unit] focus: unreadable (auras are secret - run /am debug diag out of combat)
[Cont] #1 "Player Buffs" unit=player HELPFUL style=bars enabled=true attach=screen | engine=yes shows=yes parked=no staleData=no classStale=no retired=0 enchantFrames=0
[Filt] #1 castBy=any duration=any maxDuration=0 sort=expirationOnly/normal maxAuras=0 hidePermanentEnchants=true
[Filt] #1 categories hide=[Consumables, Raid buffs] show=26 other(s)
[Filt] #1 whitelist(2)=[1459 Arcane Intellect, 21562 Power Word: Fortitude] blacklist(0)=[]
[Plan] #1 plan in sync   | PENDING (combat) | DRIFT: settings changed but no apply was requested | not built
[Plan] #1 g1 "Always shown" filter=HELPFUL cand={includeSpellIDs:2} sort=expirationOnly/normal max=0 frames=3 shown=2
[Plan] #1 warning: Spell lists only apply while the unit is friendly.
[Cfg]  #1 non-default: bars.width=220, layout.perLine=5
[Shown] #1 g1 btn1 id=? name="Arcane Intellect" icon=135932
[Shown] #1 predicted: 1459 Arcane Intellect -> shown (rank 1 whitelist); 2825 Bloodlust -> hidden (rank 4: Consumables)
[Diag] ==== end: 143 line(s) ====
```
No SavedVariables key, default or schema change, so NO MIGRATION.

### Evidence

- settings/Slash.lua:78-79 - the `debug` verb row and its help key. :340-347 - runDebug: on/off goes to SetEnabled, anything else to Toggle(), so the `diag` branch goes before the on/off test
- settings/Slash.lua:122-131 - liveVerbs includes `debug`, so `/am debug diag` answers while the addon is disabled
- settings/Slash.lua:440-452 - formatValue is a local and emits color escapes (`|cff808080(%s)|r`, color swatches through SlashLib.FormatValue). Those would land verbatim in the plain buffer, because FormatPlain (DebugLog.lua:125) does no stripping
- libs/LibKa0s/DebugLog.lua:57 MAX_BUFFER=1500; :624-646 D:Add is ungated and safeToString's msg; :652-680 D.Debug is gated; :732 CopyText copies the newest MAX_BUFFER lines; :746 Show
- WowAddonStandards standards/standards/debug-logging.md:58-59 - Add is for explicit user-initiated diagnostics; debug <topic> dump verbs are allowed. :212-213 (§12) - diagnostic output MUST NOT be gated; revealing the console is the host's call
- WowAddonStandards standards/standards/documentation.md:256 - docs/debug.md is required once the addon ships debug surfaces beyond the default console; docs/ARCHITECTURE.md:284 currently lists it as Not applicable
- core/PerfSetup.lua:76-78 - precedent: NS.DebugLog:Add("Perf", line)
- core/DebugLogSetup.lua:13-65 - the library-absent stub: Add is a no-op and Show calls sayOnce, so diag must detect the missing library and print an unavailable line
- docs/midnight-quirks.md:30-38 - aura APIs raise on every call while secret; secret in every combat context
- docs/midnight-quirks.md:61-65 and :169-171 - buttons lock while secret; Region:IsShown / IsAnchoringSecret on button objects raise in combat
- core/Compat.lua:46 AurasAreSecret; modules/TimedSpells.lua:69-80 - the existing gated, pcall'd GetAuraDataByIndex loop reading `_G.C_UnitAuras`
- core/Secrets.lua - IsSecret/CanAccess/IsReadableNumber/IsSafeKey
- modules/Container.lua:327-346 - pcall'd GetAuraGroupFrameCount/GetAuraGroupFrame; :350-392 Apply compiles with FC.Compile(cfg, FC.ProfileContext()), sets warnings (:356) and clears parked/staleData (:389); :267/:315 set self.plan; :181 Retire nils plan; :40 retired/enchantFrames
- modules/Style_Bars.lua:30-40,65-67 - frame.__am regions (icon, name); :315-316 the SetIcon/SetSpellName bindings; Style_Icons.lua:155; Style_Text.lua:508,521
- docs/superpowers/research/2026-09-13-aura-engine-notes.md:46-47 (GetAuraInstance on CustomAuraButtonPrivateMixin) and :75 (initializeFrame gets auraFrame:GetObjectTable()). The previous record's ':71,594-596' were line numbers in the quoted Blizzard source, not in this file
- modules/ContainerManager.lua:30-36 - pending/pendingAll/scheduled/shownReason are file locals; :44 CM.Count; :145/:148 __retiring/__dormant; :196 MustDefer
- modules/FilterCompiler.lua:566-575,637-641 - plan group labels are the RAW def.label, deterministic, so the plan Signature compares cleanly with no label strip. :761-768 ProfileContext; :916-941 ExplainSpell (spells-kind only per :896-903); :950 Signature
- settings/Schema.lua:192 NS.ActiveContainer, :221 NS.DefaultFor, :349-355 rowApplies (local), :377 NS.GetSetting(path, containerId)
- core/Constants.lua:39 - C.UNITS = {player, target, focus, pet}: pet is a supported container unit, so it belongs in the dump
- core/LifecycleSetup.lua:31,165,169 - NS.EnabledStored / IsStoodDown / IsDisabled; core/State.lua:19-21 debug/activeContainerId/testMode
- .luacheckrc:13-23 - read_globals has no UnitExists or GetBuildInfo, and tests/test_lintconfig.lua keeps the list exact. Read them through `_G.` as TimedSpells does, or add them to read_globals
- tests/wow_mock.lua:59-83 - mock engine __frames/GetAuraGroupFrameCount; :130-148 __SECRET + issecretvalue; :217-218 __aurasSecret. The mock has NO C_UnitAuras by default; tests/test_timedspells.lua:10 installs mocks.C_UnitAuras; tests/_kit/mock_base.lua:1078 UnitExists reads mocks.__unitExists
- tests/test_slash_verbs.lua:538-552 - the bare-debug and debug on/off tests; :810 the list of verbs that must answer while disabled
- locales/enUS.lua:412 - the current debug help key; docs/slash-dispatch.md:60 row 20; docs/ARCHITECTURE.md:46 (49 files, 14 modules), :161 (slash row), :281 (21 compat shims), :284 (debug.md)

### Files

- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Diagnostics.lua (NEW)
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/AuraMaster.toc (modules\Diagnostics.lua after modules\ContainerManager.lua)
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/settings/Slash.lua (runDebug `diag` branch; help key; publish Sl.FormatValue = formatValue)
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/ContainerManager.lua (read-only CM.QueueSnapshot())
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/settings/Schema.lua (NS.RowApplies = rowApplies)
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/locales/enUS.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_diagnostics.lua (NEW)
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/run.lua (suite inventory)
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/tests/test_slash_verbs.lua
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/debug.md (NEW)
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/ARCHITECTURE.md (:46 counts 49->50 / 14->15 modules, :161 slash row, :284 debug.md Present)
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/slash-dispatch.md (row 20)
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/module-map.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/smoke-tests.md
- /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/test-cases.md (regenerated inventory)
- OPTIONAL: /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/core/Compat.lua + docs/compat-layer.md + ARCHITECTURE.md:281 (21->22) only if the owner prefers a Compat.UnitAuraList shim
- OPTIONAL: /mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/.luacheckrc only if UnitExists/GetBuildInfo are read as bare globals rather than through _G

### Implementation sketch

**1. NEW `modules/Diagnostics.lua`: `NS.Diagnostics` (local Diag).** It is a pure line builder plus a thin Run. Every function stays under CCN 15.

Constants:
- `local lib = LibStub and LibStub("LibKa0s-DebugLog-1.0", true)`
- `MAX_LINES = math.min(1200, ((lib and lib.MAX_BUFFER) or 1500) - 100)`
- `MAX_AURAS = 100`, `MAX_IDS = 40`
- `UNITS = NS.Constants.UNITS` (player, target, focus, pet)
- `FILTERS = {"HELPFUL","HARMFUL"}`

Output buffer:
- `newOut()` returns `{lines={}, dropped=0}`.
- `out:add(tag, fmt, ...)` pre-stringifies every arg through `NS.SafeToString`, then runs `pcall(string.format, fmt, ...)`. Format strings use `%s` only, never `%d` or `%.1f`, because the args are already strings. On failure it falls back to a space-join.
- `plain(s)` strips `|c%x%x%x%x%x%x%x%x` and `|r` (and `|T...|t`) so the Copy text is clean.
- Past MAX_LINES, `add` increments `dropped` instead of appending.
- `section(out, name, fn, ...)` pcall-wraps each section. On error it adds `[Diag] section <name> failed: <err>`.

Readers, all through `_G.` so luacheck needs no new read_globals: `_G.UnitExists`, `_G.GetBuildInfo`, `_G.C_UnitAuras`.

`Diag.Header(out)`:
- NS.name and NS.Version(), `NS.db.global.schemaVersion`, `NS.db:GetCurrentProfile()`, and `pcall(_G.GetBuildInfo)`.
- The state line: NS.EnabledStored(), NS.IsStoodDown(), NS.IsDisabled(), profile.locked, NS.State.testMode, profile.visibility, UnitAffectingCombat("player"), InCombatLockdown(), NS.Compat.AurasAreSecret(), and `select(2, NS.ActiveContainer())`.
- The queue line from `NS.ContainerManager.QueueSnapshot()`.
- Counts: `global.timedSpells` (pairs count), the profile.categorySpells add/remove counts, `#profile.userCategoryOrder` if present, and profile.enchantSlots.

`Diag.ProfileConfig(out)`: every NS.Schema row whose path does not start with `container.`, and is neither `sessionOnly` nor `hidden`. It prints only where `FC.Signature(NS.GetSetting(p)) ~= FC.Signature(NS.DefaultFor(p))`, as `path=plain(NS.Slash.FormatValue(row, v))`, several per line, joined up to about 200 chars.

`readAuras(unit, filter)`:
- Returns `nil, "secret"` if `AurasAreSecret()`.
- Returns `nil, "unavailable"` when `_G.C_UnitAuras` has no `GetAuraDataByIndex`.
- Otherwise loops `i = 1..MAX_AURAS` over `pcall(api.GetAuraDataByIndex, unit, i, filter)`. It stops on a non-table and returns `nil, "read failed: "..err` on a raise.
- This stays LOCAL, mirroring TimedSpells (see the open question on the Compat shim).
- Out of combat, the result is cached per `(unit, filter)` for this run, so [Shown] predictions reuse it.

`fmtAura(unit, filter, i, a)` prints:
- inst=auraInstanceID, id=spellId, `"name"`, dispel=dispelName, src=sourceUnit, mine=isFromPlayerOrPlayerPet, dur=duration, stacks=applications, boss=isBossAura, steal=isStealable.
- `left = (IsReadableNumber(exp) and exp > 0 and IsReadableNumber(GetTime())) and ("%.1f"):format(exp - GetTime()) or "-"`. That format is applied to a readable number BEFORE `add`, so it is not affected by the %s-only rule.
- No boolean test on any field.

`Diag.Auras(out)`:
- Per unit, if `not _G.UnitExists(unit)`: `[Unit] <unit>: none`.
- Else if secret: one unreadable line per unit, and no API call.
- Else, per filter, the header line with the count, then the aura lines.

`Diag.Containers(out)` runs, for each `c` in `NS.Database.GetContainers()` with `inst = CM.instances[c.id]`, six section-wrapped helpers:
- `contLine`: id, name, unit, auraType, style, enabled, attach. Then engine yes/no, pcall(inst.ShouldShow, inst), parked, staleData, classStale, #retired, #enchantFrames, and whether the id is in CM.__dormant()/__retiring().
- `filtLines`: castBy, durationMode, maxDuration, sortMethod/sortDirection, maxAuras, hidePermanentEnchants.
  - Categories: the hide keys as `NS.Categories.LabelOf(def)` labels, and a show count.
  - Whitelist and blacklist: sorted numerically, capped at MAX_IDS, each id paired with its name from `NS.Compat.GetSpellInfo(id)` under pcall.
- `planLines`:
  - `fresh = FC.Compile(c, FC.ProfileContext())`, `q = CM.QueueSnapshot()`.
  - verdict: `not inst or not inst.plan` gives "not built"; equal Signature gives "plan in sync"; `(q.all or q.idSet[c.id])` gives "PENDING (" .. (q.notice or (q.mustDefer and "deferred") or "scheduled") .. ")"; anything else gives "DRIFT: settings changed but no apply was requested".
  - One line per APPLIED plan group: key, label, filter, a cand summary (id-set sizes and flag values, math.huge shown as `inf`), sort/max.
  - frames=/shown= per group. frames always comes from pcall(GetAuraGroupFrameCount). shown is counted with pcall(frame.IsShown, frame) ONLY when not secret, else `shown=?`.
  - Then `inst.warnings`.
- `cfgLines`: the non-default `container.*` rows other than `container.filter.*` and `container.name`, where `NS.RowApplies(row, c)` holds, compared by Signature against NS.DefaultFor.
- `shownLines`:
  - Skipped with one line when secret.
  - Otherwise, per shown frame, `identify(frame)`:
    - It first probes `pcall(frame.GetAuraInstanceID, frame)`, then `pcall(frame.GetAuraInstance, frame)`, each only `if type(frame.X)=="function"`. A table auraData is read for auraInstanceID/spellId through SafeToString.
    - Failing that, it reads `am.name` (`pcall(am.name.GetText, am.name)`) and `am.icon` (`pcall(am.icon.GetTexture, am.icon)`).
    - Else it prints `id=?`.
  - Then the `predicted:` list: for each cached aura of c.unit / c.auraType whose `Secrets.IsSafeKey(spellId)` holds, ExplainSpell gives verdict, rank and the category labels.
  - Never call any Set*/Add*/Clear* on a button: each Set/Add re-runs ApplyAuraInstance (research notes :31-33).

`Diag.Build()` adds the begin marker and the sections, then `truncated: N` if `dropped > 0`, then the end marker with the count. It returns out.

`Diag.Run()`:
- If `not lib`, `NS.Printf(L["%s, so the diagnostic report is unavailable."], NS.LIBKA0S_MISSING)` and return 0.
- Otherwise `Build`, then `NS.DebugLog:Add(tag, line)` per line.
- Show the console if `not NS.DebugLog:IsShown()`.
- `NS.Printf(L["Diagnostic report written to the debug console: %s lines. Use Copy to share it."], n)`.
- Return n.
- Read-only: no settings writes, no RequestApply, no change to NS.State.debug.

**2. `settings/Slash.lua`.**
- runDebug: `if word == "diag" then NS.Diagnostics.Run() return end` goes first.
- Help key at :78: `L["Toggle the debug console - on/off enable or disable logging, diag writes a diagnostic report"]`.
- Publish `Sl.FormatValue = formatValue` after :452. Diagnostics must `plain()` it.

**3. `modules/ContainerManager.lua`.** `function CM.QueueSnapshot()` returns `{ all = pendingAll, ids = sortedCopy(pending), idSet = copy(pending), scheduled = scheduled, notice = shownReason, mustDefer = CM.MustDefer() }`. It is read-only and never exposes the live tables.

**4. `settings/Schema.lua`.** `NS.RowApplies = rowApplies` after :355.

**5. Locale (enUS.lua)**, ASCII apart from the em dash:
- Replace the :412 key with the new help key. Delete the old one, or test_locale fails on an unused key.
- Add "Diagnostic report written to the debug console: %s lines. Use Copy to share it."
- Add "%s, so the diagnostic report is unavailable."

**6. TOC.** `modules\Diagnostics.lua` after `modules\ContainerManager.lua`. Everything is read at call time, so the position is conventional.

**7. Docs.**
- New docs/debug.md: purpose, the tag vocabulary, an example, what `predicted`, `id=?`, `shown=?`, PENDING and DRIFT mean, the secret rules, the caps, and that the report appends to (and may evict) the existing log.
- ARCHITECTURE.md:46 file counts (49->50, 14->15 modules), :161 `/am debug [on|off|diag]`, :284 debug.md Present.
- slash-dispatch.md row 20; module-map.md; smoke-tests.md; regenerate test-cases.md.

**NO DB MIGRATION.**

### Tests

- NEW tests/test_diagnostics.lua, added to the explicit suite list in tests/run.lua (Kit.run asserts the inventory). It installs mocks.C_UnitAuras as tests/test_timedspells.lua:10 does and sets mocks.__unitExists for units.
- The debug flag OFF, then `/am debug diag`: NS.DebugLog.buffer gains lines from `[Diag] ==== Aura Master diagnostic begin` through `==== end: N line(s)`, the window is shown, NS.State.debug stays false, and one chat line carries N. Red under routing through the gated NS.Debug.
- Regression on branch order: bare `/am debug` still toggles only the window, and `/am debug on`/`off`/`ON` still flip the flag (extend test_slash_verbs.lua:538-552). `/am debug DIAG` runs the diagnostic (firstWord lowercases).
- A C_UnitAuras mock serving two player buffs and one debuff: [Aura] lines carry inst=, id=, the quoted name, dispel=, src=, dur=, left=, stacks=, and the HELPFUL/HARMFUL [Unit] headers show the right counts.
- An aura whose duration, expirationTime and spellId are mocks.__SECRET (issecretvalue planted): renders `<secret>` and `left=-`, raises nothing, and the predicted list skips it. Red under arithmetic or format on a raw field.
- mocks.__aurasSecret = true: one `unreadable` line per existing unit, and a spy counts 0 GetAuraDataByIndex calls. [Shown] prints its skipped line and calls no IsShown on seeded frames (a spy frame whose IsShown errors stays untouched).
- GetAuraDataByIndex raising: a `read failed` line, and the container sections still land.
- UnitExists false for target, focus and pet: `[Unit] target: none` and so on. A pet with auras is dumped when __unitExists.pet is set.
- Every container in display order gets a [Cont] line and a full [Filt] block, with the whitelist and blacklist sorted and named. bars.width changed shows under [Cfg] non-default; untouched rows are absent. A color row prints with no `|c` escape in the buffer (red under raw formatValue).
- An auraTypes-scoped row is not listed for a HARMFUL container (NS.RowApplies).
- Plan verdicts: after a clean apply, `plan in sync`. With __aurasSecret = true and a SetByPath on container.filter.castBy (queued), `PENDING`, with QueueSnapshot listing the id. Mutating c.filter directly with no RequestApply gives `DRIFT`. An instance with plan=nil gives `not built`.
- [Plan] groups report frames= and shown= from engine.__frames (two shown, one hidden). `frames=?` when GetAuraGroupFrameCount is rawset to error (the test_container.lua pattern).
- [Shown] identity: a frame with GetAuraInstanceID returns the id; a frame with only __am.name uses its GetText; a bare frame prints `id=?`. Predicted: a whitelisted id reads `shown (rank 1`, a blacklisted id `hidden (rank 2`.
- Size cap: 60 containers plus 4x100 auras gives at most MAX_LINES lines plus the `truncated:` line, and the begin marker is still in D:CopyText().
- Section isolation: a container whose filter is a string prints `section ... failed`, and the next container still reports.
- Disabled addon: `/am disable` then `/am debug diag` gives no refusal, and the state line reads enabled=false stoodDown=true. Add `debug diag` to test_slash_verbs.lua:810's must-never-be-refused list.
- Degraded env (tests/degraded_env.lua, LibKa0s absent): diag prints the unavailable line and raises nothing.
- QueueSnapshot returns copies: mutating the returned ids does not change the pending queue.
- test_locale, test_docs, test_loadorder and test_lintconfig stay green: new keys used, old key removed, TOC entry covered, doc file:line citations valid, and no bare UnitExists/GetBuildInfo global.

### Smoke

- Out of combat with a target, a focus and a pet: `/am debug diag`. The console opens, chat reports N lines, and the [Aura] names and stacks match the default buff and debuff frames.
- Copy: the copy window starts at the begin marker and ends at the end marker, with no `|c` color codes. Paste it into a file and check nothing is cut off.
- In combat on a dummy: `/am debug diag` gives no Lua error (BugSack clean). Units read unreadable, [Cont]/[Filt]/[Plan] still print, frames= are numbers or `?`, shown=?, and [Shown] is skipped.
- Change castBy in combat: diag shows PENDING (combat) for that container. After combat, diag shows `plan in sync`.
- Whitelist a spell while its buff is up: [Shown] lists a button and predicted reads shown (rank 1). RECORD whether identify resolves inst/id (GetAuraInstance reachable) or only name/icon. This answers the open engine question.
- `/am disable` then `/am debug diag`: runs, and the state line reads enabled=false.
- About 8 containers and a long whitelist: under the cap, or ends with a truncation line; the console line counter stays at or under 1500.
- Bare `/am debug` still toggles the window, `/am debug on`/`off` still flip logging, and `/am help` shows the new description.

Needs migration: False

### Risks

- CHANGED vs the prior record: the plan comparison needs no label stripping. Plan group labels are the raw, deterministic def.label (FilterCompiler.lua:566-575,637-641), and both plans come from the same pure Compile. Stripping would only add code.
- CHANGED: the staleness verdict now combines the queue with the plan comparison, giving PENDING, DRIFT, in-sync or not-built. The prior 'matches settings' wording implied every setting was applied. The plan covers filters only: a deferred bars.width change would still read 'matches'. DRIFT (plan differs, nothing queued) is the case that points at a real apply-path bug.
- CHANGED: Region:IsShown and other button-object calls raise in combat (midnight-quirks.md:169-171). While secret, [Shown] makes no per-button calls and prints shown=?, and GetAuraGroupFrameCount is the only engine call. pcall alone would work, but it would spam caught errors and possibly taint-log.
- CHANGED: the pet unit is included by default (C.UNITS, core/Constants.lua:39), since pet containers are supported. The prior record left it as an open question.
- CHANGED: formatValue (Slash.lua:440-452) emits color escapes. Diagnostics must strip `|cXXXXXXXX`, `|r` and `|T..|t`, or the Copy text is polluted, because FormatPlain does no stripping (DebugLog.lua:125).
- CHANGED: .luacheckrc has no UnitExists or GetBuildInfo, and test_lintconfig keeps read_globals exact. Read them through `_G.` as TimedSpells does with `_G.C_UnitAuras`.
- CHANGED: the default recommendation is now a LOCAL pcall'd aura reader rather than a new Compat shim. It matches the TimedSpells precedent and avoids compat-count doc churn (21->22). The shim remains an open question.
- CHANGED: corrected the research-notes citation to docs/superpowers/research/2026-09-13-aura-engine-notes.md:46-47,75. The prior :594-596 and :71 were Blizzard source line numbers quoted inside the notes.
- CHANGED: noted that the wow_mock has no C_UnitAuras by default. Tests must install it (test_timedspells.lua:10) and use mocks.__unitExists (tests/_kit/mock_base.lua:1078).
- CHANGED: add() pre-stringifies every argument, so format strings must use %s only. %d or %.1f against a SafeToString'd arg raises (the same trap DebugLog.lua:661-667 documents). Numeric formatting happens before add, and only on values IsReadableNumber has confirmed.
- Aura identity inside a container may be unobtainable. GetAuraInstance sits on a private mixin, and initializeFrame receives GetObjectTable(). Expect `id=?` with name only for bars and text containers, and icon only for icon containers. Promise only what the smoke probe confirms.
- The predicted verdict is approximate (ExplainSpell: spells-kind categories only). castBy, duration, token/flag/dispel categories and the friend/foe id rule are the engine's. Label it `predicted` everywhere.
- Buffer eviction: a report of about 1000 lines evicts earlier trace lines. It appends by design, and docs/debug.md says so.
- Cost: about 1000 Add calls, each running AddMessage, UpdateScrollBar and UpdateStatus, so a one-shot hitch of a few ms. Acceptable for an explicit command.
- Privacy: spell ids and unit tokens only; no character, target or focus names in the header.
- Doc drift: ARCHITECTURE.md:46 file and module counts, :161, :284; slash-dispatch row 20; module-map; test-cases regeneration. test_docs fails until they match.
- Locale: remove the old :412 help key when adding the new one, and keep new keys ASCII apart from the em dash.
- Lizard CCN 15: split per section and per helper; one monolithic Build would breach the gate.

### Open questions (as raised)

- Body-line language: unrouted English, like every existing NS.Debug trace and the [Init] summary, since the lines are pasted back to the author. Acceptable, or should every body format route through NS.L?
- Scope: is a `/am debug diag <container id|name>` variant wanted, to fit a full non-filter dump for one container under the 1500-line cap? Or a `full` flag?
- Clear the console before writing (a clean paste, but it loses the user's reproduction trace) or append (the proposal)?
- Compat shim: add Compat.UnitAuraList (a 22nd shim, documented in compat-layer.md; TimedSpells could adopt it later) or keep the reader local to Diagnostics as TimedSpells does (the proposal)?
