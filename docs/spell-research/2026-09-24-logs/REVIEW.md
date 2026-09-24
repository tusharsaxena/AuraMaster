# Review sheet — 2026-09-24

`REVIEW.csv` holds every proposal of this bundle as rows, one per spell id per change: corrections first (most-applied first), then additions grouped by recommended category. It is UTF-8 with a byte-order mark, so Excel opens it cleanly.

678 rows: 50 correction-add, 3 deletion, 11 move, 614 addition.

## How to review

1. Open `REVIEW.csv` in a spreadsheet.
2. In the last column, `decision`, write `Approve` or `Reject` on each row you rule (case does not matter; `A`/`R` and `Y`/`N` are accepted too). A blank row stays pending and is asked again next time; a rejected row is never asked again.
3. To put an approved row in a different category, overwrite its `proposed_category` with a category key or label from the list below.
4. A replace is two or more rows sharing one `proposal_key`: the `deletion` of the listed id and a `correction-add` per new id. Rule them independently: approving the add and rejecting the deletion keeps both ids.
5. Save the sheet as CSV and hand it back: `/aura-spells-review apply <path>`, which runs `logs.py ingest` on it, then the addon gates.

Do not edit `row_id`, `spell_id`, `type` or `proposal_key`: the sheet is checked against this bundle's copy by them, and a mismatched row fails the whole ingest.

## Columns

| Column | Meaning |
|---|---|
| `row_id` | Stable id of the row in this sheet (`R0001`, ...). Do not edit. |
| `spell_id` | The aura id the row is about. Do not edit. |
| `spell_name` | Its DB2 name. |
| `type` | `correction-add` (add this id to an existing entry), `deletion` (remove this listed id: the delete half of a replace), `move` (move this listed id to another category) or `addition` (a new aura into a category). Do not edit. |
| `class` | The class token, or `ALL` for a class-neutral entry. |
| `current_category` | The category it is in today (blank for an addition). |
| `proposed_category` | Where it would go (blank for a deletion). **Editable**: overwrite it with another category key or label before approving. |
| `specs` | Per spec: applications/distinct players, most-applied first. |
| `applications` | Total applications of this id. |
| `players` | Distinct players who applied it. |
| `context` | Why, in one plain sentence, with the rule that chose it. |
| `confidence` | high, medium or low. |
| `proposal_key` | The proposal the row belongs to; several rows may share one (a replace is a deletion plus one add per new id). Do not edit. |
| `decision` | **Yours, the last column.** `Approve` or `Reject`; blank leaves the row pending. |

## Decision values

| Write | Means |
|---|---|
| `Approve`, `A`, `Y` | apply the row |
| `Reject`, `R`, `N` | never apply it, and never ask again |
| (blank) | pending |

## Categories

| Key | Label |
|---|---|
| `defensives` | Defensive cooldowns |
| `activeMitigation` | Active mitigation |
| `raidCDs` | Raid cooldowns |
| `offensiveCDs` | Offensive cooldowns |
| `healing` | Healing |
| `support` | Support |
| `movement` | Movement |
| `utility` | Utility |
| `consumables` | Consumables |
| `hardCC` | Hard CC (loss of control) |
| `softCC` | Soft CC (roots & snares) |
