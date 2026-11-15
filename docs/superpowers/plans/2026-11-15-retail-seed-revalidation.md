# Retail seed re-validation against wago.tools (issue #27): plan of record

**Goal:** Re-validate every Retail `spells` seed list and `defaults/CastToAura.lua` against the
current Retail build on wago.tools, and turn the re-validation into a repeatable activity whose
re-run surfaces only what is new since the last ruled build.

**Branch:** `feat/2026-11-15-retail-seed-revalidation` (AuraMaster), `feat/2026-11-15-wago-tools-seed-validation`
(WowAddonStandards). No merge, push, tag or version bump without the owner's go-ahead.

**Owner rulings (2026-11-15):**
1. The seed-file split is approved: the Retail lists leave `defaults/Categories.lua` for
   `defaults/Categories_Retail.lua`, picked once per client (clients-§5), and the `layout-§1`
   FX-AM-SIZE deviation row is retired.
2. Claude rules every candidate (the Forever precedent); the owner reviews `RULINGS.md`.

**Baseline measured 2026-11-15** (build 12.1.5.70783 against the last derivation's 12.1.0.69875): CC
buckets identical (215/40/172, gate PASS 71); shipped-id check 435 ids, 0 unnamed, 0 renamed, 1 no
aura (35546, #15); player pool 7020 -> 7028 (+10/-2/8 renamed, no shipped id affected); CastToAura
two rows (Frost Strike +1305700, Chomp +1310257); Forever's DB2 rules on Retail propose 249
unshipped ids; `--diff` repeats 308 CC additions ruled only in 2026-09-20 prose.

**Gate before every commit:** `lua tests/run.lua`, `KA0S_KIT_CLIENT=forever lua tests/run.lua`,
`~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` (0/0), and `python3 -m pytest -q tools/spell-research`
when `tools/` changes.

**How to resume:** read the ledger below; an item is done when a commit whose subject opens with
`<ID>: ` exists on the branch (`git log --oneline master..HEAD`). Current position is the first row
not marked done.

## Status ledger

| ID | Item | Status |
| --- | --- | --- |
| RS-00 | This plan | done |
| RS-01 | GitHub issues: ConsumableMaster #49, KickCD #39, LibKa0s #91 | done (filed 2026-11-15) |
| RS-02 | Split: Retail lists into `defaults/Categories_Retail.lua` (`seed("key", "AURA", { ... })` blocks, bodies moved with an 8-space dedent), TOC, load-order and client tests | done (d3f48d0) |
| RS-03 | Tooling reads and writes the `seed(...)` shape; defaults point at the seed file; pytest | done (folded into d3f48d0) |
| RS-04 | Docs: retire the FX-AM-SIZE row, ARCHITECTURE/module map/README of the tool, smoke FILT-65..67 | done |
| RS-05 | `sid_seeds.py` (shared candidate + ruling machinery out of `forever.py`) and `retail.py` (status / derive / rule / check / apply / report), the shipped check as a `dropped`-since-previous-build delta; pytest | done (c1bb7d2) |
| RS-06 | The 2026-11-15 run: bundle `docs/spell-research/2026-11-15-retail/`, every candidate ruled in `retail_rulings.json` | done (28560ac): 10 accept, 549 reject, 1 keep |
| RS-07 | Apply accepted ids; regenerate `defaults/CastToAura.lua`; ANALYSIS.md | done (df3e6f8) |
| RS-08 | Repeatable: `.claude/commands/aura-seeds-validate.md`, `docs/common-tasks.md` recipe | done (with RS-04) |
| RS-09 | Upstream: WowAddonStandards clients-§10 (wago.tools reference), v2.111.0 | done (WowAddonStandards 83502de, unpushed) |

**Current position (2026-11-15):** every item landed on the branches; nothing pushed or merged. Owed: the owner's review of `RULINGS.md`, smoke FILT-65 to FILT-67 (full client restart), and the go-ahead to merge and push both repos.
