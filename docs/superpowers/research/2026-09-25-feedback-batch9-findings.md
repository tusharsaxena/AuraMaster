# Feedback batch 9: investigation findings and anchor-point design

Read-only investigation, 2026-09-25, of the owner's batch-8 smoke feedback. Each item had one investigator and one adversarial critic, and one agent drafted the design. The spec (`../specs/2026-09-25-feedback-batch9-design.md`) records the owner's rulings and wins where the two differ.

## Problem A: "Anchoring is not working correctly." While unlocked, followers in an attached chain sit in the wrong place: Player Weapon Enchants attached to Player Buffs (All), the Text Offensive -> Defensive -> Raid chain, and Target Debuffs (Mine) attached to Target Buffs (Mine) growing up.

### Root cause

I confirmed the other agent's diagnosis. Three parts of it need correcting: which requirement is at fault, whether its proposed fix can work, and how GetAuraGroupFrameCount behaves.

1) A REAL POSITIONAL BUG. This is what screenshot 30 shows. It is a conflict inside the batch-8 spec that B8-P6 (3c23d2e) implemented exactly as written.
- EO-1 (spec :74) says: "When a parent is unlocked and not previewing, its followers hang from the parent's anchor, which is exactly one element." This is unconditional as written, not a scoping slip in the code.
- SS-3 (spec :68) says: "The seam must be identical locked, unlocked and in test mode."
- The two cannot both hold once the parent has 2 or more auras. P6 chose EO-1 and wrote the SS-3 breakage down as a known limitation (docs/known-limitations.md:207-219, smoke 192). What the owner reported is exactly that documented case.
- The mechanism:
  - hangModeFor (modules/Container.lua:531-534) returns "slot" whenever the container is unlocked and not previewing. It never looks at what the container holds. ApplyVisibility stores the result at :565, then calls Anchors.PlaceAttached.
  - Anchors.targetFor (modules/Anchors.lua:106) then returns target.anchor instead of target.engine. The anchor is the parent's first element.
  - DerivedPoints for a bars parent growing down gives TOPLEFT -> BOTTOMLEFT.
  - The seam is 0: the child's layout.spacing is 0, attach.y is 0, and stripRoom is 0 because #1 is a screen root.
  - So the Weapon Enchants slot lands exactly on the parent's 2nd bar.
- Pixel check on shot 30:
  - Parent bars are at about y 48-66 (Sign of the Skirmisher), 66-85 (Ophidian Maw), 85-104 (Devotion Aura) and so on.
  - The child strip is at about y 66-86. That is level with bar 2 (Ophidian Maw), not bar 1 as the owner described it. Its right edge is about 2px left of the bars.
  - This fits StripPoints' beside branch: the strip's TOPRIGHT sits on the child anchor's TOPLEFT at x = -STRIP_GAP.
  - The child's faint outline sits under the opaque bar 2, which is why no outline is visible.
- With auras present, while unlocked and not in test mode:
  - The child's first aura draws over the parent's 2nd aura, and the parent's 2nd to Nth auras draw under the child.
  - Growth-up chains (#10/#11) behave the same way, mirrored: the parent's later auras grow up into the child.
  - Locked, the child sits one spacing past the parent's LAST aura, which is correct.
  - In test mode ("preview") it hangs past the placeholder block, which is also correct.

2) EXPECTED LAYOUT THAT LOOKS WRONG (shots 31 and 32, both chains empty). The geometry there is as designed.
- Shot 31:
  - Offensive: strip above at about y 10-30, outline from y 30.
  - Defensive: outline from about y 57, with its strip beside it at the same height, ending about x 300.
  - Raid: outline from about y 80, a few px more because of the EO-2 clearStrip, with its strip beside it.
  - No strips overlap.
- Shot 32:
  - Parent Target Buffs, growing up: its outline is at about y 50-68 and its strip is below it at y 70-90. A root's strip goes below its block when the block grows up.
  - The child's outline is directly above, at about y 30-48, with its strip beside it at the same height.
- "Handle to the left" is how it is meant to look:
  - B8-P5 (c9caf26, besideSeam and StripPoints) moved a FOLLOWER's strip beside its first element. SS-3 asked for this so the strip would not cover the parent's last aura.
  - B8-P10 (a945c09) put the name label in the same spot and pushes the strip further out past it (labelPush).
- Beside placement makes shot 30 look worse, but it does not cause the bug.

3) CORRECTIONS TO THE OTHER AGENT'S FIX.
- Its main proposal is a "provably empty" check built on GetAuraGroupFrameCount. That is very probably not viable. The addon's own code treats this count as the number of buttons the engine has CREATED, a pool that does not shrink:
  - ContainerClass:Restyle (modules/Container.lua:326-339) documents it as "every button the engine has created" and re-dresses them all.
  - Diagnostics.frameCounts (modules/Diagnostics.lua:456-468) reports frames= and shown= separately, precisely because the count includes frames that are not shown.
- The only way to tell which pooled frames are live is frame:IsShown(). The owner's report shows that this returns a SECRET boolean, even out of combat with aurasSecret=false. That is the Diagnostics.lua:453 crash.
- So once a parent has ever held an aura, its emptiness is not provable. known-limitations.md:214-216 already records that following the live count was considered and rejected: geometry can read secret, and re-anchoring on count changes is illegal under lockdown.
- The only emptiness that can be proven is "the engine has created 0 frames". That covers a freshly built, never-populated parent, which is exactly the #9 empty-chain screenshot case. It does not cover a parent that has been emptied.

4) DIAGNOSTICS BUG ALONGSIDE THIS.
- modules/Diagnostics.lua:451-454 frameShown does `v == true` on a secret boolean. B8-P11 (1e3c29d) introduced it.
- Every "section plan" and "section shown" failed because of it, which hid the frames= counts.

### Evidence

- modules/Container.lua:531-534 (blame 3c23d2e, B8-P6): hangModeFor returns "slot" whenever unlocked and not previewing, regardless of what the container holds. It is stored at :565, then Anchors.PlaceAttached(self) runs at :566
- modules/Anchors.lua:104-107 (blame 3c23d2e): mode "slot" returns target.anchor (one element, the parent's first aura) instead of target.engine. The HangMode doc comment is at :85-97
- git log -S'"slot"' -- modules/ returns only 3c23d2e 'B8-P6: Empty unlocked containers hang from the parent's one-element slot'
- docs/superpowers/specs/2026-09-25-feedback-batch8-design.md:68 SS-3 (seam identical locked/unlocked/test) vs :74 EO-1 (unconditionally 'When a parent is unlocked and not previewing, its followers hang from the parent's anchor'). The two requirements contradict each other for any parent holding 2 or more auras
- docs/known-limitations.md:207-219 and docs/smoke-tests.md:1183-1187 (check 192) describe the owner's shot 30 exactly: 'Unlock with A holding two or more auras -> B moves up to one element past A's first aura, and A's later auras draw under B (known limitation)'. known-limitations :214-216 also records that following the live count was rejected
- Shot 30 pixel check: parent bar 1 at about y48-66, bar 2 (Ophidian Maw) at 66-85. The child strip is at about y66-86, with its right edge about 2px left of the bars. This matches slot hang (TOPLEFT->BOTTOMLEFT of the parent anchor, seam 0 from spacing=0 and attach.y=0) plus the StripPoints beside branch (TOPRIGHT->TOPLEFT, x=-STRIP_GAP). The handle is level with bar 2, not bar 1 as the owner described it
- Shot 31: Offensive strip at about y10-30 above its outline. Defensive outline and strip at about y57-78, Raid at about y80-101 (the extra px is the EO-2 clearStrip). The strips end at about x300, left of the outlines at about x305-663. No overlap, as designed (smoke 191)
- Shot 32: parent (growV=up) outline at about y50-68 with its root strip below at y70-90, child outline directly above at about y30-48 with its strip beside it at the same height. Correct for an empty growth-up chain
- modules/Container.lua:326-339 Restyle: GetAuraGroupFrameCount is iterated as 'every button the engine has created', which means pool size, not live count
- modules/Diagnostics.lua:456-468 frameCounts reports frames= and shown= separately, and shown needs IsShown on each frame. modules/Diagnostics.lua:451-454 frameShown does `v == true` on IsShown's secret boolean (added by 1e3c29d, B8-P11). This is the ':453 attempt to compare a secret boolean' failure in the report, seen out of combat with aurasSecret=false, so a frame's shown state is unreadable even outside combat
- c9caf26 (B8-P5) put a follower's strip beside its first element (Anchors StripPoints/besideSeam), and a945c09 (B8-P10) added the name label there plus labelPush. Together they explain why every child handle reads as 'attached to the left'
- Diagnostics header testMode=true at 20:04, but the screenshots are described as test mode off. The shots show slot geometry (unlocked, not previewing), so they were taken outside test mode, at a different time from that header line

Introduced by: 3c23d2e (B8-P6, 'Empty unlocked containers hang from the parent's one-element slot') introduced the positional regression, at modules/Container.lua:531-534 and modules/Anchors.lua:104-107. It implements spec EO-1 exactly as written, which conflicts with SS-3; the same commit records the breakage as a known limitation. c9caf26 (B8-P5, the follower strip beside its first element) and a945c09 (B8-P10, the name label and labelPush) make every child handle read as 'anchored to the left'. 1e3c29d (B8-P11) introduced the separate Diagnostics.lua:453 secret-boolean compare.

### Fix

This is a spec conflict (EO-1 vs SS-3). It needs an owner decision before any code changes. My recommendation, in order:

A) Recommended: SS-3 wins, and 'slot' is kept only for a parent that provably has never shown an aura.
   - hangModeFor(previewing, unlocked, pristine) returns "slot" only when unlocked AND pristine. Otherwise it returns engine, or preview in test mode.
   - pristine means: out of combat, and the sum over self.plan.groups of pcall(engine.GetAuraGroupFrameCount) is a readable number equal to 0, and there are no shown enchant frames (the plan has no enchant slots, or #self.enchantFrames == 0).
   - Any unreadable or secret value, or combat lockdown, gives false, which means engine.
   - Do NOT call IsShown or read geometry.
   - Once the engine creates its first frame, the container is never pristine again (the pool does not shrink). A populated parent then always hangs from its engine, so its seam is identical locked and unlocked.
   - The effect of the pristine check:
     - An empty chain that has never held an aura keeps the #9 fix (shot 31 layout).
     - A parent that has held auras and gone empty falls back to the 1x1 engine: its follower sits about 5px under the parent's top, which is the old #9 look for that case only.
   - Re-check the mode when the parent creates its first frame:
     - Hook the plan's initializeFrame callback. It already runs once per created button in Style; only the first creation per container matters.
     - Out of combat, and only while unlocked, re-run the hang-mode update and PlaceAttached.
     - The PlaceAttached memo on (mode, room) keeps repeat passes free.
     - In combat, defer to the existing PLAYER_REGEN_ENABLED re-pass.
   - Before building this, spike in game with /dump: confirm GetAuraGroupFrameCount is 0 before any aura and does not drop back after the last aura leaves (pool semantics).

B) Minimal: drop 'slot' entirely.
   - hangModeFor returns "engine" whenever not previewing, the pre-P6 behaviour.
   - Unlocked then matches locked exactly (SS-3). Empty unlocked chains collapse again (#9), and the owner uses /am test to lay chains out, where the preview extent is correct.

The other agent proposed re-evaluating on UNIT_AURA churn from a live count. Drop that idea: the count is pool size and IsShown is secret, so the live count cannot be read (known-limitations :214-216).

Whichever option ships, update:
- spec EO-1: add the pristine condition, or retire EO-1
- docs/known-limitations.md:207-219: narrow the entry to 'a parent emptied after holding auras', or remove it for B
- docs/smoke-tests.md checks 191-193
- the Anchors.lua:85-97 HangMode doc comment
- the Container.lua:529-530 comment

Optional, owner's call: a follower's strip beside its first element (P5/P10) reads as 'attached to the left'. Keep it or move it; this is independent of correctness.

Separate commit: modules/Diagnostics.lua:451-454. Test the IsShown result with NS.Secrets.CanAccess or issecretvalue before comparing it. Return nil ('?') when it is secret, and make frameCounts print shown='?' when any frame's state is secret.

### Tests

- tests/test_anchors_hang.lua: new test. Unlocked, not previewing, parent engine stub GetAuraGroupFrameCount returns 3: the follower hangs from target.engine with the same point, relativePoint and offsets as when locked (SS-3 identity), for a growV=down bars parent and a growV=up parent
- tests/test_anchors_hang.lua: keep :50/:61 as they are for a parent whose every group count is readable 0 and which has no enchant frames: it hangs from target.anchor (slot)
- tests/test_anchors_hang.lua: new test. A count that errors (pcall false) or is secret (Secrets stub) answers engine, never slot
- tests/test_anchors_hang.lua: new test. A parent whose plan has enchant slots with enchantFrames present answers engine
- tests/test_anchors_hang.lua: new test. Unlocked, out of combat, the parent's first initializeFrame call (count 0 -> 1) re-places the follower from anchor to engine. A second created frame re-places nothing (memo)
- tests/test_anchors_hang.lua: new test. The first frame created under combat lockdown re-places nothing. The PLAYER_REGEN_ENABLED pass then moves the follower to the engine
- tests/test_anchors_hang.lua: keep :70 (lock/unlock re-target), :100 (lockdown), :151 (empty Text chain strips never overlap) and :185 (test-mode room) green
- For option B instead: change :50/:61 to expect target.engine while unlocked, and add a test that unlocked placement equals locked placement for down, up and icons chains
- tests/test_diagnostics.lua: new test. An IsShown stub that returns a secret boolean (Secrets stub) gives shown='?' and the 'plan' and 'shown' sections complete without error
- Green gate: lua tests/run.lua all pass, luacheck . 0 warnings/0 errors, lizard CCN <= 15 for hangModeFor, the pristine helper and frameShown

### Smoke

- Before coding (spike): /dump the parent engine's GetAuraGroupFrameCount for Player Buffs (All) at login with no buffs, then with 5 buffs, then after clicking them all off. Expect 0, then >= 5, then unchanged (pool). This decides between option A and option B
- Shot-30 repro: Player Buffs (All) with 5 buffs, Player Weapon Enchants attached, test mode off, /am unlock. The Weapon Enchants outline, and its bar when an enchant is applied, sits directly under Encapsulated Destiny (the last bar) with 0 gap. Its strip is beside that slot, not level with Ophidian Maw, and no parent bar is covered
- /am lock and /am unlock on the same setup: the follower does not move (SS-3)
- Growth-up (shot 32): the target has 3+ of your buffs, /am unlock. Target Debuffs (Mine) sits above the TOP-most Target Buffs bar and stays there on /am lock
- Empty Text chain (shot 31) right after /reload, never populated, unlocked, test mode off: outlines one Spacing apart, strips beside them, no overlap (smoke 191, option A). With option B, expect the chain to collapse and check /am test lays it out correctly
- Option A: give Offensive a matching aura, then remove it while unlocked. The follower moves to the engine on the first aura, and after the aura leaves it sits about 5px under Offensive's top (documented residual). No Lua error
- /am test with every chain: followers start past the parent's placeholder block (smoke 193)
- Combat: unlocked, enter combat, gain the parent's first aura, /am lock and /am unlock. Nothing re-anchors in combat, no ADDON_ACTION_BLOCKED or taint. Leaving combat snaps the followers correctly (smoke 196)
- /am diagnostics out of combat: no 'section plan/shown failed ... Diagnostics.lua:453' lines, and each group reports frames=N shown=? (or a number where readable)

### Open questions (as raised)

- Does GetAuraGroupFrameCount report pool size (never shrinks) or active frames? The code (Restyle 'every button the engine has created', and frameCounts reporting frames and shown separately) strongly suggests pool size. That rules out the other agent's 'provably empty' live-count fix and leaves only 'never populated' (option A) or dropping slot (option B). Confirm in game with /dump
- Owner decision on the EO-1 vs SS-3 conflict: option A (slot only while a parent has never created a frame; an emptied parent's follower sits about 5px under the parent's top) or option B (engine always when not in test mode; empty unlocked chains collapse again, use /am test to lay them out)
- Owner decision: keep a follower's strip and label beside its first element (P5/P10) or move them. This is the main reason shots 31 and 32 read as 'anchored left' although their geometry is correct
- Which state was each screenshot taken in? The diagnostics header says testMode=true, but the shots show slot (non-preview) geometry, so they were taken at a different time from that report
- Not in scope, but worth a look: text containers #13-#15 show no text.autoSize override (template default true) while bars #1/#5 list autoSize=false. That suggests the v8 AS stamp applied to the wrong containers, and would explain the identical ~360px outline widths in shot 31 despite text.width 100/300
- The vertical guide line at about x490 through the shot-31 outlines has not been traced to code (possibly an alignment grid or another addon)

## Problem B: in test mode, anchored (container-attach) children look as if their placeholders are drawn in the parent

### Root cause

Verified. The other agent's conclusion holds, with some corrections to line numbers and details. The child's placeholders belong to the child and sit where the spec puts them: one child-spacing (0 here) past the parent's whole preview block. The child's strip is also where SS-3 puts it. Nothing renders in or with the parent. The owner is seeing a loss of visual separation, and three things combine to cause it:

(1) The seam is now the child's own spacing, which is 0 here. Anchors.SeamOffset (modules/Anchors.lua:196-200) returns y = -spacing when growing down and +spacing when growing up. #5 and #11 both have layout.spacing=0, so the gap is 0. The same commit, c9caf26 (B8-P5), moved the template's attach.y from -4 to 0. Its MigrateV8 also reset stored 0/-4 to 0/0 on container-mode containers. That silently removed the 4px gap the owner's profile used to have. The diag agrees: #5 lists no attach.y (so it is 0), while the screen-attached #1 still shows attach.y=-4 as non-default. Bars are a column axis, so the child already stacked vertically before batch 8 (B8-P4 565fc38 changed only row parents). The difference is that the child now butts flush with the parent: same bar height, same texture, no gap. It reads as one taller container.

(2) The follower strip moved beside the block. besideSeam (Anchors.lua:565-567, c9caf26) and StripPoints (Anchors.lua:598-609) put a follower's strip to the left of its first element. Growing down, that is TOPRIGHT->TOPLEFT; growing up, BOTTOMRIGHT->BOTTOMLEFT; x = -STRIP_GAP. Before P5 the strip sat across the seam and acted as a divider (feedback #13 asked to remove that because it covered the parent's last aura). stripRoom (Anchors.lua:588-592, B8-P6 3c23d2e) adds nothing here, because a root parent's strip is not beside the seam.

(3) Test mode draws no boundary per container. ApplyOutline is gated `unlocked and not previewing` (modules/Container.lua:561). That gate came from f7af87b; 3c23d2e only touched nearby lines. On top of that, Preview.AurasFor (modules/Preview.lua:77-79) keys only on cfg.auraType. So a weapon-enchant child of a HELPFUL parent previews the same HELPFUL names (Power Word: Fortitude, Bloodlust, Shield Wall...) directly under the parent's, and a text child repeats its parent's names too.

Checked against the screenshots:
- 35 (growV=up): parent strip at the bottom (y~229). Parent bars run from Power Word: Fortitude (y~209) up to Well Fed (y~131). The child's first element, Shadow Word: Pain (y~111), is flush on top, and the child's HARMFUL set continues up to Mortal Wounds. The child strip spans y~101-120, bottom-aligned with Shadow Word: Pain and left of it. That matches BOTTOMRIGHT->BOTTOMLEFT exactly. The dispel tints (poison green, disease brown, curse purple, magic blue, bleed red) come from the HARMFUL set, which the HELPFUL parent #10 cannot render, so these are #11's frames.
- 36: 5 blue parent bars (y~34-133), then purple child bars starting flush at y~134. The child strip is top-aligned with the first purple bar, to its left. Correction to the other agent: only 3 purple bars are visible because the image is cropped. placeholderCount (Preview.lua:141-153) clamps an enchant-only container to its enchant slot count (at most 3: mainHand/offHand/ranged), so the child probably has 3 bars, not 5.
- 37: the parent is autosized to about 320px wide; the #14 and #15 strips' right edges sit at about x=315, just left of the parent's left edge. Each child's lines use its own color and size, and #15 autosizes to about 220px. Consistent with the same mechanism.

Separate defect found in the same report: modules/Diagnostics.lua:451-454, frameShown. The pcall covers IsShown, but `v == true` runs outside the pcall. On a secret boolean that compare raises, so every engine-backed container reports 'section plan/shown #N failed'. #5 printed its [Shown] lines, most likely because as an enchant-only container it has no aura group whose buttons frameShown reads (not traced end to end). Introduced by 1e3c29d (B8-P11).

### Evidence

- modules/Anchors.lua:196-200 Anchors.SeamOffset: gap = spacing (vertical axis) or lineSpacing, max(0,...), growth-signed. With spacing=0, y=0. git log -S 'function Anchors.SeamOffset' -> c9caf26 (B8-P5)
- modules/Anchors.lua:248-257 attachSpec: container mode = DerivedPoints + SeamOffset + clearStrip + stored attach.x/y nudge. c9caf26 changed defaults/Profile.lua attach.y from -4 to 0 and added Database.MigrateV8, which resets 0/-4 to 0/0 on container-mode containers (commit diff lines: V8_OLD_X, V8_OLD_Y = 0, -4)
- Diag: #5 (attach=container#1) lists no attach.y override, so the seam is 0 + 0; #1 (screen) still lists attach.y=-4, confirming the old default was -4 and the template is now 0
- modules/Anchors.lua:182-186 DerivedPoints: TOP{H}->BOTTOM{H} growing down, BOTTOM{H}->TOP{H} growing up. B8-P4 (565fc38) changed only row parents, so the bar column chains in 35/36 stacked vertically before batch 8 as well
- modules/Anchors.lua:100-110 targetFor: HangMode 'preview' puts the child on target.previewExtent. modules/Container.lua:564-568 sets hangMode after Preview.Show and before PlaceAttached, so the ordering is correct
- modules/Preview.lua:195-219 Preview.Extent: extent at the parent's corner, sized farX+w by farY+h over all placeholders, so the child starts past the parent's last placeholder
- modules/Preview.lua:180 each placeholder: f:SetPoint(point, container.anchor, point, x, y), anchored to the CHILD's own anchor. The factory parents it to container.anchor (Preview.lua:176)
- modules/Anchors.lua:565-567 besideSeam (c9caf26) and 598-609 StripPoints: a follower's strip goes beside its first element (TOPRIGHT->TOPLEFT down, BOTTOMRIGHT->BOTTOMLEFT up, x=-STRIP_GAP). The other agent's 476-478 line citation was wrong
- modules/Anchors.lua:588-592 stripRoom (3c23d2e B8-P6) returns 0 when the target is a root (besideSeam(parent)=false), so clearStrip adds nothing for #1->#5 or #10->#11
- modules/Container.lua:468-487 ApplyOutline draws one element at the flow corner; Container.lua:561 calls it with `unlocked and not previewing`, so test mode has no outline. That gate comes from f7af87b; 3c23d2e only touched adjacent lines
- modules/Preview.lua:77-79 AurasFor keys only on cfg.auraType; core/Constants.lua:275-291 has only HELPFUL/HARMFUL sets. modules/Style_Text.lua:757 uses the same lookup. So an enchant-only child previews buff names
- modules/Preview.lua:141-153 placeholderCount clamps an enchant-only container (plan.enchants and no groups) to #plan.enchants.slots (<=3; defaults/Profile.lua:57 enchantSlots), so #5 likely draws 3 bars, not 5. Screenshot 36 is cropped after 3
- Screenshot 35 pixel check: child strip y~101-120 vs Shadow Word: Pain bar y~102-121, strip right edge ~285 vs bar left ~288 (STRIP_GAP). Parent's top bar Well Fed y~131 is flush with Shadow Word: Pain's bottom (0 seam)
- Screenshot 36 pixel check: parent's last bar Well Fed ends y~133, first purple bar starts y~134 (0 seam). Child strip top-aligned with the first purple bar, left of it
- Spec docs/superpowers/specs/2026-09-25-feedback-batch8-design.md:66-68 SS-1..SS-3: the seam is the child's spacing and must be identical locked, unlocked and in test mode, and the strip must not cover the parent's last aura. The behaviour matches the spec; the spec left out visual separation at spacing 0
- modules/Diagnostics.lua:451-454 frameShown: `local ok, v = pcall(frame.IsShown, frame); return ok and v == true`. The compare is outside the pcall and raises on a secret boolean. Callers are at :466 (frameCounts, plan section) and :559 (groupButtons, shown section). git log -S -> 1e3c29d (B8-P11)

Introduced by: c9caf26 (B8-P5, "The seam to an attached container is the child's own spacing"): SeamOffset gives 0 at spacing 0, the template attach.y went from -4 to 0 and MigrateV8 zeroed the stored 0/-4, and besideSeam moved the follower strip off the seam. These are the visible regressions. Contributing factors that predate batch 8 or are separate: the outline is gated off in test mode (Container.lua:561, from f7af87b), and preview samples keyed only by auraType (TD-1, B8 preview work) make an enchant or text child repeat the parent's buff names. The diagnostics secret compare that blocked confirmation comes from 1e3c29d (B8-P11).

### Fix

Keep the seam and DerivedPoints as they are: SS-1 and SS-3 are met, and changing the seam in test mode only would break SS-3. The fix is to make each container's block separable.

1. Primary, and it moves nothing: draw each container's outline around its whole placeholder block in test mode. Change Container.lua:561 to `self:ApplyOutline(cfg, unlocked, previewing)`. In ApplyOutline (Container.lua:468-487), when previewing and self.previewExtent exist, call o:SetAllPoints(self.previewExtent) instead of the one-element size. Keep the one-element slot outline when not previewing, and hide it when locked. ApplyVisibility calls Preview.Show before ApplyOutline, so the extent has already been sized. A slightly stronger alpha in test mode is optional. The outline is not an attach target, so no follower needs to be re-placed. It must not allocate after the frame is first created (perf).

2. Weapon-enchant preview set: add C.PREVIEW_AURAS.ENCHANT (for example Windfury Weapon, Flametongue Weapon, Instant Poison, a sharpening stone) in core/Constants.lua. Make Preview.AurasFor choose it when the compiled plan has enchants and no aura groups; placeholderCount already compiles the plan, so pass it in or cache it. Mirror this at Style_Text.lua:757. This fixes a Weapon Enchants container showing Power Word: Fortitude.

3. Optional: once (1) is in, the beside strip touches the child's box, which ties them together visually. Do not put the strip back on the seam (feedback #13).

User workaround now: set the child's Y offset on the Layout page to -4 (growing down) or +4 (growing up), or give the child a non-zero Spacing. That restores a visible gap in every mode (SS-2).

4. Diagnostics (separate, B8-P11): change Diagnostics.lua:451-454 to `local ok, v = pcall(frame.IsShown, frame); if not ok or NS.Secrets.IsSecret(v) then return false end; return v == true`. Report a secret as '?' in the counts. Audit the other pcall'd frame reads in Diagnostics.lua that compare their result outside the pcall.

### Tests

- tests/test_anchors_seam.lua: test mode, column parent growing down, parent and child spacing 0. The child anchor SetPoint is ('TOPLEFT', parent.previewExtent, 'BOTTOMLEFT', 0, 0), and every child placeholder's SetPoint relative frame is the child's anchor, never the parent's
- tests/test_anchors_seam.lua: same with growV=up. ('BOTTOMLEFT', parent.previewExtent, 'TOPLEFT', 0, 0), and the child strip is BOTTOMRIGHT->BOTTOMLEFT of the child anchor at x=-STRIP_GAP
- Container outline test: unlocked plus test mode, the outline is shown and SetAllPoints'd to previewExtent. Unlocked without test mode, the one-element slot outline. Locked, hidden. Toggling test mode does not call Anchors.Place on followers, and the child anchor offsets are equal across locked, unlocked and test (SS-3 identity)
- Preview.AurasFor test: an enchant-only container (plan.enchants, no groups) gets the ENCHANT set, capped to its slot count. HARMFUL gets debuffs, HELPFUL buffs, unknown HELPFUL. Style_Text measuring uses the same set
- Diagnostics test: IsShown stubbed to return a kit secret boolean. frameShown returns false (or the count shows '?') without raising, and the 'section plan' and 'section shown' pcalls no longer report failure
- Full battery: luacheck, headless harness, tests/perf.lua (the visibility pass does not allocate after the first outline), lizard with no function above CCN 15

### Smoke

- /am test, unlocked: Player Buffs (All) with Player Weapon Enchants attached, both spacing 0. Each container shows its own faint box around its placeholder block. The child box starts exactly at the parent box's bottom edge, and the child strip sits left of the child box's top, touching it
- Target Buffs (Mine) growV=up with Target Debuffs (Mine): the debuff box sits directly above the buff box. The child strip is level with Shadow Word: Pain at the left
- The Weapon Enchants child in test mode shows weapon-enchant names (up to its enchant slot count), not Power Word: Fortitude/Bloodlust/Shield Wall
- Toggle /am test and /am lock and unlock: the child never moves (SS-3). Only the boxes show or hide. Locked with test off: no outlines
- Set the child's Y offset to -4 (or give it Spacing 4): a 4px gap opens in test mode, unlocked and locked alike. Reset to 0: flush again
- Text chain #13->#14->#15: each block gets its own box, and no two strips overlap (EO-2)
- /am diagnostics out of combat with test mode on: no 'section plan/shown #N failed ... secret boolean' lines, and every container prints a [Shown] section

### Open questions (as raised)

- Should the fix be the test-mode block outline, which moves nothing and keeps SS-3, or does the owner now want a minimum visible seam, which would break SS-3's rule that locked, unlocked and test are identical?
- Is the purple fill on #5's placeholders its configured bar color? The diag line for #5 was truncated. The HARMFUL-tint evidence in 35 already proves the placeholders are the child's
- How many placeholders does #5 actually draw (enchantSlots ticked)? Screenshot 36 is cropped after 3
- Should the outline show in test mode even while locked (test mode can run locked), or only while unlocked?

## PROBLEM C: Text chain #13 -> #14 -> #15 draws misaligned in test mode after a width change or a Size to fit click (verified; the prior record is confirmed, with refinements)

### Root cause

Confirmed. This is a geometry mismatch, not stale state. Each Text line is justified inside its own element box, and each box's width comes from Style.ElementSize for that container alone: Text.AutoSize's fitted width when Size to fit is in effect, or the stored text.width when it is off (modules/Style.lua:736-750). A container attached to a column parent is always hung by its LEFT edge from the parent block's LEFT edge (TOPLEFT to BOTTOMLEFT), because Anchors.DerivedPoints (modules/Anchors.lua:182-186) looks only at the root's growH and growV, never at the child's text.justifyH. A CENTER line sits at box left + W/2 + x, so the child's lines are offset from the parent's by (Wc - Wp)/2 (by Wc - Wp for RIGHT; LEFT lines line up). A change to Width, a Size to fit toggle, or a font or template change moves one box's width while its left edge stays pinned. So CENTER and RIGHT chains separate.

Screenshot geometry (measured with PIL, about 1.22 px per unit, since the 18-unit strip draws 22px tall):
- 33.png: 'Power Word: Fortitude' is 215px wide in all three chains, so the glyphs are the same size. The parent's text centre is x=147.5 and its left edge (the root strip's start edge) is x=32. That gives Wp of about 226-231px, roughly 185 units. That is the fitted width of a name-only line: 176 units of text + x 2 + 2. The children's left edge is about x=31, just past the beside-strip at x=28 plus STRIP_GAP. Their text centre is x=211.5, which gives Wc of about 356-361px, roughly 292-296 units. That matches the stored text.width=300 with Size to fit off, not a fitted width. Predicted offset (Wc - Wp)/2 is about 65px; measured 64px.
- 34.png is cropped 16px further left. The parent is now LEFT: its text starts at x=22, 6px inside its left edge (x=2 units plus glyph bearing). #14 and #15 are still CENTER, because justify is per container. Their centre is still 180.5px past their left edge, the same as in 33, and their text starts at x=88. Predicted start is left + (Wc - 215)/2, about 71-73px, or 66-67px relative to the parent's text start; measured 66px.

Why the workarounds do nothing. /am test re-dresses and re-places every frame from the same ElementSize values. Changing only the parent's justify moves only the parent's text inside its box. Nothing is keyed wrongly:
- the fitKey memo (Style_Text.lua:806-812) covers font, template, justify and x, and the fitted width does not depend on text.width;
- Preview.Show re-dresses whenever previewDirty is set, which every Apply does;
- the PlaceAttached cache does not need a re-place, because the child's anchor is live on the parent's previewExtent and its left edge never moves;
- every consumer reads one consistent ElementSize: Anchors.Place, Preview.Extent, Text.Apply (frame SetSize, with area SetAllPoints), the strip, the label and the engine.

Introduced by: the left-edge rule has been there since bcc54f3 (L-6). B8-P4 (565fc38, IA-1) collapsed the row branch but kept 'TOP{H} to BOTTOM{H}' for column parents, and did not touch Text. So the latent defect is older than batch 8. B8-P7 (5f9f08b, AS-1/AS-2: the AutoSize branch at Style.lua:743-745) exposed it: chained Text boxes now differ in width routinely, because one box is fitted and the next hand-sized, or boxes are fitted from different fonts or templates. No batch-8 requirement covers aligning a chain across different box widths.

Data conflict (confirmed, unresolved). In the screenshots the glyphs are identical and the children are about 300 units wide, which means Size to fit was off on #14 and #15 at that moment. The 20:04 diagnostics show text.autoSize not listed as non-default (so true) for #13-#15, and #15 at fontSize 16. Size to fit off is listed as non-default for #1, so it would have shown up. The diagnostics were most likely taken after further toggles. Under that config #13 and #14 would still line up only if their templates and x match, and #15 at font 16 would be narrower and misaligned. The mechanism is the same either way.

### Evidence

- modules/Anchors.lua:182-186 Anchors.DerivedPoints(L): h = LEFT unless growH == 'left'. Growing down it returns 'TOP'..h, 'BOTTOM'..h. It never reads the child's text.justifyH.
- modules/Anchors.lua:252-259 attachSpec: container mode takes its points from DerivedPoints(EffectiveLayout(cfg)); SeamOffset gives gx = 0 (lines 196-200).
- modules/Anchors.lua:267-282 Anchors.Place: anchor:SetSize(Style.ElementSize(cfg)), then SetPoint(point, target, relativePoint). targetFor (lines 101-108): in test mode the target is the parent's previewExtent; locked, it is the parent's engine or anchor.
- modules/Preview.lua:201-219 Preview.Extent: pinned at the parent anchor's first-placeholder corner and sized farX + ElementSize width. For one column its left edge is the parent box's left edge and its width is Wp.
- modules/Style_Text.lua:547-553 Text.Apply sets frame:SetSize(Style.ElementSize(cfg)). modules/Style_Text.lua:303-314 layoutChain anchors the head piece at pointAt(v, justifyH) of the area with offset x, so a CENTER line is centred at box left + W/2 + x.
- modules/Style.lua:736-750 Style.ElementSize: text uses Text.AutoSize(s, auraType) when OrTemplate(s.autoSize, true), otherwise the stored s.width. Each container is sized on its own.
- modules/Style_Text.lua:793-803 fitWidth: widest fit line + icon inset + |x| + 2, clamped 40..600 (C.TEXT_WIDTH_MIN/MAX, core/Constants.lua:191-192). So 300 is not a clamp artefact: the children's roughly 296-unit box is the stored width.
- defaults/Profile.lua:251 text.autoSize = true (the template). core/Database.lua:905-914 MigrateV8 stamps it false only on containers stored before v8. That is why #1 lists text.autoSize=false and #13-#15, made later, list nothing.
- settings/Text.lua:102-104 sizedToFit greys out Width only when autoSize is stored true. The owner could edit Width only while Size to fit was off, which fits the screenshots' 300-unit children.
- PIL on 33.png: first-line spans are green 40..255, red 104..319 and orange 104..319, all 215px wide. Centres are green 147.5 and red/orange 211.5 on every line. Root strip left edge about x=32; child beside-strips end at about x=28.
- PIL on 34.png: green lines start at x=21-22 (LEFT). Red and orange first lines span 88..303, centre 195.5, which is the same 180.5px past the child's left edge (about x=15 after the 16px crop) as in 33.
- git show 565fc38 -- modules/Anchors.lua: the old vertical-axis branch already returned 'TOP'..h, 'BOTTOM'..h with h = LEFT/RIGHT. P4 removed only the row branch. git log bcc54f3: 'Layout: an attached container continues its parent's flow ... derived points (L-6)'.
- git show 5f9f08b -- modules/Style.lua adds widestLine / Style.TIME_SAMPLES for AutoSize, and the ElementSize AutoSize branch (Style.lua:741-746) comes with it.
- modules/Container.lua:364 Container:Apply calls NS.Anchors.Place(self) on every apply, so a write to the child's own justifyH or width re-places it. No FLOW_PATHS change is needed for a child-justify-derived point.
- settings/Layout.lua:291 the IA-2 label calls DerivedPoints(EffectiveLayout(cfg)). C.POINT_LABELS (core/Constants.lua:102-106) already has TOP and BOTTOM labels.
- Side issue: modules/Diagnostics.lua:451-454 frameShown does `ok and v == true` on a pcall'd IsShown result, which can be a secret boolean under taint. That raises the 'attempt to compare local v (a secret boolean ...)' error the owner saw for every 'section plan' and 'section shown'. It came in with 1e3c29d (B8-P11).

Introduced by: 

### Fix

Derive the horizontal attach side from the child's own justification when the child draws as Text. Bars and icons keep IA-1 as it is.

1. modules/Anchors.lua. Change DerivedPoints to DerivedPoints(L, cfg), with a local side(cfg, L):
- if cfg and Style.StyleKey(cfg) == 'text', map text.justifyH (OrTemplate over D.text.justifyH): LEFT -> 'LEFT', CENTER -> '', RIGHT -> 'RIGHT';
- otherwise return the current rule, LEFT unless growH == 'left'.
Growing down, return ('TOP'..h, 'BOTTOM'..h); growing up, return ('BOTTOM'..h, 'TOP'..h). CENTER then gives TOP/BOTTOM.
Pass cfg from attachSpec (line 256) and from settings/Layout.lua:291, so the IA-2 label reads 'Top ... Bottom'.

The child's box centre then sits on the centre of the parent's previewExtent (test mode), engine or anchor (locked). CENTER lines line up for any Wc and Wp, RIGHT edges line up, and LEFT behaves as it does today. A parent's width change moves the child through the live anchor, so no cache or FLOW_PATHS change is needed. A write to the child's justify re-places it through Container:Apply -> Anchors.Place.

2. Check the side effects of a child whose left edge now sits left or right of the parent's:
- the SS-3 beside-strip and the NL label move with the child's left edge; they stay below the seam, so there is no vertical overlap;
- clampBeside keeps the strip on-screen;
- EO-2 stripRoom arithmetic is vertical only and is unaffected.

Alternative (more invasive, not recommended): give every Text member of a chain one shared width, the widest ElementSize. That aligns boxes for mixed justify too, but it overrides hand-set widths and changes elementWidth for the engine, handle and outline.

Separate small fixes seen along the way:
(a) Diagnostics.lua:453: `return ok and NS.Secrets.CanAccess(v) and v == true` (or issecretvalue guard), fixing the per-container 'section plan/shown' errors from B8-P11.
(b) fitWidth (Style_Text.lua:800): a CENTER line is shifted by the whole x but is budgeted |x| once, so a nudged centred line overhangs by about x/2. Budget 2*|x| when justifyH == 'CENTER' (and add justifyH to nothing new: it is already in fitKey).

### Tests

- tests/test_anchors.lua: DerivedPoints(L, textCfg). CENTER returns ('TOP','BOTTOM') growing down and ('BOTTOM','TOP') growing up. RIGHT returns ('TOPRIGHT','BOTTOMRIGHT'). LEFT returns ('TOPLEFT','BOTTOMLEFT'). The CENTER and RIGHT cases fail today.
- tests/test_anchors.lua: the existing DERIVED table and the IA-1 axis-independence test still pass for bars and icons and for a nil cfg (the non-text path is unchanged).
- New tests/test_anchors_text_chain.lua, test mode, using the mock SetPoint recorder. Set up a CENTER parent with Size to fit on (stub measurer) and a CENTER child with autoSize=false and width=300. Anchors.Place(child) records ('TOP', parent.previewExtent, 'BOTTOM', 0, -seam), and the mock rect centres coincide.
- Same fixture: SetByPath the child's text.width 300 -> 150 and flush. The child is re-placed and still anchors TOP/BOTTOM, which is the owner's regression.
- Same fixture: toggle the child's text.autoSize through SetByPath. The points stay TOP/BOTTOM and only the anchor size changes.
- Same fixture: SetByPath the child's text.justifyH CENTER -> LEFT. The next apply re-places it with TOPLEFT/BOTTOMLEFT.
- Same fixture, locked (hang mode engine): the child's point targets the parent's engine or anchor with TOP/BOTTOM.
- tests/test_pages_layout.lua: the IA-2 'Attached by its %s to the %s' label reads Top/Bottom for a CENTER Text child and is unchanged for bars and icons.
- Separate: tests/test_diagnostics.lua: frameShown with IsShown returning a secret sentinel returns false without raising, and 'section plan' and 'section shown' complete.
- Separate (if taken): tests/test_style_text_autosize.lua: a CENTER line with x=10 fits 10 units wider than the same line LEFT.

### Smoke

- Rebuild the owner's chain: #13 Text CENTER with Size to fit on; #14 attached, CENTER, Size to fit off, width 300; #15 attached to #14, CENTER, width 300. With /am test, 'Power Word: Fortitude' and every other line in all three centre on one vertical.
- Change #14's width 300 -> 120 -> 400, then #15's: the lines stay centred under #13's.
- Toggle Size to fit on #13, #14 and #15 in turn, and set #15's font to 16: the centres stay on one line.
- All three LEFT: left edges line up (as today). All three RIGHT: right edges line up.
- Mixed, #13 LEFT and #14/#15 CENTER: the children centre on #13's box centre. This is expected; say so in the smoke note.
- Toggle /am test off and on, and /reload: the alignment holds, with no Lua errors.
- Locked with real auras up: the live chain lines up the same way (the engine target path).
- Unlocked in test mode: each child's beside-strip and Label sit beside its first line and stay on-screen when the child's box is wider than the parent's. Dragging #13 moves the whole chain.
- Regression: #1 -> #5 bars, #10 -> #11 bars growing up, and the #12/#16 icon rows attach exactly as before (IA-1). The Layout tab's 'Attached by its ...' line is unchanged for them and reads Top/Bottom for a CENTER Text child.
- /am diagnostics: no 'section plan/shown ... secret boolean' errors, and every container prints its [Shown] lines (if fix (a) is included).

### Open questions (as raised)

- The screenshots and the 20:04 diagnostics disagree. The pixels show #14 and #15 at about 296 units (the stored 300, Size to fit off), with the same glyph size as #13. The diagnostics show Size to fit at its default (on) for all three, and fontSize 16 on #15. Can the owner confirm the Size to fit state and fonts at the time of screenshots 33 and 34? The root cause and fix hold either way.
- Design choice for the owner: align a Text child by its own justification (recommended, local to Anchors.DerivedPoints), or give every Text container in a chain one shared width.
- Should a bars or icons child under a CENTER Text parent also centre (key on the parent's justify), or keep IA-1's start-edge rule? The proposed fix keys only on the child's style and justify.
- Include the Diagnostics.lua:453 secret-boolean guard (B8-P11 regression) in the same batch?
- Should fitWidth budget 2*|x| for CENTER lines so a nudged centred line is not clipped?

## PROBLEM D: /am diagnostics raises "attempt to compare local 'v' (a secret boolean value)" at modules/Diagnostics.lua:453, out of combat with aurasSecret=false; plus a review of the v8 migration, the [Cfg] noise and MAX_LINES. (Adversarial re-verification: the earlier record is CONFIRMED in substance, with the additions and corrections noted below.)

### Root cause

(1) THE CRASH (confirmed). modules/Diagnostics.lua:451-454:
  local function frameShown(frame)
      local ok, v = pcall(frame.IsShown, frame)
      return ok and v == true          -- :453
  end
The pcall only covers the IsShown call. On an engine aura button (the frame from engine:GetAuraGroupFrame(key, i)), IsShown succeeds and returns a SECRET boolean. `v == true` then runs outside the pcall, and in tainted code it raises. GetAuraGroupFrameCount is not the cause: it is gated by NS.Secrets.IsReadableNumber (:462 and :548). IsAnchoringSecret is never called. Nothing else on this path compares a value.

Why it is secret while AurasAreSecret() is false: the DG-3 guard (header :17-22) assumes that "auras not secret" means "engine buttons are readable". That is not true. The engine drives each button's Shown aspect from aura data, and like the button's size (midnight-quirks.md:344-356, B2-3), frame level (:330) and an engine-written name's anchoring (:173), that aspect stays secret out of combat. midnight-quirks.md:171 already lists Region:IsShown among the calls that fail on these buttons in combat. frameCounts (:458-470) and groupButtons (:545-560) skip button reads only when x.secret (AurasAreSecret) is true, and never check the value IsShown returns. ADDITION: the owner ran with testMode=true, and in test mode every engine is SetEnabled(false) (Container.lua:448-451, Preview.lua:13-16). The code cannot tell whether IsShown is secret on every used engine button, or only on buttons that a disabled engine hid with a secret SetShown. Either way the fix is the same, but the smoke run must cover test mode both OFF and ON.

Effect: "section plan #N" raises in planLines -> groupLine -> frameCounts -> frameShown (:465-467). The verdict line has already printed, but every group line and warning after it is lost. "section shown #N" raises in shownLines -> groupButtons -> frameShown (:552). groupButtons runs before predictions() in the same section (:596-599), so the predicted lines are lost too. #5 "Player Weapon Enchants" is enchant-only: plan.enchants is set, the Uncategorized state is hide, and the plan has zero aura groups (FilterCompiler.lua:732-735, appendEnchants :745-754). Both group loops run zero times, so only #5 printed predictions. CORRECTION to the owner summary: #5's plan and shown sections should not have failed at all. "For EVERY container" is almost certainly shorthand for "every container with an aura group".

Introduced by 1e3c29d "B8-P11: /am debug diag writes a diagnostic report to the console". git blame on :451-454 shows every line is from 1e3c29d, and git log -S frameShown finds only that commit. d386957 (B8-P13) only renamed the command. Why the tests missed it: tests/test_diagnostics.lua:210-231 covers only the aurasSecret=true path. The mock's __SECRET sentinel (tests/wow_mock.lua:130-134) has no __eq and is a table, so `sentinel == true` is plain false headlessly and never raises.

(2) THE v8 MIGRATION IS CORRECT (confirmed). core/Database.lua:909-926: stampFitOff(c) runs for EVERY container in p.containers, whatever its style. It creates the text block if it is missing and stamps text.autoSize=false when the stored value is nil. It does not key off style or off the text block. This is broader than AS-3's "every existing text container" on purpose (D8 comment :885-891), not the opposite of it. MigrateV8 was created in c9caf26 (B8-P5), and the stamp was added in 5f9f08b (B8-P7). The only writer of false in the source is Database.lua:913; true comes only from the template (defaults/Profile.lua:251). So #1 and #5 reading false proves the stamping step ran on this profile. The names "Text (Offensive/Defensive Cooldowns)" are not starters: no Lua file defines them. "Text (Defensive Cooldowns)" already appears in the pre-v8 batch-8 research (docs/superpowers/research/2026-09-25-feedback-batch8-findings.md:942), so these containers existed before v8 and were stamped false. The ways they could read true (template default, so absent from [Cfg]) are: (a) smoke 200 (docs/smoke-tests.md:1237-1241) tells the owner to "Tick it" on each Text container; (b) `/am reset container.text.autoSize` (Slash.lua:54) or Reset all (OptionsSetup.lua:222); (c) delete-and-recreate after v8, or a profile copy or import from a fresh profile. (a) is the most likely. Owner check: /am get container.text.autoSize on #13.

(3) THE OTHER LINES (confirmed). The [Cfg] noise comes from cfgLines/isContainerRow (:492-510). NS.RowApplies (settings/Schema.lua:349-356) checks only row.auraTypes. It ignores the row's shownWhen (settings/Layout.lua:38-41: SCREEN_ONLY on position.*, CONTAINER_ONLY on attach.container, FRAME_ONLY on attach.frame/point/relativePoint, ATTACHED_ONLY on attach.x/y at :148/:153). It also ignores the style pages, which are disabled for other styles (Text.lua:506, Bars.lua:207, Icons.lua:125). The listed values that have no effect:
- attach.y=-4 on screen-mode #1 and the other old screen containers. The template moved to 0/0 in c9caf26 (defaults/Profile.lua:171-174). resetOldSeam (Database.lua:899-907) returns early unless mode=="container". In screen mode the value does nothing: Anchors.Place uses attachSpec only when there is a target (Anchors.lua:252-283). It is still a LATENT BUG. If such a container is later switched to "Another container", attachSpec adds the stored y as a nudge on top of the seam (gy + y, :258), and the 4px v8 removed comes back. The MODE row has no onChange that resets it (Layout.lua:93-99).
- attach.container=16 on a screen-mode container: a stale target that does nothing.
- position.y=-120 on #5 (attached to #1): SCREEN_ONLY, does nothing.
- text.autoSize=false on bars and icons containers: stamped deliberately by D8, but the Text page is disabled for them, so in a diagnosis it is noise.
Header: stateLine (:203-210) is correct and prints more fields than the owner summarised. It does not say that with testMode=true the engines are disabled, so frame counts and [Shown] describe engines that draw nothing. #5's "Devotion Aura -> Stances" is what ExplainSpell should say (465 is in the Stances list, defaults/Categories.lua:615). But predictions for a container whose plan has enchants and zero aura groups are all noise, because that container draws no aura group. The report should describe its enchant slots instead.

(4) MAX_LINES IS CORRECT (confirmed). BUFFER = lib.MAX_BUFFER = 1500 (libs/LibKa0s/DebugLog.lua:57). Diag.MAX_LINES = min(1200, 1500-100) = 1200 (Diagnostics.lua:36-37). Out:add stops at MAX_LINES-2 (:79-86), and Out:close appends only the two markers. "138/1500" is the console's status line: BufferSize() over MAX_BUFFER, counting every line in the console (DebugLog.lua:690 and the status line). It is not the report's own count. No defect.

### Evidence

- modules/Diagnostics.lua:451-454 frameShown: `return ok and v == true` at :453, outside the pcall; git blame -> every line from 1e3c29d (B8-P11); git log -S frameShown -> 1e3c29d only
- modules/Diagnostics.lua:458-470 frameCounts: count gated by Secrets.IsReadableNumber (:462), IsShown read whenever x.secret is false (:463-467)
- modules/Diagnostics.lua:545-560 groupButtons -> frameShown (:552); shownLines :591-600 runs groupButtons before predictions() in one section
- modules/Diagnostics.lua:117-121 section(): one pcall per section, so one raise costs the rest of that section
- modules/Diagnostics.lua:17-22 header DG-3: the only button guard is AurasAreSecret
- modules/FilterCompiler.lua:732-735 (groupCount==0 with plan.enchants is legitimate) and :745-754 appendEnchants: #5 has zero aura groups
- docs/midnight-quirks.md:171 (Region:IsShown fails on engine buttons in combat), :173 (IsAnchoringSecret true out of combat), :330 (FrameLevel a SecretAspect out of combat), :344-356 (a laid-out button's size is secret out of combat)
- modules/Container.lua:448-451 ApplyLive -> engine SetEnabled; modules/Preview.lua:13-16: test mode disables every engine, and the owner ran with testMode=true
- tests/test_diagnostics.lua:210-231 covers only __aurasSecret=true; tests/wow_mock.lua:130-134 __SECRET has no __eq, so `sentinel == true` cannot raise headlessly
- core/Database.lua:899-907 resetOldSeam (container mode only); :909-926 stampFitOff for every container, style-independent
- git log -S MigrateV8 -> c9caf26 (B8-P5) created it; git log -S autoSize -> 5f9f08b (B8-P7) added the stamp
- grep: text.autoSize=false is written only at core/Database.lua:913; true only via defaults/Profile.lua:251
- docs/superpowers/research/2026-09-25-feedback-batch8-findings.md:942 names 'Text (Defensive Cooldowns)' before v8; no .lua file defines the Text (...) names; docs/smoke-tests.md:1237-1241 check 200 says to tick Size to fit
- settings/Slash.lua:54 `/am reset path` and settings/OptionsSetup.lua:222 Reset all can also restore the template's true
- settings/Schema.lua:349-356 rowApplies checks only auraTypes; settings/Layout.lua:38-41 shownWhen selectors, :100-156 position.* SCREEN_ONLY, attach.container CONTAINER_ONLY, attach.x/y ATTACHED_ONLY; the MODE row :93-99 has no onChange
- modules/Anchors.lua:252-261 attachSpec adds stored attach.x/y on top of the seam in container mode; :266-283 Place uses it only when there is a target, so screen mode ignores attach.*
- defaults/Profile.lua:171-174 attach template x=0,y=0
- defaults/Categories.lua:615: 465 Devotion Aura in Stances
- modules/Diagnostics.lua:35-39 MAX_LINES=min(1200,1400)=1200; :79-92 add/close; libs/LibKa0s/DebugLog.lua:57 MAX_BUFFER=1500, :690 BufferSize

Introduced by: 

### Fix

A. Secret-boolean crash (modules/Diagnostics.lua, B8-P11 follow-up; keep the section):
1. Make frameShown tri-state:
   local function frameShown(frame)
       local ok, v = pcall(frame.IsShown, frame)
       if not ok or not NS.Secrets.CanAccess(v) then return nil end  -- nil = unknowable
       return v == true
   end
2. frameCounts: count shown and unknowable separately. Return n,"?" when every read was unknowable, or n,"<shown>+<k>?" when some were. Keep the early return while x.secret.
3. groupButtons: when frameShown is nil, do not drop the group. List by index (up to MAX_IDS) with identify() run under pcall, and label the line "shown=? (button visibility is secret)". Or print one summary line per group. identify/probeInstance must run under pcall: probeInstance indexes frame[method] and v.auraInstanceID outside its pcall.
4. Isolation: in shownLines, pcall each group's groupButtons and pcall predictions() separately. In planLines, pcall each groupLine, so later groups and warnings survive.
5. Docs: fix the DG-3 wording (header :17-22, docs/debug.md). Add a midnight-quirks.md entry: an engine button's IsShown returns a secret boolean out of combat even while AurasAreSecret() is false.

B. [Cfg] noise (cfgLines/isContainerRow :492-510). Use a Diagnostics-local applies(row, c) that also requires two things. (a) row.shownWhen matches c: read NS.GetSetting(sw.path, c.id), with equals as a scalar or a list, mirroring the options library's shownNow. (b) A style-page row (page bars/icons/text) matches c.style. Better, export each page's disabledFor from NS.RegisterContainerPage so there is one source. List inert rows on a separate "#N inert:" line rather than dropping them, because stale values like attach.y=-4 come back into use on a mode switch.

C. Latent -4 seam. Either give the attach.mode row a write-time reset (when the mode changes to "container" and the stored pair is exactly 0/-4, set it to 0/0), or add a schema v9 step that applies resetOldSeam's rule to mode=="screen" containers too, still leaving frame-mode containers alone. v8 cannot be extended, because accounts are already stamped v8.

D. Test mode: when NS.State.testMode, print "test mode: engines disabled, placeholders drawn; frame counts and [Shown] describe the engine, not the screen".

E. Enchant-only containers (plan.enchants and #plan.groups==0): skip predictions() and print "#N enchant slots only: slots=[...] hidePermanent=... frames=n", reading shown state through the guarded frameShown.

No change to MAX_LINES. No change to MigrateV8's autoSize stamp (correct and deliberately broader). Update the AS-3 wording in the spec to "every existing container" so the spec and code agree.

### Tests

- tests/test_diagnostics.lua 'an engine button whose IsShown is secret out of combat costs no section': aurasSecret=false; give the sentinel (or a dedicated secret-boolean sentinel) an __eq that raises, plant mocks.issecretvalue to recognise it, and rawset(f,'IsShown', function() return SECRET end) on the group's frame. Assert: no 'section'+'failed' line, the [Plan] line reads shown=?, and a 'predicted:' line for 774 Rejuvenation still prints. It fails under the current code only once the sentinel raises on == (note: Lua 5.1 calls __eq only for two tables, so the harness needs issecretvalue-based detection. The assert that fails today is the shown=? one, since current code prints shown=0).
- tests/test_diagnostics.lua 'a raising button probe costs one line, never the predictions': a frame whose __index errors on GetAuraInstanceID, with IsShown true. The predicted lines still print.
- tests/test_diagnostics.lua 'a plan group that raises keeps later groups and warnings': GetAuraGroupFrameCount raises for the first key only; the second group's [Plan] line and the warnings still appear.
- tests/test_diagnostics.lua '[Cfg] lists only settings in use': screen container with attach.y=-4 and attach.container=16 -> neither is in non-default (or both are on the inert line); an attached container's position.y=-120 is absent; a bars container's text.autoSize=false is absent; a text container's text.autoSize=false is present.
- tests/test_diagnostics.lua: an enchant-only container prints an 'enchant slots only' line and no predicted lines; with testMode=true the report carries the test-mode note.
- tests/test_migrations.lua (if C is a v9 step): screen 0/-4 -> 0/0, frame 0/-4 kept, other pairs kept, idempotent. Or tests/test_pages_layout.lua: switching screen->container resets a stored 0/-4 to 0/0 and keeps any other pair.
- Keep tests/test_migrations.lua v8 tests (every container stamped false regardless of style).

### Smoke

- Out of combat, test mode OFF, with a target and focus: /am diagnostics. No '[Diag] section ... failed' line. Every container with aura groups prints its [Plan] group lines (frames=N shown=<n> or ?), its [Shown] lines and its predicted lines.
- Repeat with /am test ON: no failure lines, and the test-mode note is printed.
- In combat on a dummy: no Lua error, shown=?, '[Shown] #N skipped' (smoke 207 unchanged).
- #5 Player Weapon Enchants prints an enchant-slots line instead of predicted hidden buffs.
- [Cfg]: screen containers no longer list attach.y=-4 or attach.container among the non-default values; #5 no longer lists position.y; bars and icons containers no longer list text.autoSize; a Text container with Size to fit off still lists text.autoSize=false.
- /am get container.text.autoSize on #13-#15: false unless the owner ticked Size to fit (smoke 200), ran /am reset, or recreated or imported them; true with none of those means the v8 stamp missed them. Report it.
- If fix C lands: switch a screen container still storing 0/-4 to Another container. The seam equals the child's Spacing, with no extra 4px.
- /run print(issecretvalue(<engine button>:IsShown())) with test mode off and on, to settle whether the Shown aspect is secret in both.

### Open questions (as raised)

- Did the owner tick Size to fit on #13-#15 during smoke 200, run /am reset, or recreate or import them? The code shows the v8 stamp covered every pre-existing container.
- Did #5's plan and shown sections actually fail, or does 'every container' mean every container with aura groups? The code predicts #5 cannot fail, because it has zero groups.
- Is an engine button's IsShown secret whenever it is out of combat, or only while test mode has the engine disabled (SetEnabled(false))? This needs an in-game issecretvalue check with test mode off and on. The fix is the same either way.
- Should inert [Cfg] rows be dropped, or shown on a separate inert line? (Recommended: a separate line, since stale attach offsets come back into use on a mode switch.)
- Fix C: a write-time reset on the attach-mode change, or a v9 migration step?

## Anchor-point design draft

# Design: user-chosen container-to-container anchor points (AuraMaster, branch `feat/2026-09-25-feedback-batch8`)

Read-only: no files were edited.

## 0. Where the fixed behaviour lives today, and which commits introduced it

- **The points are hard-coded.** `Anchors.DerivedPoints(L)` (modules/Anchors.lua:182-186) is the only source. It gives `TOP{H}` to `BOTTOM{H}` growing down and `BOTTOM{H}` to `TOP{H}` growing up. H is LEFT unless growH is left. The skeleton dates from bcc54f3 (L-6). The body in use now is 565fc38 (B8-P4, IA-1), which removed the row branch.
- **Nothing about the points is stored.** attachSpec (Anchors.lua:252-262) derives them on every Place. The read-only line `attachedText`/`attachedLine` (settings/Layout.lua:287-304) re-derives them for display.
- **The follower strip sits beside the first element.** `besideSeam` (Anchors.lua:565-567, c9caf26, B8-P5) is true for every follower, and `StripPoints` (598-609, reworked in a945c09, B8-P10) then puts the strip beside the child's first element. This is the "handle floats to the left" confusion. With explicit side points it becomes wrong, not just confusing, because a left-side attachment needs that exact spot.
- **Flow is inherited, so there is no growth conflict today.** `EffectiveLayout`/`FLOW_KEYS` (Anchors.lua:128, 170-178) copies the root's axis, growH and growV and writes nothing. The Growth rows are dimmed through `inherits()`/`inherited()` (Layout.lua:44-58).
- **Parts that carry over unchanged:**
  - The engine is pinned at its growth corner, with a 1x1 provisional size (Container.lua:225-231). All nine edge points of the engine, the preview extent (Preview.lua:196-214, a plain sized rect) and the anchor can be used as SetPoint targets. We only anchor to them and never read them.
  - A popup already has an established pattern in this repo: `AURAMASTER_DELETE_CONTAINER` (settings/Containers.lua:128-149).

## 1. Allowed points

### Model

Store the choice relative to the flow, not as absolute points. One key, `attach.edge = "<side>-<align>"`.

- **side:**
  - `after`: the parent's vertical growth side (below when it grows down, above when it grows up). This is the only stacking side IA-1 had.
  - `ahead`: the parent's horizontal growth side (right when growH is right).
  - `behind`: the side the parent's lines start from (left when growH is right).
  - The side opposite vertical growth ("before", the TOP* points when growing down) is never offered. That is the owner's rule. CENTER is never offered either.
- **align:** `start` | `center` | `end` along the edge. start is the edge the lines start from: LEFT for after when growH is right, TOP for ahead/behind when growing down.

Why relative rather than absolute: a stored token can never become invalid when the root's growV or growH flips. The chain mirrors itself, and the child stays aligned with the parent's first element. Absolute points would need a revalidation or popup on every Growth write.

### Validity rule (no grow-back)

Let `extendsH(L) = L.axis ~= "vertical" or (tonumber(L.perLine) or 0) > 0`. That is, the child can hold more than one element across. The axis comes from the effective (inherited) layout; perLine is the child's own.

| side | allowed when |
|---|---|
| after | always. The child grows away from the parent, so this is the owner's "bottom" when growing down. |
| ahead | always. The child's lines grow further away. For an icon row this reads as "continue the row". |
| behind | only when `not extendsH(childL)`. A child that holds more than one element across would grow back into the parent, because it inherits growH. |
| before, CENTER | never |

Checked against the owner's example (bars growing down): bottom, bottom left and bottom right are OK; left and right, each with top, middle or bottom, are OK; top is not. That matches the owner's rule exactly. For horizontal-axis icon rows (IA-1), the behind side is never available, and the ahead side is the "continue the row" choice.

### Point table

Notation:
- V0/V1 are the start and end vertical edges: TOP/BOTTOM growing down, BOTTOM/TOP growing up.
- H0/H1 are the start and end horizontal edges: LEFT/RIGHT when growing right, RIGHT/LEFT when growing left.
- Each pair reads child point -> parent relativePoint.

| token | pair | down, right | down, left | up, right | up, left |
|---|---|---|---|---|---|
| after-start (**default**, the same as today) | V0H0->V1H0 | TOPLEFT->BOTTOMLEFT | TOPRIGHT->BOTTOMRIGHT | BOTTOMLEFT->TOPLEFT | BOTTOMRIGHT->TOPRIGHT |
| after-center | V0->V1 | TOP->BOTTOM | TOP->BOTTOM | BOTTOM->TOP | BOTTOM->TOP |
| after-end | V0H1->V1H1 | TOPRIGHT->BOTTOMRIGHT | TOPLEFT->BOTTOMLEFT | BOTTOMRIGHT->TOPRIGHT | BOTTOMLEFT->TOPLEFT |
| ahead-start | V0H0->V0H1 | TOPLEFT->TOPRIGHT | TOPRIGHT->TOPLEFT | BOTTOMLEFT->BOTTOMRIGHT | BOTTOMRIGHT->BOTTOMLEFT |
| ahead-center | H0->H1 | LEFT->RIGHT | RIGHT->LEFT | LEFT->RIGHT | RIGHT->LEFT |
| ahead-end | V1H0->V1H1 | BOTTOMLEFT->BOTTOMRIGHT | BOTTOMRIGHT->BOTTOMLEFT | TOPLEFT->TOPRIGHT | TOPRIGHT->TOPLEFT |
| behind-start | V0H1->V0H0 | TOPRIGHT->TOPLEFT | TOPLEFT->TOPRIGHT | BOTTOMRIGHT->BOTTOMLEFT | BOTTOMLEFT->BOTTOMRIGHT |
| behind-center | H1->H0 | RIGHT->LEFT | LEFT->RIGHT | RIGHT->LEFT | LEFT->RIGHT |
| behind-end | V1H1->V1H0 | BOTTOMRIGHT->BOTTOMLEFT | BOTTOMLEFT->BOTTOMRIGHT | TOPRIGHT->TOPLEFT | TOPLEFT->TOPRIGHT |

The child point is always a point on the child's one-element anchor, which is its first element. The relative point is on the parent's hang target (engine, preview extent, or anchor).

Why `after-start` is the default:
- It is exactly the current DerivedPoints, so migrating to it moves nothing.
- `after-center` is the fix Problem C asks for (centred Text chains) as a user choice, with no special case keyed on justify.

### Anchors.lua API (replaces DerivedPoints)

- `Anchors.EDGES`: the nine tokens in display order (after, then ahead, then behind; start, center, end within each).
- `Anchors.ParseEdge(token)` returns side and align. An unknown token returns `"after", "start"`.
- `Anchors.EdgeAllowed(cfg, token, L)` returns true, or false plus an `NS.L` reason. It applies the validity rule to `L or EffectiveLayout(cfg)`.
- `Anchors.ResolvedEdge(cfg)` returns the stored token if it is allowed. Otherwise it returns `"after-"..align`, writes nothing, and emits a `[Anchor]` debug trace.
- `Anchors.EdgePoints(L, token)` returns point and relativePoint from the table above, using `NS.Container.Growth(L)`.
- `Anchors.DerivedPoints(L)` becomes a thin wrapper, `EdgePoints(L, "after-start")`, kept for its existing callers and tests.
- `attachSpec` (Anchors.lua:252): `local edge = Anchors.ResolvedEdge(cfg); local point, rel = Anchors.EdgePoints(L, edge); local gx, gy = Anchors.SeamOffset(L, (Anchors.ParseEdge(edge)))`. clearStrip applies only when side == "after".

### Dependency on Problem A

This design needs the follower to hang from the same rect whether the parent is locked or unlocked. The side, center and end points on the "slot" (one element) resolve differently from the same points on the engine. For example, `ahead-end` would attach level with the parent's first element when unlocked and level with its last element when locked, which breaks SS-3. So:
- Resolve Problem A first.
- Recommended: Problem A option B, which drops `slot` from `hangModeFor` (Container.lua:531-534).
- Alternatively, option A: keep `slot` only for a pristine parent (one whose engine has never created a frame). Both paths keep one geometry.

## 2. Settings UI: Layout > Anchor, subsection "Another container"

### Row order

`[Container v] | Attached by its Top left to the Bottom left of 'X'` (the existing pairWith line), then a new line with `[Side v]`.

### New schema row

- path `container.attach.edge`, page `layout`, group `G_ANCHOR`, subgroup `S_CONTAINER`, `shownWhen = CONTAINER_ONLY`, type `string`, `startsLine = true`, label `L["Side"]`, `onChange = structural` (so the attached line redraws).
- `values = edgeChoices`: a function over `Anchors.EDGES`, filtered by `EdgeAllowed(active)`. Labels are absolute and computed from the effective growth by `edgeLabel(token, L)`:
  - after: "Bottom left" / "Bottom" / "Bottom right" (Top... when growing up; left and right swapped when growing left)
  - ahead: "Right, top" / "Right, middle" / "Right, bottom"
  - behind: "Left, top" / ...
- If the stored token is currently not allowed, it stays in the list, grayed with the suffix " (unavailable)", so the dropdown never shows blank.
- `validate = function(v, id) ... return NS.Anchors.EdgeAllowed(cfg, v) end`. This returns false plus a reason, the same pattern as the Text template, so `/am set` prints why it refused.
- desc (via NS.L): "Which side of the container it is attached to it sits on. Only sides it cannot grow back over are listed: never the side the chain grows away from, and the side lines start from only when this container is one aura wide."

### attachedText (Layout.lua:287)

- Use `EdgePoints(EffectiveLayout(cfg), ResolvedEdge(cfg))`.
- Change the wording to "Its %s joins the %s of '%s'", which says "joins" instead of the ambiguous "attached by".

### New afterGroup note `edgeFallbackNote`

Chain it with `growsBackNote` in `afterGroup[G_ANCHOR]`. When the stored token differs from `ResolvedEdge`, it prints a gray line: "'%s' needs this container to be one aura wide (Fill: columns, Per row or column: 0). It sits %s until then."

### When the parent's growth or axis changes later

- growV or growH flips: the token keeps its meaning, the whole chain mirrors, the label text updates on the next draw, and nothing is written.
- The root's axis changes to rows, or the child's own perLine goes above 0, while a `behind-*` edge is stored: `ResolvedEdge` falls back to `after-<align>` at runtime, the stored token is kept, and the note explains. Undoing the change restores the side.
- No popup and no write. A write to another container, or to an unrelated key, never gets a dialog.

### Re-apply routing

- Add `"container.attach.edge"` and `"container.layout.perLine"` to `FLOW_PATHS` (Anchors.lua:132).
- Add `requestParents(p)` in modules/ContainerManager.lua beside `requestFollowers` (:581). On writes to `container.attach.edge|mode|container`, it re-applies the old target (from the payload's old value) and the new one, because a parent's strip side depends on which sides its followers occupy (§4).

## 3. Growth-direction conflicts

### Options compared

| | (i) Keep inheritance and add a confirm popup (**recommended**) | (ii) Owner's literal version: write the child's growth to match |
|---|---|---|
| Stored child growth | untouched; a detach restores it | overwritten (lossy) |
| Parent growth changed later | the chain re-flows through EffectiveLayout; no dialog, no writes | every descendant needs a cascade write, or opposing growths reappear |
| Chains A<-B<-C | always consistent from the root | each link needs its own write and its own conflict |
| Satisfies "popup, reject on cancel" | yes | yes |

Recommendation: (i). The popup states the truth ("it will grow down like X"). Accepting attaches; cancelling writes nothing. The child's own stored growth is never overwritten, which is the least surprising outcome.

### Trigger

`Anchors.FlowChangeOnAttach(childCfg, targetId)` returns nil or `{ root = rootCfg, keys = {...changed FLOW_KEYS...}, followers = n }`.
- The root compared against is `FlowRoot` of the prospective attach, which is the target's root, not the target itself. The comparison is between the child's own stored `layout.axis/growH/growV` and that root's values.
- `followers` is `#Anchors.Followers(child.id)`, because those containers re-flow too.

### Panel intercept

settings/OptionsSetup.lua, `descriptor.set` (:128):
- Before `NS.SetByPath`, look up the row. If `row.confirmWrite` exists and `row.confirmWrite(value, activeId)` returns a prompt, call `NS.ConfirmWrite(prompt, path, value, id)` followed by `NS.RequestPanelRefresh()`. That reverts the dropdown to the stored value immediately. Then return without writing.
- Put `confirmWrite = attachConfirm` on two rows:
  - `container.attach.container` (value != 0 while mode == container);
  - `MODE` (value == "container" while `attach.container` names a usable target). This covers the stale `attach.container=16` case from the diagnostics.

### Popup

`StaticPopupDialogs["AURAMASTER_ATTACH_FLOW"]` (in settings/Layout.lua, following the Containers.lua:128 pattern):
- `button1 = L["Attach"]`, `button2 = L["Cancel"]`, `timeout = 0`, `whileDead`, `hideOnEscape`.
- Set the text before `StaticPopup_Show`, as GeneralSpells.lua:938 does, because StaticPopup takes only two arguments: `L["Attach '%s' to '%s'? '%s' will fill and grow like '%s' (%s). Its own Growth settings are kept and come back if you detach it."]`, plus `L[" %d container(s) attached to it follow too."]` when followers > 0. All strings go through `NS.L` in ASCII.
- `popup.data = { path, value, id }`.
- **OnAccept:**
  - If `InCombatLockdown()`, print the gray refusal and do nothing.
  - Otherwise `NS.SetByPath(path, value, id)`. Its validate re-checks the cycle, because the state may have changed while the popup was open.
  - Then `H.RefreshAllPanels()`.
- **OnCancel / OnHide:** `NS.RequestPanelRefresh()` (idempotent).
- **Taint:** the popup is shown only from a panel click, never from a protected path. OnAccept touches only the write seam. No frame of ours is shown or hidden from it, and anchor work is deferred through CONFIG_CHANGED to RequestApply, which already respects lockdown.

### Other paths

- **`/am set` and resets:** no popup (non-interactive). The write happens, followed by one `NS.L` chat line: "'%s' now grows like '%s'; its own Growth settings are kept." Emit it from the `attach.container` onChange when `FlowChangeOnAttach` returned non-nil.
- **Changing the root's growth after attaching:** no popup. The root's Growth tab intro (`growthIntro`) gains the line "%d container(s) attached to this one follow its fill and growth." Mid-chain containers already have dimmed rows.
- **Detaching a mid-chain B from A** when B's own flow differs: B and C revert to B's own flow. Recommendation: a chat line, not a popup (see open question 7).

## 4. Seam spacing, handle and label

### Seam

`Anchors.SeamOffset(L, side)`:
- after: unchanged. `(0, ±gap)` with `gap = axis == "vertical" and spacing or lineSpacing` (SS-1).
- ahead/behind: `hgap = (L.axis == "horizontal") and L.spacing or L.lineSpacing`. That is the child's own gap between elements across (between columns when it fills columns), clamped at >= 0.
  - ahead gives `x = (growH == "left") and -hgap or hgap`, y = 0.
  - behind gives the opposite sign.
- `attach.x/y` nudge on top as before (SS-2). `clearStrip` applies only to after (EO-2 stays vertical).

### Strip side

A new `Anchors.StripSide(cfg)` returns `"before" | "behind" | "ahead" | "inside"`. It replaces `besideSeam` and picks the first side of the child's first element that nothing occupies:

| container | tried in order |
|---|---|
| root (no FlowRoot) | before (unchanged) |
| after-* follower | behind (as today) -> ahead (only if `not extendsH` and it has no ahead-* follower) -> inside |
| ahead-* / behind-* follower | before (the parent is beside it, so this side is free) |

- Occupied by followers means a direct follower of this container with a matching side, found by one allocation-free scan over `NS.Database.GetContainers()`.
- **inside:** the strip overlays the top band of the container's own first element at HANDLE_LEVEL, and never covers the parent.
- `StripPoints` (Anchors.lua:598) switches on StripSide:
  - A before or side strip extends away from the parent. For a behind follower, the strip's H1 edge sits on the child's H1 edge and extends toward H0. That way a label wider than the element never spills over the parent column.
  - For an `ahead-*` follower whose parent strip also sits on its before side, the child's strip is pushed out by the parent's rows (`(stripShown + labelShown) * (STRIP_H + STRIP_GAP)`). This extends the EO-2 rule that "strips never stack" sideways.
- `stripRoom`, `labelPush`, `clampToHandle` and `clampBeside` read StripSide instead of the boolean `beside`. The clamp reaches out from whichever side the strip is on.
- The label (NL-2/NL-3) follows the strip's side, as today.

### Making it unambiguous

1. **Join pin.** A new `container.joinPin`: a 10x10 gold diamond (WHITE8X8 rotated 45°, the handle's gold), created once, at `SetPoint("CENTER", anchor, childPoint)`. It is shown only while unlocked and while `placedAs == "container"`, at the handle's level. Placed in `Anchors.UpdateHandle` alongside the strip, out of lockdown. It marks the actual join, so a beside strip no longer reads as the attachment.
2. **Tooltip.** The strip's `attached()` tooltip line (Anchors.lua:391) becomes specific: "Joined to the %s of '%s'. Change the side on Layout > Anchor."

## 5. Schema, v9 migration and validation

- **Template** (defaults/Profile.lua:171): `attach = { ..., edge = "after-start" }`.
- **`Database.MigrateV9(p)`**, a new ladder row `{ to = 9 }`. It cannot go into v8, because the owner's accounts are already stamped v8. For every container table `c` with a table `attach`:
  1. If `at.edge == nil` or it is not in `Anchors.EDGES`, set `at.edge = "after-start"`. Stamp every container, not only container-mode ones (the same rationale as D8): a later switch to "Another container" then keeps today's placement even if the template default ever changes.
  2. Recommended: the latent-seam fix from Problem D.
     - Mode `"screen"` with offsets 0/-4 (absent y counts as -4): reset to 0/0.
     - Frame mode: untouched.
     - This reuses `resetOldSeam`, parameterised on mode.
  - It returns `(stamped, reset)` and logs `NS.Debug("Migrate", "v9 profile '%s': ...")`.
  - It is idempotent.
  - No visual change: `EdgePoints(L, "after-start") == old DerivedPoints(L)` for all eight axis x growH x growV combinations, pinned by a test. The seam is unchanged for after.
- **Load validation.** `backfillContainers` (Database.lua:183) calls `normalizeAttach(c)`, which maps an unknown `attach.edge` to "after-start" with a Debug line. Runtime validity (behind while extendsH) is never rewritten on load. Only `ResolvedEdge` falls back.
- **Diagnostics.** `cfgLines` prints `attach.edge` as non-default only when mode == container. This is consistent with the Problem D fix B.

## 6. Tests and smoke checks

### Headless tests

A new tests/test_anchors_edges.lua, plus changes to existing suites.

1. `EdgePoints` for 4 growth combos x 9 tokens matches the §1 table.
2. `EdgePoints(L, "after-start") == DerivedPoints_old(L)` for all 8 axis/growH/growV combos (the no-visual-change pin).
3. `EdgeAllowed`:
   - no before or CENTER token exists;
   - behind is refused when the effective axis is horizontal, or when perLine > 0, with the reason from NS.L;
   - behind is allowed for a single column;
   - after and ahead are always allowed.
4. `ResolvedEdge`: stored `behind-start` with the root axis flipped to horizontal resolves to `after-start`, the store is unchanged, and flipping back restores it.
5. `SeamOffset(L, side)`:
   - ahead x = +lineSpacing for a column child and +spacing for a row child;
   - behind is negated;
   - growH left mirrors both;
   - y is 0 for sides;
   - nudge is additive;
   - clearStrip only for after (test_anchors_seam).
6. Mirroring: `ahead-start` with the root's growH changed right->left places TOPRIGHT->TOPLEFT and writes nothing.
7. Chain A<-B<-C with mixed edges: C's points come from A's flow; detaching B re-flows C from B.
8. `FlowChangeOnAttach`: nil when flows match; the changed keys and follower count when they differ; the target's root is used, not the target.
9. Panel intercept (test_optionssetup / test_pages_layout, with mocked `StaticPopup_Show`):
   - a differing-flow container write does not store and requests a refresh;
   - OnAccept stores through SetByPath;
   - OnCancel stores nothing;
   - OnAccept in combat is refused;
   - a mode write with container = 0 shows no popup;
   - `/am set` writes and prints the info line.
10. Layout page:
    - the Side row is drawn only in container mode;
    - its values are filtered;
    - its labels are absolute per growth (4 combos);
    - `/am set container.attach.edge behind-start` on an icon row is refused with a reason;
    - the fallback note appears when the stored edge differs from the resolved one.
11. `StripSide`:
    - root: before;
    - after follower: behind;
    - after follower with a behind follower of its own: ahead, or inside when extendsH;
    - side follower: before, with the push when the parent's strip is on the same side;
    - clamp insets per side;
    - no allocation on a repeat visibility pass (perf scenario).
12. The parent is re-applied when a child's edge, mode or container changes (test_containermanager).
13. Join pin: shown while unlocked and container-attached, hidden when locked, in screen mode and in frame mode; placed at the child point.
14. `MigrateV9`:
    - stamps nil, keeps an existing value, repairs an unknown value;
    - screen 0/-4 -> 0/0, frame untouched, container untouched;
    - idempotent;
    - the ladder's `to = 9` equals `NS.SCHEMA_VERSION` (test_migrations).
15. Locale: all new strings are keys in NS.L and ASCII (test_locale). The docs test covers the new smoke numbers.

### In-game smoke checks (new docs/smoke-tests.md entries)

- **S1.** After loading the v9 build, every existing chain (Weapon Enchants under Buffs; Offensive->Defensive->Raid; the Target Debuffs chain growing up) is pixel-identical to v8, locked and in test mode. `/am get container.attach.edge` on #5 gives after-start.
- **S2.** Bars parent growing down: the Side list shows Bottom left, Bottom, Bottom right, Right top/middle/bottom and Left top/middle/bottom, and no Top entry. Pick each one; the child moves there with a gap equal to its own spacing (after) or line spacing (sides).
- **S3.** Flip the parent to grow up. Bottom* entries now read Top*, the child mirrors, and no dialog appears.
- **S4.** Icon-row child: no Left entry. `/am set container.attach.edge behind-start` prints a refusal with its reason.
- **S5.** Bar child set to Left top, then Per row or column set to 3. The child moves below the parent and the gray note explains; setting it back to 0 returns it to the left.
- **S6.** Attach a container that grows up to a parent that grows down. The popup names both and the flow. Cancel: the dropdown reverts to None and nothing moves. Attach: it attaches, and its own Growth tab still shows the dimmed inherited values. Detach: its own "up" comes back.
- **S7.** The same attach attempted in combat is refused on accept.
- **S8.** Text chain #13->#14->#15 centred: set Side to Bottom on #14 and #15. The lines are centred under each other after changing Width and toggling Size to fit (closes Problem C by user choice).
- **S9.** Unlocked:
  - a diamond sits exactly at each join;
  - a Bottom-attached follower's strip sits beside its first element, not over the parent;
  - a Right-attached follower's strip sits above it and does not overlap the parent's strip;
  - no strip is left over after lock.
- **S10.** A chain where B is attached Left of A and C is attached below B: B's strip moves to its free side (right, or inside) and C's strip does not overlap B's first element.
- **S11.** `/am diagnostics` lists `attach.edge` only for container-mode containers, and screen containers no longer list `attach.y=-4`.
- **S12.** Test mode on and off with side attachments: the geometry is identical locked, unlocked and in test mode (requires Problem A's hang-mode fix).

## 7. Open questions for the owner, with a recommendation for each

1. **Store the side relative to the flow (after/ahead/behind), or as absolute points?** Recommendation: relative. Nothing becomes invalid when the root's growth flips, and the chain mirrors as a unit. The UI still shows absolute names.
2. **Popup that keeps inheritance, or popup that overwrites the child's Growth settings?** Recommendation: keep inheritance; the popup confirms but does not overwrite. Detach restores the child's own settings, and later root changes need no cascade of writes or dialogs.
3. **Let a side-attached child keep its own horizontal growth, so an icon row can sit on the parent's Left and grow away from it?** Recommendation: not now. Inherit all three FLOW_KEYS as today, and offer Left only to one-wide children. Revisit with #22.
4. **Allow Top for a single-row child** (it can never grow back)? Recommendation: no. Follow the owner's rule literally, which also keeps the strip's "before" side free.
5. **Should a new attachment of a CENTER- or RIGHT-justified Text container default to Bottom or Bottom right?** Recommendation: no automatic change. Show a gray hint on the Anchor tab for Text children whose justify is not LEFT ("Bottom lines centred text up with its parent").
6. **Problem A (the unlocked "slot" hang).** Recommendation: drop `slot` (option B) before this ships, or restrict it to a pristine parent (option A). Side and centre points need one geometry locked and unlocked.
7. **Popup on detaching a mid-chain container whose own flow differs?** Recommendation: a chat line only. Detaching is the user undoing a choice, and a dialog there adds friction.
8. **Fold the screen-mode 0/-4 -> 0/0 reset (Problem D-C) into v9?** Recommendation: yes. v8 cannot be extended, and it is invisible until a mode switch, when it would silently add 4px.
9. **Issue #22 (drag to attach).** Recommendation: build it on this model later. The drop picks the nearest allowed token of the nine (the nearest point among `EdgePoints` on the target), and drag-away detaches to screen at the drop position with `attach.x/y` reset. Record this in #22 and keep it out of this change.
10. **Diamond pin, or just the specific tooltip line?** Recommendation: both. The pin costs one texture per container, is shown only while unlocked, and removes the ambiguity from the beside strip.

Files: `/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Anchors.lua`, `/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/settings/Layout.lua`, `/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/settings/OptionsSetup.lua`, `/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/ContainerManager.lua`, `/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/modules/Container.lua`, `/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/core/Database.lua`, `/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/defaults/Profile.lua`, `/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/settings/Containers.lua`, `/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster/docs/superpowers/specs/2026-09-25-feedback-batch8-design.md`