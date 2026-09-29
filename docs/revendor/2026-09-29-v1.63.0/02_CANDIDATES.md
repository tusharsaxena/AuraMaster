# 02 - Candidates: LibKa0s v1.62.0 -> v1.63.0

Sources:

```sh
git -C ../LibKa0s log --oneline v1.62.0..v1.63.0
git -C ../LibKa0s show v1.63.0:CHANGELOG.md          # the v1.63.0 block
git -C ../LibKa0s show v1.63.0:docs/api/Slash/version-17-docs.md
```

## A. Delivered on the re-vendor alone

None. Minor 17 adds surface and moves no existing behavior.

## B. Host change required

| Candidate | Evidence | What the host does |
|---|---|---|
| The `profile` verb (`CliProfile`, `ProfileSwitch`, descriptor field `profiles`) | `version-17-docs.md`, *The profile verb* | A `profile` row in `NS.COMMANDS` calling `cli:CliProfile(rest)`, `profiles = function() return NS.db end` on the descriptor, and `"profile"` in `liveVerbs()` |
| `lib.ProfileNames(store)` | `version-17-docs.md`, *The profile verb* | Nothing: AuraMaster has no profile sub-tree of its own to list from |

## C. Whole-module adoption

None. No major is added in this range.
