Delta: LibKa0s v1.80.0 -> v1.83.0 (span: v1.80.0 v1.81.0 v1.82.0 v1.83.0)

# 01 - Delta: the unrecorded span, LibKa0s v1.80.0 to v1.83.0

A consolidated span bundle, written 2026-10-31 as item `FX-AM-DOCS` of the findings remediation
(Ka0sAddonsCommonTasks `docs/2026-10-31-FINDINGS_REMEDIATION/`). Between the store's
`2026-10-24-v1.77.0` bundle and this run, four tags reached this addon inside the skinning and skin
font runs, and none wrote a bundle here. Each run's own record is in Ka0sAddonsCommonTasks. This folder
holds `01_DELTA.md` and `05_SUMMARY.md` only: nothing about them is decided in retrospect.

**Base: v1.77.0**, the last recorded tag (`docs/revendor/2026-10-24-v1.77.0/`). Line 1 above names the
span's first and last unrecorded tags, not a base and a new tag. v1.78.0 and v1.79.0 were never
vendored here: the provenance line goes from v1.77.0 straight to v1.80.0.

## The carrier commits

```sh
git log --format='%h %ad %s' --date=short --since=2026-10-29 -- libs/LibKa0s tests/_kit
# 472da8f 2026-10-31 AM-RV3: Take the re-cut LibKa0s v1.83.0 (LK-A3, the skin picker's rows)
# 47119a8 2026-10-31 AM-RV3: Take the re-cut LibKa0s v1.83.0 (LK-A3, the skin picker's rows)
# f7f24d8 2026-10-31 AM-RV2: Take the re-cut LibKa0s v1.83.0 (LK-A1, LK-A2)
# dc4e03c 2026-10-31 AM-F01: Re-vendor LibKa0s v1.83.0 and move to its outline default and faces
# 716cd84 2026-10-30 AM-01: Re-vendor LibKa0s v1.82.0 with the Font outline, /am skin, From skin flags and the H...
# 07ff34c 2026-10-30 AM-RV: Re-vendor LibKa0s v1.81.0
# 893d5eb 2026-10-29 AM-RV: Re-vendor LibKa0s v1.80.0 and meet what a consumer owes
```

| Tag | Carrier | `libs/LibKa0s/` and `tests/_kit/` diff |
|---|---|---|
| v1.80.0 | `893d5eb` | 76 files; adds the `LibKa0s-Skin-1.0` major |
| v1.81.0 | `07ff34c` | 24 files; the kit is byte-identical to v1.80.0's |
| v1.82.0 | `716cd84` | 31 files |
| v1.83.0 | `dc4e03c`, then the re-cuts `f7f24d8`, `47119a8`, `472da8f` | 32 files, then 2, 5 and 1 |

The tag v1.83.0 moved three times after `dc4e03c`, and each move has its own commit above. The diff
sizes are `git show --stat` of each commit over those two paths.
