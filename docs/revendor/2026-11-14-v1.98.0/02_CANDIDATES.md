# 02 Candidates, LibKa0s v1.93.0 -> v1.98.0

Sources: `git -C ../LibKa0s log --oneline v1.93.0..v1.98.0`; LibKa0s `CHANGELOG.md` blocks v1.94.0 to v1.98.0; `docs/releasing.md` step 8's v1.94.0 to v1.98.0 re-vendor notes; the `docs/api/` documents named per row. Base v1.93.0 from this addon's `CLAUDE.md` provenance line.

**Class A, delivered on the copy alone**
- Launcher minor 10 (`docs/api/Launcher/version-10-docs.md:21-24`): `checkDescriptor` peel, same messages, no behavior change.
- DebugLogDiagnostics minors 8 and 9 (`docs/api/DebugLog/version-22.9.1.4-docs.md:21`): the report's `LibKa0s running:` line names Role and Callout when the winning copy has them.
- Media minor 13 and SkinDefsOthers minor 9 (`docs/api/Media/version-13.1-docs.md:20`): `Ka0s Bebas Neue` and `Ka0s Russo One` join `FONTS` (35) and `__FACE_SIZES`; registered with LibSharedMedia by the library, so they appear in this addon's font dropdowns with no host change.
- Skin minor 18's cleaning (`docs/api/Skin/version-18.1.27.8.19.19.1.1.17.4.9-docs.md:25`): an empty skin choice resolves to the client's default. This addon's owner `get` always answers a string, so nothing observable moves on Retail.
- Kit revisions 54 (client_globals CCN split), 55 (the `media/sounds/` gate, no line meaning none) and 56 (glyph guard face list). `tools/prune-icons.lua` now prunes `media/sounds/` in the same run.

**Class B, host change required (candidates, all deferred (port run))**
| # | Candidate | Evidence | Would touch | Recommendation | Blast radius |
|---|---|---|---|---|---|
| B1 | `Skin:DefaultSkin()` as the profile's default skin choice | Skin `version-18.1.27.8.19.19.1.1.17.4.9-docs.md:23`, `:421`; CHANGELOG v1.94.0 *The default skin per client* | `core/SkinSetup.lua`, `defaults/Profile.lua` | deferred (port run): it is the port's own item AM-FP02 (spec §3.2), implemented there, not in this re-vendor | additive |
| B2 | Compat character identity: `RegionalNames`, `UnitCharacterName`, `CharacterKey`, `RealmKey` | Compat `version-4-docs.md:22-25` | `core/Compat.lua` | deferred (port run): this addon names no character or realm (AceDB keys its store), so there is no caller; `tests/test_surface_parity.lua` lists the four as having no caller | additive |
| B3 | Compat client helpers routed onto `NS.Compat` (`IsForever`, `IsRetail`, `ClientKey`, `ForClient`, Compat minor 2, v1.92.0) | Compat `version-4-docs.md` | `core/Compat.lua` | deferred (port run): carried from the v1.92.0/v1.93.0 bundles; the port's AM-FP02 takes it (spec §3.1) | additive |

**Class C, whole-module**
| # | Major | Evidence | Recommendation | Blast radius |
|---|---|---|---|---|
| C1 | `LibKa0s-Role-1.0` (new, v1.95.0) | `docs/api/Role/version-1-docs.md:48` | deferred (port run): Aura Master's shipping code reads no spec or role (spec §2) | additive |
| C2 | `LibKa0s-Callout-1.0` with `CalloutSettings`, its `SchemaRows` write route and the voice packs (new, v1.96.0 to v1.98.0) | `docs/api/Callout/version-2.3-docs.md:20`, `:38` | deferred (port run): no center-screen call-out in this addon; no `LibKa0s sounds:` line, so no pack ships | additive |
| C3 | Charts, Glow, IconBrowser, Item, Sim, Toast (unchanged since v1.93.0) | 3e | deferred (port run): nothing in this range changes the premise of the earlier non-adoption | additive |

**Blockers (3g)**: none.
