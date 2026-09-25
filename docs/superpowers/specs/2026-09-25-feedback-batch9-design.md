# Feedback batch 9 — design spec

- **Date:** 2026-09-25
- **Branch:** `feat/2026-09-25-feedback-batch8`. Batch 8 is not merged yet, and batch 9 fixes batch 8's own output.
- **Source:** the owner's smoke run of batch 8 on 2026-09-25, recorded in `docs/smoke-tests.md` section Z,
  plus requests made during that run.
- **Plan:** `docs/superpowers/plans/2026-09-25-feedback-batch9.md`
- **Evidence:** `docs/superpowers/research/2026-09-25-feedback-batch9-findings.md`: root causes for
  problems A to D, and the anchor-point design draft (its sections 0 to 7). **Where this spec differs from
  it, this spec wins.**

Requirement IDs: `HG` hang, `AP` attach points, `GC` growth conflict, `SEP` separation, `TX` Text,
`LJ` label justify, `DX` diagnostics, `MG` migration.

## 1. Owner decisions (2026-09-25)

| # | Decision |
|---|---|
| E1 | **Owner amendment, 2026-09-25 (replaces the original E1, which removed the `slot` hang outright): an unlocked chain hangs from a placeholder only while its parent is predicted empty.** The `slot` hang mode (B8-P6) stays, gated on `Container:PredictEmpty() == true`. While unlocked and not in test mode, a follower hangs from its parent's one-element slot only when the parent is predicted empty; `nil` (not knowable) and `false` (not empty) hang it from the engine, as locked does. The parent's one-element placeholder outline shows only while it is predicted empty, and is hidden otherwise. In test mode a follower hangs from the preview extent, as before. The #9 collapse remains only where the prediction is not knowable or in combat, and is documented as a known limitation. Owner's words: "When unlocked and empty, create a placeholder block and have anchors attach to that. Do this only if that container is empty. If it's not empty, hide that placeholder block." The adopted design is the findings' final section, "Addendum (2026-09-25): an empty-only placeholder for unlocked chains". |
| E2 | **Attach points are user-chosen, within limits** (owner rule): never the side the chain grows away from (Top when it grows down). The side is stored relative to the flow (design §1: `after`/`ahead`/`behind` × `start`/`center`/`end`), so flipping the root's growth mirrors the chain and never invalidates a stored value. The UI shows absolute names ("Bottom left", "Right, middle"). `behind` is offered only to a child that is one aura wide. |
| E3 | **Growth conflicts: a confirm popup, and inheritance stays.** Attaching a child whose own growth differs from the chain root's opens a popup naming the change. Accept attaches, and the child inherits the chain's flow while its own Growth settings are kept and come back on detach. Cancel writes nothing and the dropdown reverts. `/am set` does not prompt; it writes and prints one chat line. |
| E4 | **Separation: a block outline in test mode, and a join marker.** In test mode each container's outline encloses its whole placeholder block. While unlocked, a small gold diamond marks each join, and the strip tooltip names the join ("Joined to the Bottom of 'X'"). A weapon-enchant-only container previews enchant placeholders. |
| E5 | **Default side for a NEW attachment of a Text container follows its justify:** CENTER gives `after-center`, RIGHT gives `after-end`, and LEFT gives `after-start`. Every other style defaults to `after-start`. Existing attachments migrate to `after-start`, so nothing moves. |
| E6 | **Size to fit is Text-only.** v8 stamps `text.autoSize` only on containers whose style is Text. v9 removes `text.autoSize` from bars and icons containers. Diagnostics prints no text-only rows for them. |
| E7 | **Label Justify: Left, Center or Right.** The default depends on the style: bars CENTER, text CENTER, and icons LEFT (RIGHT when growH is left). It is stored nil until the player picks a value, and the dropdown shows the justification in effect. The Layout tab is named **Label** (done, 73e44b5). |
| E8 | **Size to fit must not clip live auras** (owner run: a live "Guardian of Ancient Kings" was clipped). |
| E9 | The remaining design recommendations are adopted as written: no Top even for a single-row child (design §7 q4); a chat line, not a popup, when a mid-chain container is detached (q7); the screen-mode 0/-4 → 0/0 reset folded into v9 (q8); #22 to be built on this model later, with a comment added to the issue (q9). |

## 2. Requirements

| ID | Requirement |
|---|---|
| `HG-1` | *(Owner amendment, 2026-09-25; replaces "`hangModeFor` loses `slot`".)* `Container:PredictEmpty()` answers true, false or nil per the findings addendum (pool of 0, or no unit and no enchants: true; each group read secret-safe through `C_UnitAuras`; enchants through `GetWeaponEnchantInfo`; anything secret, raising or unknown: nil). `hangModeFor(previewing, unlocked, empty)` answers `preview` in test mode, `slot` only when unlocked and `empty == true`, and `engine` otherwise. `ApplyOutline` shows the one-element outline only while unlocked, not previewing and hung as `slot`. The prediction is re-evaluated by a throttled `UNIT_AURA` pass (`RegisterUnitEvent`, for the units of followed parents only), registered only while unlocked, not in test mode, out of lockdown and while auras are not secret, and also on target, focus, pet and inventory changes, at an enchant's expiry and on every apply. `PLAYER_REGEN_DISABLED` forces every parent to `engine`. Secret-safe, and nothing is allocated per event. Update known-limitations (the #9 collapse remains only when the prediction is not knowable or in combat) and smoke checks 191-196. |
| `AP-1` | `Anchors.EDGES`, `ParseEdge`, `EdgePoints(L, token)`, `EdgeAllowed(cfg, token, L)` (false plus an NS.L reason) and `ResolvedEdge(cfg)` (falls back to `after-<align>` at runtime and never writes), per design §1. `DerivedPoints(L)` becomes `EdgePoints(L, "after-start")`. A test pins that it gives exactly the old DerivedPoints for all 8 axis × growH × growV combinations. |
| `AP-2` | `SeamOffset(L, side)`: `after` is unchanged (SS-1). `ahead`/`behind` use the child's own gap across. `attach.x/y` nudge on top (SS-2). `clearStrip` applies only to `after`. |
| `AP-3` | Layout > Anchor > Another container gets a **Side** dropdown (`container.attach.edge`), filtered to the allowed tokens and labelled with absolute names for the effective growth. A stored token that is not currently allowed is still listed, marked "(unavailable)", and a gray note says why and where the child sits instead. The read-only line becomes "Its %s joins the %s of '%s'". |
| `AP-4` | When a new attachment is made (mode or container written to container mode, and no edge chosen yet for this attach), the edge is set per E5. `FLOW_PATHS` gains `attach.edge` and `layout.perLine`. When a child's edge, mode or container changes, its old and new parents are re-applied too (`requestParents`). |
| `GC-1` | `Anchors.FlowChangeOnAttach(childCfg, targetId)` and a panel `confirmWrite` intercept in `settings/OptionsSetup.lua`. The intercept goes on the `attach.container` row, and on the mode row when a usable target is already stored. The `AURAMASTER_ATTACH_FLOW` StaticPopup follows the existing Delete popup's pattern. OnAccept is refused in combat. Cancel refreshes the panel. The `/am set` path prints the chat line. Detaching a mid-chain container whose own flow differs prints a chat line. All strings go through NS.L, in ASCII. |
| `SEP-1` | `ApplyOutline` also draws while previewing, around `self.previewExtent`, and still only while unlocked or in test mode. It draws nothing while locked outside test mode. |
| `SEP-2` | The join pin: a 10x10 gold diamond, created once, placed at the child's attach point while unlocked and attached to a container. Strip tooltip: "Joined to the %s of '%s'. Change the side on Layout > Anchor." |
| `SEP-3` | `StripSide(cfg)` replaces `besideSeam`, per design §4. A strip never covers the parent, and strips never stack. The label follows the strip's side. |
| `SEP-4` | `C.PREVIEW_AURAS.ENCHANT`: `Preview.AurasFor` picks it for a container whose compiled plan has enchants and no aura groups. |
| `TX-1` | With Size to fit on, a live Text line is never clipped. Its FontString is anchored only at the justify point, with no opposite-edge bound and no word wrap. The element width (the budget) is used only for layout, the outline and the strip. Verify in code where the width bound comes from before you change it. Optional: widen the budget with the names in the container's shown spell-list categories and whitelist. |
| `LJ-1` | `label.justifyH` (nil = the style default of E7) and a **Justify** dropdown on the Label tab. `PlaceLabel` uses the resolved value. |
| `DX-1` | `frameShown` is tri-state (nil when unknowable) through `NS.Secrets.CanAccess`. `frameCounts`/`groupButtons` report `?` rather than crash, and each group and prediction runs in its own pcall. midnight-quirks.md records that engine button IsShown is secret out of combat. The DG-3 wording is fixed. Test the crash path with a secret-boolean fake. |
| `DX-2` | `[Cfg]` rows that do not apply (text-only rows on bars and icons, attach offsets and container on a screen container, and so on) are dropped, or listed on a separate `inert` line. `attach.edge` is printed only in container mode. |
| `MG-1` | Change the unreleased v8 step: stamp `autoSize` only when `style == "text"`. Add a new **v9** step: remove `text.autoSize` from bars and icons containers; stamp `attach.edge = "after-start"` where it is missing or unknown; reset screen-mode 0/-4 to 0/0. It is idempotent and tested from v7, from v8 and from v1. `normalizeAttach` on load maps an unknown edge to `after-start`. |

## 3. Constraints

The same as batch 8, spec §3: the standard is binding; the green gate is tests + luacheck 0/0 + lizard CCN
≤ 15 + the 1500-line cap, **run before every commit**; NS.L strings in ASCII; CRLF.
