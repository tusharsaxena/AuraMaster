# 02 - Candidates: LibKa0s v1.59.0 -> v1.60.0

Sources, in the order the spec reads them:

```sh
git -C ../LibKa0s log --oneline v1.59.0..v1.60.0
git -C ../LibKa0s show v1.60.0:CHANGELOG.md          # the v1.60.0 block
git -C ../LibKa0s show v1.60.0:docs/api/DebugLog/version-14.1-docs.md   # Since 14 and Since D1 rows
git -C ../LibKa0s show v1.60.0:docs/api/Slash/version-16-docs.md
```

## A. Delivered on the re-vendor alone

| What | Evidence | Why no host change |
|---|---|---|
| The console keeps **3000** lines (was 1500), compaction slack **128** (was 64), `lib.BUFFER_SLACK` published | `CHANGELOG.md` v1.60.0, *DebugLog minor 14*; `version-14.1-docs.md` *Compatibility* | The frame's `SetMaxLines`, the copy window and `Add` read the constants at call time. `modules/Diagnostics.lua:41-43` reads `lib.MAX_BUFFER` and its `math.min(1200, BUFFER - 100)` cap stays 1200. |
| `lib.TIME_COPY`, the copy-window timing switch | `version-14.1-docs.md` (`TIME_COPY`, Since 14) | A by-hand `/run` switch, off at load; nothing for the host to wire. |
| Slash `LIVE_VERBS` includes `diagnostics` | `version-16-docs.md` (the thirteen reserved verbs) | `settings/Slash.lua:127-137` already added `diagnostics` to the live set it builds from `LIVE_VERBS` (batch 8, owner 2026-09-25). The set is unchanged. |

## B. Host change required

| Candidate | Evidence | Files it would touch | Recommendation | Blast radius |
|---|---|---|---|---|
| **The shared diagnostics report**: `D:RunDiagnostics` / `BuildDiagnostics` / `DebugVerb`, the `brandName` and `diagnostics` descriptor fields, `lib.DIAG_MAX_LINES` and `DIAG_MAX_PER_LIST`, the `out` writer | `CHANGELOG.md` v1.60.0, *DebugLogDiagnostics minor 1*; `version-14.1-docs.md:524-525` (Since D1) | `core/DebugLogSetup.lua` (descriptor), `modules/Diagnostics.lua` (drop its own `Out`/section/`Run` plumbing and cap), `settings/Slash.lua`, `tests/test_diagnostics.lua` | **Adopt**, in `DR-AM-02` (owner ruling Q3, `OWNER_RULINGS.md` DR-OW-01) | **Replaces** code AuraMaster owns and ships: its batch-8 report plumbing moves onto the helper. The sections stay the host's. |
| **The kit's shared contract suite**, `Kit.diagnostics` | `CHANGELOG.md` v1.60.0, *Test kit revision 27* | `tests/run.lua` | **Adopt** with the report in `DR-AM-02`. The suite is registered in this re-vendor, where it is one declared skip | Additive (tests only) |

## C. Whole-module adoption

None. No major is added in this range, and every major AuraMaster did not consume before
(`LibKa0s-Item-1.0`, `docs/module-map.md`) is unchanged.

The WidgetsDragHandle close mark (v1.59.0) is not in this range: AuraMaster adopted it in batch 8
(`docs/revendor/2026-09-25-v1.59.0/`).
