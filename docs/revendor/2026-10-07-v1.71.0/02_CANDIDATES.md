# 02 — Candidates

Sources: the LibKa0s `CHANGELOG.md` v1.71.0 block (lines 13-158 at the tag) and, at the tag,
`docs/api/Widgets/version-12.1.4.3.2-docs.md`, `docs/api/Slash/version-20.2-docs.md`,
`docs/api/Env/version-2-docs.md`, `docs/api/Options/version-28.2.34.2.4.8.1.7.4.2-docs.md` and
`docs/api/testkit/version-38-docs.md`.

## A. Delivered on the copy

- **`/am set <path> nan|inf|-inf` is refused** with "expected a number" (SlashParse 2;
  `Slash/version-20.2-docs.md:47-60`). AuraMaster's number rows can no longer store a non-finite value
  through the CLI.
- **`docs/test-cases.md` Totals count only the cases that run** (kit 38;
  `testkit/version-38-docs.md`, the Totals section). The inventory now agrees with the README badge.
- **Env 2 and OptionsIdList 4** drop dead bare-global rungs. No visible change on any live client.

## B. New surfaces (host change required)

| Surface | Evidence | Fit for AuraMaster |
|---|---|---|
| `Kit.secret`, `Kit.isSecret`, `Kit.reveal`, `Kit.SECRET_ERROR`, `Kit.installSecretValue` (kit 38) | `docs/api/testkit/version-38-docs.md:69-88` | Plausible. The anchor and container suites model secrets with a local sentinel, for example `tests/test_anchors_drag.lua:147` (`mocks.issecretvalue = function(v) return v == SECRET end`). `Kit.secret` would make arithmetic, comparison and indexing on a secret raise as in the client, which the sentinel does not. A test-only migration across about ten suites. |
| `ChartMath.ClipSegment` (WidgetsLineChart 3) | `docs/api/Widgets/version-12.1.4.3.2-docs.md:38-40`, `:1112` | None: AuraMaster draws no chart. |
| `lib.LineChart` render re-syncs the hover; `ClearHover` optional (WidgetsLineChart 3) | `docs/api/Widgets/version-12.1.4.3.2-docs.md:41-47` | None: no chart. |
| `lib.Autocomplete` re-call re-installs hooks; `opts.maxRows` floored (WidgetsAutocomplete 2) | `docs/api/Widgets/version-12.1.4.3.2-docs.md:49-62` | None today: AuraMaster has no search box. |

## C. Whole-module adoption

None. No major is added in this range; `LibKa0s-Item-1.0` stays unbound, as before, and is unchanged.

Four class-B candidates; one (`Kit.secret`) is a plausible fit.
