# 03 — Decisions

This run was non-interactive. The orchestrating session relayed the owner's rulings of 2026-09-12
(standard v2.44.0, `debug-logging-§10` final text at WowAddonStandards `7883278`) and the rollout
spec's AuraMaster section: adopt the bracket, convert every bulk act to one `[Set]` line, log a
reset-all once through the profile handler, and skip filing and pushing.

| Candidate | Decision | Why |
|---|---|---|
| B1 the bulk bracket on both descriptors | **adopt** | `debug-logging-§10` makes a bulk reset through the helper one `[Set] <act> <scope>: N rows` line |
| B2 profile reset / copy wording in the profile handler | **adopt** | `debug-logging-§10`: a profile-wide reset or copy is logged once by the profile-event handler, worded by the event |
| B3 `CopyFrom` and `ResetPositions` bracketed by the host | **adopt** | Both are bulk copies or resets through the helper (the rollout spec's interpretation for `ResetPositions`) |

**N is counted by the seam, not taken from the library's `count`.** The library counts a row when its
`applyDefault` returned. `debug-logging-§10` counts a row only when the act actually wrote it, and a
row already at its default is not counted. `NS.ApplyDefault` writes unconditionally, so only the seam
can tell a changed row from an unchanged one. The seam's tally is therefore the N the host logs.

Not now: none. Declined: none. Unreached: none.
