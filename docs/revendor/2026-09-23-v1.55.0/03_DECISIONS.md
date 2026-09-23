# 03 - Decisions: LibKa0s v1.54.2 -> v1.55.0

Step 6 of `/wow-addon:revendor-libka0s`. There was no interview: the owner delegated the call (CP-6)
to the sweep's Phase 6 under five rules, quoted here because they are the authority for every row:

1. Adopt each delta the spec prescribes for this repo: one major per commit, the characterization
   test green before the code moves, the spec's degraded (library-absent) case added, and the
   surface-parity map updated where the spec says. Keep the host's seam names.
2. Decline as "not now" (`state:triaged`) where the spec itself says the repo MAY defer, or where
   the adoption cannot land green without changing pinned or player-visible behavior (after one
   honest attempt, rolled back). Decline as "never" (`state:will-not-do`) only for a structural
   misfit the spec or the repo's own docs record.
3. File each decline with `gh issue create` in this repo: one `state:` and one `severity:` label.
4. Order: fixes a live defect, then closes a recorded gap, then new capability; smallest blast
   radius first.
5. The assertion standard is "renders/behaves the same": pin outputs, callback order and return
   arity where the adoption moves code.

None of the candidates fixes a live defect: every host copy the majors replace is correct today
(`02_CANDIDATES.md`). All three close the gap `docs/ARCHITECTURE.md:69` records ("not adopted yet"),
so the order is by blast radius: C1 (additive), C2 (live path of four members), C3 (the write
seam's helpers).

Each row was written when its decision landed, in the order below.

## D1. C1 `LibKa0s-Bus-1.0` `Catalog`: adopt

- **Rule:** 1. `bus.md:606` prescribes it for this repo ("Catalog only") and does not permit a
  deferral.
- **Reason:** additive; all four keys and wire names already pass every `Catalog` check
  (`bus.md:299`); the one behavior change (an undeclared key raises instead of reading nil) is the
  point of the major (OPEN-2, `bus.md:653-658`) and no call site reads an undeclared key
  (`grep -rnoE "MSG(\.[A-Za-z_]+|\[[^]]*\])" core modules settings tests/*.lua` finds only the four
  declared keys, and no `MSG[...]` index or `MSG.X =` write outside `core/Bus.lua:30`).
- **Outcome:** landed in `059f0a1`, gate green (1289 passed, 0 failed, 0 skipped; lint 0/0 in 110
  files). The stub carries `Catalog` alone and the parity case ignores `New` with the reason (D2).

## D2. The Bus stand-down record (`New`/`NewTarget`/`StandDown`/`StandUp`): never

- **Rule:** 2, "never" for a structural misfit the spec records.
- **Reason:** `bus.md:606-610` records it for this repo: the factory `core/Bus.lua:21-25` stays
  untracked because the receivers already stand down by hand per module
  (`modules/ContainerManager.lua:557-563`, `modules/TimedSpells.lua:165-168`) and the settings
  receiver (`settings/OptionsSetup.lua:395`) is setup that survives; "a second mechanism beside a
  working first one; not recommended." `architecture-§4` (standard v2.64.0) keeps a host's own
  untracked factory permitted.
- **Filed:** https://github.com/tusharsaxena/AuraMaster/issues/20, labels `state:will-not-do`,
  `severity:low` (plus `enhancement`). Closing it as "not planned", the collection's convention for
  a terminal will-not-do, was refused by the session's permission check; it stays open until the
  owner closes it.

## D3. C2 `LibKa0s-Compat-1.0` (`GetSpellInfo` and the secret trio): adopt

- **Rule:** 1. `compat.md:449-463` prescribes it for this repo and permits no deferral.
- **Reason:** the trio's answers are identical to the host copies on every input (Compat
  `version-1-docs.md`, "IsSafeKey asks IsSecret, not CanAccess"); `GetSpellInfo`'s first two returns
  are unchanged and its three callers read `name` only (`modules/CastAura.lua:72`,
  `settings/GeneralSpells.lua:256`, `:1247`). The two behavior deltas are the spec's own: the hit
  arity 2 -> 6, and a degraded install answering nil (the reader arm's documented absent value)
  instead of a `C_Spell` read. Neither is player-visible on a whole install.
- **Outcome:** landed in `c802172`, gate green (1296 passed, 0 failed, 0 skipped; lint 0/0 in 110
  files). One delta beyond the spec's list, found while pinning arity: on the legacy branch (no
  `C_Spell`, reachable only headless or on a pre-11.0 client), a miss used to answer two nils
  (`local name, _, icon = GetSpellInfo(id); return name, icon`) and now answers one, the major's
  contract. Pinned by "compat: with LibKa0s a spell info hit is the major's six values, and a
  legacy miss one nil". The adoption moved five `core/Compat.lua` citations by six lines
  (`DEPENDENCIES.md:20`, `:21`, `:35`, `docs/midnight-quirks.md:22`, `docs/settings-panel.md:608-609`),
  re-cited in the same commit.

## D4. C3 `LibKa0s-Schema-1.0` partial adoption: not now

- **Rule:** 2, "not now" where the spec itself says the repo MAY defer. `schema.md:529-531`: "AM MAY
  defer this adoption until it adopts `Set` (the re-check trigger below); the revendor interview
  decides."
- **Reason:** the spec's own cost line: minor 1 removes none of this addon's walker or bracket code,
  because `tests/degraded_env.lua` loads no LibKa0s and `SetByPath` must keep working there, so
  every host primitive stays as the library-absent arm and the live path gains a second copy. Two
  pinned seams would move for no removed code: `changes()` (`settings/Schema.lua:427-431`) from
  `FilterCompiler.Signature` to `lib.SameValue`, and the `Bulk.Run` callers
  (`modules/ContainerManager.lua:471`, `:502`, the degraded Reset all) from `return true` to
  `info.profileReset = true` (JC-9). Standard v2.64.0's adoption carve-out (`library-stack-§7`,
  anti-pattern #47) keeps the host copy compliant until a later standard requires adoption. No
  attempt was made: the rule's first clause (the spec permits the deferral) decides it on its own.
- **Filed:** https://github.com/tusharsaxena/AuraMaster/issues/21, labels `state:triaged`,
  `severity:medium` (a deferred duplication; plus `enhancement`). Re-check triggers in the issue:
  this addon adopts the library's `Set`; `row.normalize` gains a second consumer (`schema.md:538`);
  the standard makes adoption a requirement.

Every candidate in `02_CANDIDATES.md` has a decision. None is unreached.
