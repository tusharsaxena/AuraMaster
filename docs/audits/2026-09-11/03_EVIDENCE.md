# 03 — Evidence: Ka0s Aura Master (2026-09-11)

**How to read this file:**

- Every command below was executed from the repo root
  (`/mnt/d/Profile/Users/Tushar/Documents/GIT/AuraMaster`) during this run. The output is pasted as it
  came back, trimmed only where marked.
- Each count states its scope: what the command swept and what it excluded.
- Every `file:line` cited in this bundle was re-read in this run, and its text is quoted beside the
  citation. Figures that appear in more than one artifact were reconciled: 02 and 05 carry the same
  numbers.

Standard: **v2.42.0 (2026-09-10)**, taken from `standards/STANDARDS.md:1`
(`# Ka0s WoW Addon Standard (v2.42.0, 2026-09-10)`).

---

## E-1 Lint

```
$ luacheck . | tail -1
Total: 0 warnings / 0 errors in 62 files
```

**Scope:** `.luacheckrc:9`, `exclude_files = { "libs/", "tests/_kit/", "docs/audits/", "docs/reviews/",
"docs/automated-tests/", "_dev/" }`. Only `tests/_kit/` is excluded under `tests/`.

- The harness global is in `files["tests/"]` (`.luacheckrc:37-40`: `globals = { "AM_TEST" }`).
- There is no top-level `ignore`. One narrowed ignore exists: `files["core/AuraMaster.lua"] =
  { ignore = { "212/self" } }` (`:31-33`).
- One inline ignore, also narrowed: `settings/Schema.lua:169`
  `function NS.SchemaForPage(pageKey, filter)   -- luacheck: ignore 212/filter`.

## E-2 Headless suite

```
$ lua tests/run.lua | tail -3
  PASS  eol: every tracked file carries the terminator .gitattributes declares for it

154 passed, 0 failed, 0 skipped, 154 total
$ lua -v
Lua 5.1.5  Copyright (C) 1994-2012 Lua.org, PUC-Rio
```

The run includes these parity cases:

- `parity: the Core stub publishes everything core/CoreSetup.lua publishes live`
- `parity: the DebugLog stub carries every member the addon calls`
- `parity: the Options stub carries every helper a page file reaches at load`
- `parity: the Slash stub carries every dispatcher member the addon calls`

and the vendored-payload cases `libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles`
and `tests/_kit is the test kit that shipped with that release`. The `README.md:6` badge reads
`Tests-154%2F154_passing`, which matches.

## E-3 Standard resolution

- `curl -fsSL "$RAW/AUDIT.md"` saved 594 lines. `curl -fsSL "$RAW/standards/STANDARDS.md"` saved 187
  lines.
- The 26 `standards/standards/*.md` files were discovered from the Sections list
  (`grep -o '(standards/[a-z-]*\.md)' STANDARDS.md | sort -u | wc -l` returned `26`), and all 26 were
  fetched. None failed.

## E-4 Deviation register

`docs/ARCHITECTURE.md:255` `## Documented deviations` and `:257` `None.`. There are zero rows, so no
triggers or evidence IDs need evaluating.

## E-5 Issue store

The CLI subcommand was used; no GraphQL.

```
$ gh issue list --state all --limit 200 --json number,title,state,labels,url
#2 OPEN  "Add a Text container style"        labels: enhancement, state:triaged, severity:low
#1 OPEN  "Support party members (party1-party4) as container units"
                                             labels: enhancement, state:triaged, severity:medium
```

- No title carries a `[status]` prefix.
- `ls docs/pending` fails: `docs/` holds no `pending/` directory (from the full `ls docs` in this run).
- Both issues are feature deferrals. Neither is a declined rule, so neither owes a register row.

## E-6 Vendored Ka0s-owned library: diffed against the tag CLAUDE.md names

The provenance line is at `CLAUDE.md:35`: `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
v1.29.0 (MIT).`.

The sibling `../LibKa0s` was confirmed as `origin https://github.com/tusharsaxena/LibKa0s.git`, with
tag `v1.29.0` present. It was archived at the tag, not at HEAD:

```
$ git -C ../LibKa0s archive v1.29.0 LibKa0s testkit | tar -x -C $SCRATCH/lk
$ diff -r $SCRATCH/lk/LibKa0s libs/LibKa0s ; echo rc=$?
rc=0
$ diff -r $SCRATCH/lk/testkit tests/_kit ; echo rc=$?
rc=0
```

Both diffs are empty, over every module and `media/`. Nothing is missing on the addon side, so there
is no #48. There is no harness under `libs/`: `ls libs | grep -i kit` returned nothing.

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md
35:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.29.0 (MIT).
$ grep -n 'Bundles \[LibKa0s\]' README.md                         # no output
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md   # no output
$ grep -n 'WoW_Addon_Standard' README.md
5:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
```

The badge is bare, not linked. **Compliant.**

## E-7 Line endings

```
(a) test -f .gitattributes                          -> present
(b) grep -n '^\* text=auto eol=\(crlf\|lf\)$'        -> 26:* text=auto eol=crlf      (client-bound: .toc present)
(c) grep -n '^\*\.sh text eol=lf$'                   -> 34:*.sh text eol=lf
(d) grep -c ' binary$'                              -> 20
(e) the AUDIT.md one-liner (git check-attr text eol + byte counts), run as written -> 0
body: diff --strip-trailing-cr <(head -81 .gitattributes) <canonical client-bound body from line-endings-§5>  -> rc=0
tail: tail -n +82 .gitattributes | wc -l            -> 0
```

- **Scope of (e):** every file `git ls-files` lists (302 tracked). Files with `text` unset (binary)
  are skipped.
- Result: **0 tracked files disagree with the declared pin.**
- The gate that owns (e) is `tests/_kit/test_eol.lua` (kit revision 15, from `tests/_kit/framework.lua:20`,
  `Kit.VERSION = 15`). It passed in E-2.

## E-8 Package ignore list

```
(a) for e in .luacheckrc .pkgmeta .gitignore .gitattributes .claude .superpowers docs tests _dev; ... -> (no NOT IGNORED lines)
(b) for e in .[!.]*; ...                                                                    -> UNACCOUNTED — .git
```

`.git` is the one entry the packager never sees, so it is exempt. **Compliant.**

## E-9 Runner mode, and the missing assertion (AM-18)

```
$ git ls-files -s tests/_kit/run-automated-tests.sh
100755 f6cd8b0a86aaf87d394e9ebaf0decf9e13c4e10c 0	tests/_kit/run-automated-tests.sh
$ grep -n '100755' tests/_kit/*.lua tests/*.lua            # no output
```

**Scope:** the kit and the addon's own suites. No case asserts the recorded mode.

## E-10 Complexity: measured, then compared with the latest bundle

```
$ lizard --version
1.24.0
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .     # verbatim invocation (performance-§10)
...
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
      6820       6.6     2.8       53.8      676            0      0.00    0.00
```

- **Functions at CCN 12 or above**, current run and bundle
  `docs/automated-tests/20260911-141809/complexity.txt` alike (identical rows):
  - `NS.OnProfileChanged` 12
  - `NS.ResolveColor` 14 (the degraded stub)
  - `initSummary` 12
  - Container `Update` 12, `Apply` 14 and `ApplyVisibility` 13
  - `applyCategory` 13
  - `FP.NamedAncestor` 14
  - FramePicker `onUpdate` 13
  - `Preview.Offset` **15**
- **RESULTS.md row** (`docs/automated-tests/RESULTS.md:26`):
  `| 20260911-141809 | 0.1.0 | 0/0 | 62 | 154/0/154 | pass | 6820 | 676 | 6.6 | 2.8 | 15 | 0 | green |`.
- **Drift: none.** The bundle is stamped today. No function crossed a threshold and no file entered
  the band.
- **Watch list:** "None.", with 0 Accepted entries, so anti-pattern #53 has nothing to count.
- `Preview.Offset` at 15 is arithmetic with `and`/`or` defaulting (`modules/Preview.lua:23-48`), not
  tangled control flow. It sits at the release-gate boundary, not over it.
- No `docs/complexity.md` exists.

## E-11 Largest authored files

`wc -l` over all authored Lua: the maximum is `locales/enUS.lua` at 447, and no file is at or over
1000.

## E-12 TOC tail

`tail -c 4 AuraMaster.toc | od -c` printed `u a \r \n`, which is one trailing newline in the CRLF tree.

## E-13 Close-button, media and skin greps

```
$ grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
./core/CoreSetup.lua:94:    return lib.MakeCloseButton(parent, onClick, addonName)
$ grep -rn 'NS.SKIN\|ApplySkin' --include='*.lua' core modules settings
core/CoreSetup.lua:52:    NS.SKIN            = {}
core/CoreSetup.lua:53:    NS.ApplySkin       = function() end
core/CoreSetup.lua:82:NS.SKIN      = lib.SKIN
core/CoreSetup.lua:83:NS.ApplySkin = lib.ApplySkin
$ grep -rn 'NS\.Pool' --include='*.lua' core modules settings
core/PoolSetup.lua:16:NS.Pool = Pool or {
modules/Preview.lua:64:        pool = NS.Pool.New()
modules/Preview.lua:67:    NS.Pool.ReleaseAll(pool)
modules/Preview.lua:76:        local f = NS.Pool.Acquire(pool, factory(container.anchor))
modules/Preview.lua:87:    if container.previewPool then NS.Pool.ReleaseAll(container.previewPool) end
```

**Scope:** the first grep ran over the whole repo minus `libs/` and `tests/`. The other two ran over
`core/ modules/ settings/`.

These support AM-09: `core/CoreSetup.lua:80` reads `-- The shared window edge, published flat so the
frame picker's overlay reaches it by name rather than`, but no consumer exists. `core/PoolSetup.lua:5`
reads `-- Every container re-renders its elements — bars or icons — whenever its unit's auras change, which`,
but the only caller is Preview.

## E-14 Shared media

- `SetAtlas` has zero hits in `core defaults modules settings locales`.
- `Interface\` paths in the addon: the client textures at `core/Constants.lua:14,15,17`, the logo at
  `:26`, and `modules/Style_Bars.lua:46` `am.spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")`.
- `find media -type f` returns only `media/logos/auramaster.logo.{jpg,png,tga}`. There is no overlap
  with `libs/LibKa0s/media/` (fonts, icons and textures).
- The seam: `core/MediaSetup.lua:16` `local addonName, NS = ...`, `:25` `return Media.Icon(addonName, name)`,
  `:39` `if Media then Media.RegisterLSM(addonName) end`. It loads before Constants
  (`AuraMaster.toc:40-43`).
- The console is told the folder name: `core/DebugLogSetup.lua:75` `addonName = addonName,`.

## E-15 Documentation citations (AM-07, AM-08)

**Command:** a Lua script (`$SCRATCH/cites.lua`) that pulls every `path.lua:N` or `path.toc:N`
reference out of each doc and prints the cited source line. Each output line was then checked by hand
against the doc's claim.

**Scope:** `docs/ARCHITECTURE.md` and `DEPENDENCIES.md` in one pass (48 citations: 34 and 14), and
the other 15 `docs/*.md` pages in a second pass (63 citations). Frozen bundles under
`docs/automated-tests/` were excluded.

**Non-resolving citations: 35 of 111.** 12 are in ARCHITECTURE, 21 in the topic docs and 2 in
DEPENDENCIES. Two more are unverified.

**`docs/ARCHITECTURE.md` — 12:**

| Doc line | Cited | Cited line reads | Actually at |
|---|---|---|---|
| :18 | `modules/Container.lua:122` | `if not engine then return end` | `:135` `CreateFrame("AuraContainer", …)` |
| :44 | `core/Database.lua:165` | `-- ------…` | `:172` `AceDB:New(…)` |
| :108 | `modules/ContainerManager.lua:291` | `local ev` | `:301` CONFIG_CHANGED receiver |
| :109 | `modules/ContainerManager.lua:295` | `if not NS.Compat.EnsureAuraContainer() then` | `:305` VISIBILITY_CHANGED receiver |
| :154 | `modules/TimedSpells.lua:84` | *(blank)* | `:96` `RegisterUnitEvent("UNIT_AURA", …)` |
| :155 | `modules/TimedSpells.lua:87` | `if frame then frame:UnregisterAllEvents() end` | `:97` `RegisterEvent("PLAYER_REGEN_ENABLED")` |
| :156 | `core/Database.lua:171-173` | `if AceDB then` | `:175-177` RegisterCallback × 3 |
| :158 | `modules/Container.lua:161` | `self.enchantFrames = {}` | `:178` `callEngine(engine, "SetUnit", …)` |
| :168 | `modules/Container.lua:126-130` | `engine:Hide()` (Retire) | `:139-143` anchor before `AddAuraGroup` |
| :173 | `modules/Container.lua:286-290` | `return (vis == "inCombat") == inCombat` | `:310` `SetEnabled` |
| :185 | `modules/Style.lua:144-146` | `local b = cfg.behavior or {}` | `:149-151` `RightButtonUp` |
| :193 | `modules/FilterCompiler.lua:141` | `elseif not isEmpty(set) then` | `:154-163` `identityWarning` |

**Topic docs — 21:**

- common-tasks.md: `:25` → Container.lua:246, but the structure key is at `:263`. `:81` →
  Database.lua:192 is blank; `SCHEMA_STEPS` is at `:196`.
- data-flow.md:
  - `:21` → CM:291 (`local ev`); the receiver is at `:301`.
  - `:25` → CM:91 (`noteDeferred`); `FlushPending` is at `:120`.
  - `:30` → Container.lua:227 (Restyle loop); `Apply` is at `:244`.
  - `:54` → FilterCompiler.lua:177 (`spellSet`); `Compile` is at `:189`.
  - `:87` → Container.lua:119 is blank.
  - `:92` → Container.lua:267 (`self:Retire()`); `ShouldShow` is at `:294`.
- midnight-quirks.md:
  - `:22` → Compat.lua:27; `AurasAreSecret` is at `:40`.
  - `:36` → Container.lua:122; the engine is at `:135`.
  - `:69` → Container.lua:126-130; the right range is `:139-143`.
  - `:81` → Container.lua:166; the `Signature` compare is at `:194`.
  - `:91` → FilterCompiler.lua:141; the right range is `:154-163`.
  - `:148` → Container.lua:286-290; `SetEnabled` is at `:310`.
- performance.md: `:28` → CM:103 (`inst:Apply()`); the `applyPass` bracket is at `:129-134`. `:29` →
  Container.lua:230; the bracket is at `:247`/`:273`. `:30` → CM:130; the `visibilityPass` bracket is
  at `:141-143`.
- profiles.md: `:19` → Database.lua:165; `InitDB` is at `:169`.
- schema.md: `:9` → Database.lua:165; the right lines are `:169`/`:172`. `:184` → Database.lua:192 is
  blank; the right line is `:196`.
- scope.md: `:67` → FilterCompiler.lua:141; the right range is `:154-163`.

**Unverified — the claim is ambiguous:** `data-flow.md:84` → Container.lua:166, and
`settings-panel.md:208` → Compat.lua:155.

**`DEPENDENCIES.md` — 2:**

- `:20` → `modules/ContainerManager.lua:284` (`NS.bus:SendMessage(NS.MSG.CONTAINERS_CHANGED)`). The
  no-engine notice is at `:296`.
- `:28` names `` `Compat.IsAddOnLoaded` (`core/Compat.lua:206`) ``. `:206` is
  `if cs and cs.GetSpellInfo then`. No `Compat.IsAddOnLoaded` exists; the E-17 grep lists every shim.

## E-16 Wrapped-strip invariant (AM-06)

```
$ grep -n 'wrap\|pitch\|selected' tests/*.lua     # only unrelated hits: preview perLine wrap, "selected container"
$ grep -n 'y offset\|rowY\|band' tests/test_optionssetup.lua   # no output
```

The library side, read for the (h) check only: `libs/LibKa0s/OptionsWidgets.lua:411` `-- So the pitch
is measured ONCE, from the INACTIVE cap atlas, on a throwaway texture -- never read`, and `:442`
`if measuredArtH then return measuredArtH end`.

## E-17 Compat shim count

```
$ grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.' core/Compat.lua
17
```

The count agrees with `docs/ARCHITECTURE.md:235`.

## E-18 Re-typed defaults (AM-12)

```
$ grep -nE 'tonumber\([^)]*\) or [0-9.]+|\.(strata|justify|fontFlags|point|relativePoint|icon|tooltipAnchor) or "' modules/*.lua \
    | grep -vE 'or (0|1)([^.0-9]|$)' | wc -l
15
```

**Scope:** `modules/*.lua` only. The identity values `0` and `1` were excluded as neutral.

Twelve of the 15 lines restate a `defaults/Profile.lua` value:

- Anchors.lua:52 `"CENTER"` (template `position.point`)
- Anchors.lua:90 `"TOPLEFT"`, and `"BOTTOMLEFT"` on the continuation line (`attach`)
- Container.lua:258 `"MEDIUM"`
- Container.lua:259 `5`
- Style.lua:51 `11`
- Style.lua:119 `32`, `32`
- Style.lua:122 `220`, `18`
- Style.lua:152 `"ANCHOR_BOTTOMLEFT"`
- Style.lua:162 `5`
- Style_Bars.lua:69 `"LEFT"`
- Style_Bars.lua:141 `8`
- Style_Icons.lua:76 `0.6`

The other three (`Style.lua:52,63,65`) are generic guards.

## E-19 Pre-formatted print sites (AM-14)

```
$ grep -nE 'print_?\(\(?"[^"]*"\)?:format|print_?\([^)]*\.\. ' core/*.lua modules/*.lua settings/*.lua | wc -l
13
```

**Scope:** `core/ modules/ settings/`.

The sites: OptionsSetup.lua:209, Slash.lua:69, 125, 134, 153, 161, 171, 193, 198, 246, 257, 258 and
269. None formats a value from a protected API.

## E-20 British-spelling sweep (localization-§5)

**Command:** a Lua script carrying the canonical `BRITISH` and `ALLOWED` lists whole. `ALLOWED` is
stripped as whole words first.

**Scope:** every tracked file except `libs/`, `tests/_kit/`, `docs/audits|reviews|automated-tests/`
and binaries.

**Result:** 92 hits, all of them at `tests/test_docs.lua:68-90,167,170`. That is the repo's own gate
carrying the published lists and their self-test, which localization-§5 exempts by name. **Zero** hits
in authored prose or code.

## E-21 Locale dead keys

**Command:** a Lua script listing every `L["…"]` key in `locales/enUS.lua` and searching the source of
`core/ modules/ settings/ defaults/` for it. Result: `keys 430 without a literal reader 0`.

## E-22 Combat path citations (AM-01, AM-02)

**AM-01:**

- `modules/Anchors.lua:101` `function Anchors.ResolvePending()`
- `modules/Anchors.lua:102` `if InCombatLockdown() then return end`
- `core/AuraMaster.lua:69` `function addon:OnCombatChanged(event)`
- `core/AuraMaster.lua:71` `if event == "PLAYER_REGEN_ENABLED" then`, then `:72` FlushPending and
  `:73` BlizzardFrames.Apply. There is no ResolvePending.

**AM-02:**

- `settings/Slash.lua:164` `function runDelete(rest)`
- `settings/Slash.lua:168` `local ok, err = NS.ContainerManager.Delete(c.id)`
- `settings/Slash.lua:192` `if InCombatLockdown() then return print(L["Cannot pick a frame during combat"]) end`.
  This is the only combat guard among the registry verbs:
  `grep -n InCombatLockdown settings/Slash.lua settings/Containers.lua modules/ContainerManager.lua`
  returned `Slash.lua:192` and `ContainerManager.lua:87` only.
- `modules/ContainerManager.lua:213` `CM.Announce()`
- `modules/ContainerManager.lua:61` `CM.Sync()`
- `modules/ContainerManager.lua:53` `inst:Destroy()`
- `modules/Container.lua:126` `engine:Hide()`
- `modules/Container.lua:333` `self.anchor:Hide()`
- `modules/Container.lua:305` `--- aura button's ancestry must not be shown or hidden.`
- `core/AuraMaster.lua:111` `if NS.ContainerManager and NS.ContainerManager.Announce then NS.ContainerManager.Announce() end`

## E-23 Remaining citations

**AM-03:**

- `modules/Style.lua:41` `return NS.ResolveColor(stored, useClass, "player")`
- `settings/Bars.lua:21` `local PLAYER = { source = "player" }`
- `settings/Icons.lua:18` `local PLAYER = { source = "player" }`
- `libs/LibKa0s/OptionsCompose.lua:157` `classColorSource = source,` (the composer stamp)
- `docs/ARCHITECTURE.md:205` `- **Class colors resolve to the player's class** on every surface; an element describes an aura, not`

**AM-04:**

- `modules/TimedSpells.lua:79` `frame = CreateFrame("Frame")`
- `modules/TimedSpells.lua:96` `f:RegisterUnitEvent("UNIT_AURA", "player", "pet")`
- `modules/TimedSpells.lua:97` `f:RegisterEvent("PLAYER_REGEN_ENABLED")`
- `modules/TimedSpells.lua:75` `--- The event frame. UNIT_AURA goes through RegisterUnitEvent for the two units scanned, so the client`

**AM-05:**

- `settings/Bars.lua:76` `dialogControl = "LSM30_Statusbar", values = H.LSMValues("statusbar"), label = L["Background texture"],`
- `settings/Bars.lua:80` `prefix = P, page = PAGE, group = G_BG, subgroup = L["Background"], key = "bgColor",`
- `modules/Style_Bars.lua:133` `am.bg:SetTexture(Style.Fetch("statusbar", b.bgTexture, C.FALLBACK_TEXTURE))`
- `modules/Style_Bars.lua:131` `am.fill:SetAlpha(tonumber(b.barAlpha) or 1)`

**AM-10:** `core/EnvSetup.lua:27` `if GetAddOnMetadata then` and `:28`
`return GetAddOnMetadata(addonName, field)`.

**AM-11:**

- `core/PerfSetup.lua:65` `suspend = function()`
- `modules/ContainerManager.lua:120` `function CM.FlushPending()`. The body at `:121-136` has no
  `suspended` check.
- `modules/ContainerManager.lua:301` `ev:RegisterMessage(NS.MSG.CONFIG_CHANGED, function(_, payload)`

**AM-13:** `settings/Slash.lua:134` `print(L["Selected"] .. " " .. describe(c))`;
`modules/ContainerManager.lua:186` `c.name = CM.UniqueName(c.name ~= "Container" and c.name or ("Container " .. id))`;
`:242` `overrides.name = src.name .. " (copy)"`.

**AM-15:** `AuraMaster.toc:57` `core\Secrets.lua`, `:63` `core\Database.lua`, `:72`
`modules\TimedSpells.lua`, `:88` `settings\Slash.lua`, `:91` `settings\About.lua`. None has a comment
above it.

**AM-16:**

- `modules/ContainerManager.lua:123` `if CM.MustDefer() then`, then `:124` `noteDeferred()` and `:125`
  `return 0`. There is no `NS.Debug` on this path.
- `modules/Anchors.lua:95` `toScreen(anchor, cfg)` and `:96` `return "screen"`

**AM-17:** `modules/TimedSpells.lua:64` `if NS.ContainerManager then NS.ContainerManager.RequestApply() end`;
`settings/General.lua:40` `["enabled"]    = function() NS.ContainerManager.ApplyVisibility() end,`.

**AM-19:** `settings/OptionsSetup.lua:209` `print("|cff808080" .. L["Cannot open settings during combat."] .. "|r")`;
`settings/Layout.lua:176` `NS.OpenOptionsPage(PAGE)`.

**AM-20:** `README.md:20` ``Everything is set up from the addon's page under Settings → AddOns, or from chat with `/am`.``,
followed by `README.md:22` `## Usage`. There is no `## Screenshots` heading anywhere in the file.

## E-24 Retired-notation sweep

```
$ grep -rEn '§[0-9]+\.[0-9]' . --exclude-dir=libs --exclude-dir=_kit --exclude-dir=audits --exclude-dir=reviews --exclude-dir=automated-tests --exclude-dir=.git | wc -l
0
```

**Scope:** the whole repo minus the vendored and frozen directories. Zero hits.
