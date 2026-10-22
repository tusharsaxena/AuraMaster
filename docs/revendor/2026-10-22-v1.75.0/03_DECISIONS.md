# 03 — Decisions

No interview was held. The 2026-10-22 run's rulings make this re-vendor mechanical: M2 is
non-interactive, adoption happens only where the run's plan names it, and no GitHub issue is filed in
M2. OWNER_SCOPE A names no AuraMaster adopter for any surface of LibKa0s #45-#58, so every candidate
is recorded as "not adopted in this run", with no issue filed.

| Candidate (02_CANDIDATES) | Decision | Why |
|---|---|---|
| `W.SearchBox` (Widgets 13) | not adopted in this run | no search box in AuraMaster; adopters are LootHistory, BankLedger, DropWatcher |
| `W.TestStrip` (Widgets 13) | not adopted in this run | no standalone data window; excluded on purpose (OWNER_SCOPE A, #48) |
| `W.StepPanel` | not adopted in this run | not public (LK-11 outcome B) |
| `O.Drawer` (OptionsDrawer 1) | not adopted in this run | no owner request; stub parity only (01_DELTA 3g a) |
| `Item.BonusIDsFromLink` (Item 3) | not adopted in this run | no items |
| `Kit.assertLatchHoldOrder` (kit 39) | not adopted in this run | plausible test-only migration; no run item asks for it |
| `LibKa0s-Glow-1.0` | not adopted in this run | no LibCustomGlow use; the #56 candidacy was false |
| `LibKa0s-Sim-1.0` | not adopted in this run | no simulator; not a named adopter (OWNER_SCOPE A, C) |

Nothing was declined as "never" and no issue was filed. `O.Drawer` and `Kit.assertLatchHoldOrder` are
the two with a real fit; a later run may take them up.
