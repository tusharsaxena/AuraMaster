# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.31.0..v1.32.0` (`f7d78cd`, `4353908`, `4083889`,
`c6314d6`, `e18dd12`), the v1.32.0 block of `CHANGELOG.md`,
`../LibKa0s/docs/api/Options/version-16.15.4.3-docs.md` and `../LibKa0s/docs/api/Slash/version-8-docs.md`,
and the standard's `debug-logging-§10` at WowAddonStandards `7883278` (v2.44.0).

## Class A: reached the addon on the re-vendor alone

- **Both minors, unbracketed.** A host that supplies neither `bulkBegin` nor `bulkEnd` runs exactly
  the v1.31.0 walk: the same calls in the same order, with no `pcall`. The suite total is unchanged
  at 252 on the copy alone.
- **No surface change.** No member is added to either instance, so `tests/test_surface_parity.lua`
  needs no new exclusion.

## Class B: host change required

| # | What | Evidence | Files touched | Recommendation | Blast radius |
|---|---|---|---|---|---|
| B1 | Adopt the bulk bracket: mute the seam's per-row `[Set]` line and emit one `[Set] reset <scope>: N rows` line, or nothing when `info.profileReset` | Options doc "What the host logs — the contract"; `debug-logging-§10` | `settings/Schema.lua` (the seam, `announceWrite` and `logSection`), `settings/OptionsSetup.lua` (descriptor and degradation stub), `settings/Slash.lua` (descriptor) | **Adopt.** Required by `debug-logging-§10` (v2.44.0): every Defaults press is N `[Set]` lines today | Logging only; writes, `onChange` and `CONFIG_CHANGED` unchanged |
| B2 | Log a profile reset and a profile copy once, from the profile handler, worded by the event | `debug-logging-§10` "A profile-wide reset, copy or switch is not a batch through the helper" | `core/Database.lua`, `core/AuraMaster.lua` | **Adopt.** The three AceDB callbacks share one handler and one `[Profile] changed` line today | Logging only |
| B3 | Bracket the host's own bulk acts, `ContainerManager.CopyFrom` and `ContainerManager.ResetPositions` | Options doc "What the bracket does not do": a host's own copy or reset is the host's to bracket | `modules/ContainerManager.lua` | **Adopt.** Each logs one `[Set]` per section write today, plus a `[Containers]` summary | Logging only |

## Class C: whole-module adoption

None. `LibKa0s-Item-1.0` and `LibKa0s-Widgets-1.0` stay unbound by name; neither file moved.
