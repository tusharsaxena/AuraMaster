# 03 — Decisions

This run was non-interactive. The orchestrating session gave the owner's standing answers (owner
decisions of 2026-09-12): **adopt** means delete a local shim where the kit now provides the same
contract and the suite stays green, after checking the tests that exercise it against the kit's
version first. **Decline** means anything that needs a harness migration. Declines are recorded here
and handed back as proposed issues. This run files none, and pushes nothing.

| Candidate | Decision | Why |
|---|---|---|
| B1 `AceGUI:Release` shim | **adopt** | The kit provides the contract. `test_optionssetup.lua` stays green on the kit's stricter `Release` |
| B2 `Printf` shim | **adopt** | The kit provides it. `test_setups.lua` "NS.Printf is reclaimed from AceConsole…" stays green and still has something to go red against |
| B3 AceEvent Embed events shim | **adopt** | The kit provides it. `test_timedspells.lua`, `test_perf.lua` and `tests/perf.lua` read the same `__events` field and pass |
| B4 local 100755 case | **adopt** | The kit registers it. Keeping the local copy would run the same check twice |

Declined: none. Not now: none. Unreached: none.
