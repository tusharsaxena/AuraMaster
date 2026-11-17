# 02 Candidates, LibKa0s v1.98.0 -> v1.105.0

Sources: `git -C ../LibKa0s log --oneline v1.98.0..v1.105.0`; the LibKa0s `CHANGELOG.md` blocks v1.99.0 to v1.105.0, including v1.105.0's *What a consumer owes*; the `docs/api/` documents named per row; Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/03_ADOPTION_PLAN.md` and its research notes R3 and R7. The base is v1.98.0, from this addon's `CLAUDE.md` provenance line.

**Class A, delivered by the copy alone (smoke lines)**
- Header marks (#86): the debug console, the copy window, the perf panel and the skin picker carry **extras, settings, close** on the title band. The settings mark opens Aura Master's settings through the launcher's registered opener. The skin picker's gear moves into its header.
- The console (#79, #90): its status line is a 24 px Widgets footer, with the counter in `text.muted`. Copy hands out plain text.
- Library tooltips (#92): library dropdown entries open beside their menu, the skin picker's toolbar tips attach below their control, and the minimap tooltip opens toward the screen's center, 2 px off the button. The container drag strips are unchanged wherever `modules/Anchors_Tooltip.lua` places them. Where nothing reads, they attach below the strip instead of following the cursor (01_DELTA 3g).
- Skin colors (#82, #84): Ka0s Default's list rows (stripe .08, hover .16, selection .26), seven skins' `icon.hot`, and the `icon.tint` of Glass and High Contrast.
- Kit revision 57: registered frames are held, plus `mock_screen.lua` and `settings` in `LIBRARY_MARKS`.

**Class B, host change required. Owed in phase [3] (adoption) and not built in this re-vendor**
| # | Candidate | Issue | Evidence | Would touch |
|---|---|---|---|---|
| B1 | Report verbs on `D:Report`: `/am containers` | LibKa0s#79 | `docs/api/DebugLog/version-23.11.1.5-docs.md`; `settings/Slash.lua:68` | settings/Slash.lua |
| B2 | The PresetPicker's own title marks on `W.HeaderButtons`, with a settings mark; the drag strip's opt-in settings mark | LibKa0s#86 | `docs/api/Widgets/version-27.2.7.14.1.7.8.6.1.1-docs.md`; `settings/PresetPicker.lua:478` | settings/PresetPicker.lua, modules/Anchors.lua |
| B3 | Container strips in `/am test` docked as HUD strips (`dock="hud"`) | LibKa0s#88 | 03_ADOPTION_PLAN #88; R7 §3 | modules/Anchors.lua |
| B4 | The PresetPicker's status/footer line on `W.Footer` (24 px) | LibKa0s#89 | 03_ADOPTION_PLAN #89; `settings/PresetPicker.lua:497-505`, `:593` | settings/PresetPicker.lua |
| B5 | Tooltips through `LibKa0s-Tooltip-1.0`: the strip's host placer (`modules/Anchors_Tooltip.lua`) onto `PlaceAttached`, the retired `tooltipOwner = "cursor"` (`modules/Anchors.lua:709`) dropped, and the player option `tooltipAnchor` with its `ANCHOR_CURSOR` and corner anchors (`core/Constants.lua:290-295`, `settings/Layout.lua:531`, `defaults/Profile.lua:249`) migrated | LibKa0s#92 | `docs/api/Tooltip/version-1-docs.md`; 03_ADOPTION_PLAN #92 (**owner ruling needed** on whether the player choice survives) | modules/Anchors*.lua, settings/Layout.lua, core/Constants.lua, defaults/Profile.lua, a schema migration |

**Not applicable to this addon**
- LibKa0s#85 (Callout consumers): Aura Master is not a candidate.
- LibKa0s#87 (`Sim.Sample`): Aura Master looks up no Sim and its test mode names no character, so there is nothing to swap.
- LibKa0s#80 (`W.Bar`) and #81 (`extraEntries`): Skill Master only.

**Class C, whole-module**: Tooltip (new, through B5), WaypointArrow (new; there is no waypoint here), and Callout, Role, Charts, Glow, IconBrowser, Item, Sim and Toast, whose earlier non-adoption premise is unchanged.

**Blockers (3g)**: none.
