Delta: LibKa0s v1.93.0 -> v1.98.0

Recorded before anything was copied. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.98.0 LibKa0s testkit tools | tar -x -C <scratch>/new` (tag commit 9dd6d09; `git -C ../LibKa0s ls-remote --tags origin v1.98.0` shows the tag pushed, so this is a re-vendor, not a refresh). Run under the Aura Master WoW Forever port, item AM-FP01 (`docs/superpowers/plans/2026-11-14-auramaster-forever-port.md`).

## Step 0 pre-flight (this addon)
- Newest single-tag bundle `docs/revendor/2026-11-07-v1.93.0/` states `Delta: LibKa0s v1.92.0 -> v1.93.0`.
- The commit that rolled the line to v1.93.0 is ad6482d, whose parent's `CLAUDE.md` names v1.92.0. ok, no base correction.

## 3a Base
- `grep -n 'Bundles' CLAUDE.md` -> `36:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.93.0 (MIT).`
- Last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 238bbed (WFP-RV2-AM); its `CLAUDE.md` names v1.93.0. They agree.
- Payload before the copy equals the library at v1.93.0: `diff -rq <scratch>/claimed/LibKa0s libs/LibKa0s` prints only `Only in <scratch>/claimed/LibKa0s/media/icons` lines (the undeclared icons), and `diff -rq <scratch>/claimed/testkit tests/_kit` prints nothing.
- Range: `git -C ../LibKa0s log --oneline v1.93.0..v1.98.0` is 44 commits, five releases (v1.94.0 through v1.98.0); `git -C ../LibKa0s diff --stat v1.93.0 v1.98.0` is 203 files, +117900 / -427 (most of it the Callout voice packs and two fonts).

## 3b/3c Per-file minors that moved (old = this addon, new = v1.98.0)
Command: the spec's loop over `git -C ../LibKa0s show v1.98.0:LibKa0s/LibKa0s.xml`'s file list, printing rows where old and new differ.
```
Compat.lua           old: LibKa0s-Compat-1.0 3     new: 4    (v1.94.0)
Skin.lua             old: LibKa0s-Skin-1.0 17      new: 18   (v1.94.0)
Role.lua             old: none                     new: LibKa0s-Role-1.0 1      (v1.95.0, new file)
Launcher.lua         old: LibKa0s-Launcher-1.0 9   new: 10   (v1.95.0)
DebugLogDiagnostics  old: DIAG_MINOR 7             new: 9    (v1.95.0 8, v1.96.0 9)
Callout.lua          old: none                     new: LibKa0s-Callout-1.0 2   (v1.96.0 1, v1.98.0 2, new file)
CalloutSettings.lua  old: none                     new: SETTINGS_MINOR 3        (v1.96.0 1, v1.97.0 2, v1.98.0 3, new file)
Media.lua            old: LibKa0s-Media-1.0 12     new: 13   (v1.97.0)
SkinDefsOthers.lua   old: OTHERS_MINOR 8           new: 9    (v1.97.0)
```
Every other file matches v1.93.0, and before the copy every file matched the v1.93.0 extract: no cross-major skew.

## 3d Diffs
Before the copy: as 3a. After the copy and before the prune, both payloads' content diffs against the v1.98.0 extract must be empty; after the prune only `Only in <scratch>/new/LibKa0s/media/icons` and `.../media/sounds` lines may remain. Results in 05_SUMMARY.md.

## 3e Consumption map
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' --include='*.lua' core modules settings defaults locales`:
```
core/Bus.lua                  LibKa0s-Bus-1.0
core/Compat.lua               LibKa0s-Compat-1.0
core/CoreSetup.lua            LibKa0s-Core-1.0
core/Database.lua             LibKa0s-Skin-1.0 (two sites)
core/Database_Migrations.lua  LibKa0s-Skin-1.0
core/DebugLogSetup.lua        LibKa0s-DebugLog-1.0
core/EnvSetup.lua             LibKa0s-Env-1.0
core/LauncherSetup.lua        LibKa0s-Launcher-1.0
core/LifecycleSetup.lua       LibKa0s-Lifecycle-1.0
core/MediaSetup.lua           LibKa0s-Media-1.0
core/PerfSetup.lua            LibKa0s-Perf-1.0
core/PoolSetup.lua            LibKa0s-Pool-1.0
core/Secrets.lua              LibKa0s-Compat-1.0
core/SkinSetup.lua            LibKa0s-Skin-1.0
modules/Anchors.lua           LibKa0s-Widgets-1.0
settings/OptionsSetup.lua     LibKa0s-Skin-1.0, LibKa0s-Options-1.0
settings/Schema.lua           LibKa0s-Schema-1.0
settings/Slash.lua            LibKa0s-Slash-1.0
```
Majors in the payload with no lookup here: Callout (new), Role (new), Charts, Glow, IconBrowser, Item, Sim, Toast.

Moved minors intersected with consumed majors, the set 3g reads: Compat, Skin (Skin.lua, SkinDefsOthers.lua), Launcher, DebugLog (DebugLogDiagnostics.lua), Media.

## 3f Kit revision
```
grep -n 'Kit.VERSION' <scratch>/new/testkit/framework.lua tests/_kit/framework.lua
new: 20:Kit.VERSION = 56
old: 20:Kit.VERSION = 53
```
Revisions 54 (client_globals split under CCN 15, no behavior change), 55 (the `LibKa0s sounds:` gate on `media/sounds/`, no line meaning none) and 56 (the glyph guard's face list). The kit moves with the library in one commit, both copied whole; the pairing rule (v1.9.0+ needs kit 11+) holds by construction.

## 3g Contract delta and Blockers
Read per consumed major whose minor moved, from the tag's `CHANGELOG.md` blocks and `docs/api/`:
- **Compat 4** (`docs/api/Compat/version-4-docs.md:22-25`, `:79-80`): `RegionalNames`, `UnitCharacterName`, `CharacterKey`, `RealmKey`. Additive; no existing member moved.
- **Skin 18** (`docs/api/Skin/version-18.1.27.8.19.19.1.1.17.4.9-docs.md:23-25`, `:420-421`, `:441`): `Skin:DefaultSkin()` is new, and an empty or non-string skin given to `RegisterOwner`'s first read, `WriteChoice` or `SetChoice`, and an unregistered owner's `GetChoice`, now answer `DefaultSkin()` (`"forever"` on the Forever client) where they answered `"ka0s"`. This addon's owner `get` (`core/SkinSetup.lua:601`) always hands a string (`"ka0s"` from `defaults/Profile.lua:55`, or before `NS:InitDB`), so its path does not reach the changed cleaning. Retail answers are unchanged. Not a blocker: moving the profile default to the client's skin is the port's item AM-FP02.
- **SkinDefsOthers 9** / **Media 13** (`docs/api/Media/version-13.1-docs.md:20`): two faces join `FONTS` and `__FACE_SIZES` (33 -> 35). Additive. No suite here counts `FONTS` or `__FACE_SIZES`.
- **Launcher 10** (`docs/api/Launcher/version-10-docs.md:21-24`): `checkDescriptor` peel, no member or behavior change. No suite here pins `Launcher 9`.
- **DebugLogDiagnostics 9** (`docs/api/DebugLog/version-22.9.1.4-docs.md:21`, and `version-22.8.1.4-docs.md:25`): the report's `LibKa0s running:` line names Role and Callout when the winning copy has them. No member change. No suite here pins `DebugLogDiagnostics 7`.

Host-supplied members, `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`: none.

Tests loading library files by name: none; `tests/run.lua:21`, `tests/perf.lua:47` and the suites that rebuild a namespace read `Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")`, so `Role.lua`, `Callout.lua` and `CalloutSettings.lua` load in the shipped order with no loader line.

`VendorSync.register` with its own `pairs`: no (`tests/test_vendor_sync.lua:23` passes `{}`), so the kit's default library pair carries `sounds = "media/sounds"`.

**Blockers: none.**

## 3h Unrecorded vendored tags
The spec's walk from the store's first bundle (horizon 2026-09-12), payload commits plus `CLAUDE.md` line rolls, against the store's bundle tags: empty. No span bundle.

## 3i The icon declaration, and the sound declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md` -> `37:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset, settings, volume-high.` It is the next non-blank line under the provenance line, the line is one sentence, and nothing in this port draws a new catalog name. Kept as written.
- Sounds (kit revision 55): this addon adopts no Callout, so it ships no voice pack. No `LibKa0s sounds:` line is written: no line means none, and the prune removes `media/sounds/` whole. Decided by this run (adopt nothing beyond the port's need).
- Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`); the owner's in-client smoke stays the backstop for a name the host forgot to declare.

## 3j Tests that assume the whole icon folder
`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`:
```
tests/test_optionssetup.lua:483-484  opens libs/LibKa0s/media/icons/info.tga (declared)
tests/test_vendor_sync.lua:10        comment
```
Neither assumes an undeclared icon. No blocker.
