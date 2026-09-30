# 03 - Decisions

No interview was held. The 2026-09-29 run's spec (`02_SPEC.md`, section S3) and the owner's decision
D1 (`00_OVERVIEW.md`) already settle this release: every addon adopts the Slash minor 17 profile
verb, and adopts no other surface in the same item. No decline issue is filed.

| Candidate | Decision | Where it lands | Source |
|---|---|---|---|
| The `profile` verb (`CliProfile`, `profiles`, live while disabled) | adopted | `SP-AM-02`'s second commit, `/am profile via CliProfile` | S3 steps 2-7, owner decision D1 |
| `ProfileSwitch` | carried on the degradation stub only | The re-vendor commit (the parity case requires it); no host sub-tree calls it | S3 step 5 |
| `lib.ProfileNames` | not adopted | Nothing to call it from | `02_CANDIDATES.md` B |
