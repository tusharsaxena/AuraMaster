# Known limitations — Ka0s Aura Master

What this addon cannot do, or does differently from what a player might expect, and why. Most of it
follows from the 12.1 aura restrictions and the aura container engine (`docs/midnight-quirks.md`);
the rest are trade-offs the owner accepted, each marked where it was ruled on. Summarized in
`docs/ARCHITECTURE.md` → Known Limitations.

- **Units are player, target, focus and pet.** Party units 1–5 are deferred and tracked as a GitHub
  issue.
- **A profile copy or reset discards the player's own spell categories, without asking.** Profiles
  → Copy From and Reset Profile replace the profile wholesale, and `userCategories`,
  `userCategoryOrder` and `categorySpells` go with it. That is how those two acts have always
  worked and issue #10 did not change them — but it did change what is lost, from a set of
  Show/Hide states to categories the player named and filled themselves. Reviewed and **accepted by
  the owner on 2026-09-21**: the acts say what they do, and adding a confirmation to one of them and
  not the other would be worse than neither. Revisit if a player reports losing work this way.
- **The create form sits between the category picker and its spell list.** A player who only came to
  edit spells passes "Make a new category" on every visit. Accepted by the owner on 2026-09-21: the
  alternative is below the list, where sixty entries would hide it.
- **A claimed spell's `(also in N)` can be truncated away on the narrowest panel.** The claim now
  rides the entry's own row — `(X) [icon] Renewing Mist (119611) (also in 1)`, LibKa0s v1.49.0's
  entry `suffix` — with the claiming categories named in the entry's tooltip. At two columns word
  wrap is off and the client cuts the tail, and the library's truncation order is the suffix first,
  then the id, then the name's tail. The budget is real: `0.43 × 520 − 16 = 207.6px` of label at the
  icon style's 520px floor, which at LibKa0s's published rule of thumb of ~4.5px a character (its
  figure; nothing here measures a font) is about 46 characters, while a long row such as
  `Ancestral Protection Totem (207399) (also in 1)` is 47. So at the floor that row shows
  no `(also in 1)`. **Accepted**: this is the library's documented degradation and the tooltip still
  names every claiming category. A wider panel buys it back at about 8 characters per 100px.
- **Categories are created only on General → Spell Categories.** Filters → Categories, where a player
  is most likely to be thinking about categories, shows them and links to their spells but offers no
  way to make one. Accepted by the owner on 2026-09-21.
- **A Text line of several pieces cannot be centered as one line.** A line is a chain of font strings
  the engine writes secret, so the chain's width is never readable, and no addon code runs when the
  engine rewrites a piece in combat. A multi-piece template set to Center is therefore STACKED: one
  centered row per field, its plain literal pieces not drawn, the rows fixed in place (an empty field
  keeps its row) and the box grown to fit them (`Style.Text.Stacked`, `Style.Text.StackHeight`;
  feedback #1). The Text page says so under Placement.
- **A Text line cannot be colored by its aura's dispel type.** No engine binding colors a font string by
  dispel type (`SetDispelTypeText`, `SetSpellName`, `SetApplicationCount` take no color;
  `SetDurationText`'s color curve runs over time), the dispel-keyed color map exists only on
  `AddDispelTypeTexture`, which takes a Texture, and addon code can neither read the type nor touch a
  button in combat. The Text page offers three opt-in stand-ins instead (Font → Dispel type,
  feedback #7): the `$dispeltype$` word colored by a `|c` escape in the engine's own text map, and a
  backdrop and an edge the engine tints (`modules/Style_Text.lua`).
- **A border style other than Solid redraws a live button only when the button is rebuilt.** Its
  backdrop does arithmetic on the button's size, which reads secret once the engine has laid the button
  out, so a new texture or thickness is applied on a new button, a rebuild or a `/reload`; its color
  changes at once, and Solid redraws at once (`Style.ApplyBorder`, B2-3). The Border style tooltip says
  so.
- **A Text token can be used once, the duration tokens must sit together, and there is no caster
  token.** The engine has one binding per field (one spell name, one stack count, one dispel type, one
  duration text whose format holds every duration value); it has none for the caster
  (`modules/TextTemplate.lua`).
- **A Text animation cannot start, stop or change in combat.** Every call on an engine button's
  objects is refused in combat; loops are built and played at dress time and keep running, and a
  change made in combat applies with the deferred restyle (`docs/midnight-quirks.md`).
- **Spell-id filters are honored only for buffs on friendly units and debuffs on hostile units** (the
  engine's identity gate). `FilterCompiler` emits a warning per container where that bites
  (`identityWarning`, `modules/FilterCompiler.lua:417`, choosing its sentence from `FC.IdsHonored`),
  rendered in orange on the Filters page.
- **On a target or focus BUFF container, Uncategorized set to Show no longer rescues an unlisted
  aura.** That row's group carries an `excludeSpellIDs` of the categorized union as its only
  constraint whenever another category is Hidden, and a target's hostility is dynamic while the plan
  is compiled once — on a hostile target the engine discards the ids and the group degenerates into
  "every buff", superseding the catch-all and defeating every Hide on the tab. The compiler
  therefore emits the group only where the ids are CERTAIN (`FC.IdsAlwaysHonored`: buffs on the
  player and pet), and the same gate runs in `FC.ExplainSpell` so the Filters page never claims a
  rescue the plan does not contain. Accepted deliberately by the owner (issue #11, 2026-09-20):
  losing a niche rescue on one unit beats defeating every Hide by default. The debuff side answers
  false on every unit for the same reason, which is what keeps issue #11's `hardCC`/`softCC` from
  re-opening fix round 3's failure.
- **Five crowd-control spells are missing from the shipped `hardCC`/`softCC` lists.** Both lists are
  derived by `tools/spell-research/research.py` from the client's own DB2 tables, and five abilities
  sit where that pipeline cannot reach: Repentance (20066), in none of the four pool sources for the
  build; Axe Toss (89766) and Seduction (6358), on a pet skill line with ClassMask 0, which the same
  test that excludes professions and mounts throws away; and Earthbind Totem (2484) and Earthgrab
  Totem (64695), whose root auras carry no mechanic and no matching name, so Shaman ships no root at
  all. The KNOWN GAPS comment above `hardCC` (`defaults/Categories.lua:817`) records each one and why
  rather than papering over it. A player who
  wants any of the five adds it by id on General → Spell Categories, which is a profile-wide edit
  every container picks up.
- **"Only auras without a duration" is learned, not filtered.** The engine has no such filter; the
  addon excludes every spell it has seen carry a duration, learned from player and pet buffs while
  auras are readable (`modules/TimedSpells.lua`). A timed buff never seen out of combat shows once;
  the set only grows until `/am forgettimed`. Because only buffs are scanned, the mode narrows
  nothing on a debuff container.
- **Settings changes wait for secrecy and lockdown to lift.** The player is told once per deferral,
  and the line names the cause: "…will apply when combat ends." under lockdown, or "…will apply once
  aura information is available again (after the encounter, key or match)." when secrecy alone holds
  the change. A stretch announced as combat that secrecy still holds afterwards says so once more, on
  the next held change and never on the `PLAYER_REGEN_ENABLED` edge itself, whose order against
  `ADDON_RESTRICTION_STATE_CHANGED` is unverified. Writes that apply no container never wait: the
  master enable, visibility, lock and alpha run the visibility pass at once, and a rename and the
  session toggles queue nothing. The Blizzard-frame toggles queue nothing either, but reparenting
  waits for lockdown to lift: a toggle in combat prints the combat line, under the same
  once-per-stretch rule, and applies on `PLAYER_REGEN_ENABLED`. The notice is only for the
  player's changes. What the addon queues for itself waits just the same but prints nothing: a
  class-swap re-apply, a learned timed spell, the startup build after a reload in combat, a perf
  resume (`RequestApply(id, true)`).
- **A container deleted or switched away in combat, or while aura information is withheld (an
  encounter, key or match), draws nothing until that ends, and is torn down then.** Its frames stay
  parked in the meantime. Creating and deleting from our own surfaces are refused in combat instead;
  Reset all, like Reset Profile, takes this parked path.
- **After a profile switch, copy or reset in combat, a container whose id the new profile shares
  draws nothing until combat ends** (or, while aura information is withheld, until that ends). Its
  engine was built for the old container, so it stays parked rather than show stale auras under the
  new container's name, and the deferred apply rebuilds it. The same goes for a container a Create
  or Duplicate adds under an id the profile change just retired: while aura information is withheld
  out of combat it draws nothing until that ends.
- **The schema v3 migration can widen what an already-narrowed container draws.** A container that
  used the old three-state model's exclusive Whitelist (only Defensive cooldowns shown, say) keeps drawing
  only Defensive cooldowns after migration — every other category of its aura type becomes Hide (`E-8`,
  `docs/schema.md` → Migration path). But an aura in **no category at all** now shows too (rank 5),
  where the old exclusive Whitelist excluded it, because the two-state model has no way to express
  "only the categories I named" on its own. The fix is `Uncategorized = Hide` (batch 7, `U-1`..`U-5`,
  restored to debuffs in fix round 3) — a player who notices new, uncategorized auras appear in a
  container that used to be narrow should look at Filters → Categories and set that row to Hide. On a
  debuff container this row means only that: its Show side does not contribute a group of its own, so
  it is Hide-only in practice, exactly reproducing the retired per-container **"only these
  categories"** toggle it replaced (batch 7 fix round 2). The reason is no longer "`Cat.HARMFUL` has
  no `spells`-kind category" — it carries `hardCC` and `softCC` as of issue #11 — but that
  `FC.IdsAlwaysHonored` is false for every debuff container: the engine discards debuff spell ids on
  the player and pet outright, and may discard them on a `target` or `focus` the moment the unit is
  friendly, so the group that Show would contribute could arrive carrying nothing at all.
- **A change of shape rebuilds the engine.** A different group count, enchant slots appearing or
  going, toggling hide-permanent enchants, a style switch, or a growth change that moves the corner
  the engine is pinned at (Grow horizontally or vertically, its own or inherited from the container
  it follows; the engine cannot be re-anchored after its first group) retires the old engine and
  creates a new one; WoW never frees a frame, so
  each such change leaves one hidden frame for the session.
- **Preview elements are addon-owned frames**, dressed by the same `Style` code but laid out by
  `Preview.Offset`'s arithmetic rather than by the engine. Like the live buttons, they hold the
  mouse's hover unless the container is click-through or shows no tooltips (`Style.TakesHover`), and
  they take no clicks. A world unit's tooltip appears only when no mouse-enabled frame is under the
  cursor, and the aura tooltip is the engine's own `AuraButtonTooltip`, not `GameTooltip`. So only
  the hover stops that bleed; strata cannot (L-3).
- **Class colors follow the container's unit, snapshotted per apply.** After a target, focus or pet
  swap under combat lockdown or while auras are secret, a class-colored container keeps the previous
  unit's class until it re-applies. Under lockdown alone (open world, auras readable) that happens
  on `PLAYER_REGEN_ENABLED` (`ReapplyStaleClass`). While auras are secret it happens when the
  restriction lifts, since engine buttons cannot be re-dressed until then. That residual is ratified
  by the `options-ui-§17` row in `docs/ARCHITECTURE.md` → Documented deviations.
- **A user category's key is unique within the account, not across accounts.** `Cat.NewUserKey` draws
  ten base-36 characters from a Lehmer sequence seeded per client from the player GUID, the clock and
  the profiler, and then refuses any key `Cat.UserKeysInUse` finds anywhere in the account — so within
  the account uniqueness is a guarantee and it is the scan's doing, not the generator's. Across
  accounts nothing can check a key an account has never seen, so it is a very small probability rather
  than an impossibility. Keys travel: a container copy, an AceDB profile copy, and import/export when
  it exists (issue #9). The import half of #9 must therefore RE-KEY a record whose key the importing
  account already holds rather than trust that keys cannot collide.
- **Deleting a user category sweeps the stored profiles one at a time, and is recoverable rather than
  atomic.** `Cat.DeleteUserCategory` clears `filter.categories.<key>` and the spell list from every
  container of every stored profile through `Database.EachProfile`, each profile inside its own
  `pcall`, and runs the sync unconditionally afterwards. A profile whose stored table is malformed
  therefore keeps its own leaves while every other profile is cleaned. That is a real outcome and not
  a failed delete — the record, the definition, the schema row and the template key are all gone, and
  what survives is inert — so the act returns the refusing-profile count third and the panel's
  confirmation says so, leading with what went. A profile holding a record of its OWN under the key (a
  profile copy) is skipped deliberately, which is what keeps a copy's category alive when the original
  is deleted. `Cat.ForgetUnusableUserRecords` does not yet carry that count out the same way: it sums
  the leaves cleared and discards each sweep's failure count, so a profile that refuses ITS sweep
  reaches `NS.Debug` and nothing else.
- **A frame anchor needs a global name.** The picker walks up to the nearest named ancestor
  (`FP.NamedAncestor`, `modules/FramePicker.lua:26`); an unnamed frame cannot be re-found after a `/reload`.
- **While unlocked, a container flush with the screen edge on its handle's side is pushed in.** The
  anchor's clamp rect takes the handle in, so the handle can never be dragged off the screen
  (`Anchors.UpdateHandle`). A container dragged against the top edge that grows down therefore sits
  20px lower (the 18px strip and its 2px gap) until `/am lock`, and a handle wider than one element
  (only on an element too narrow for its marks and a readable label, such as one icon, batch 11 T11)
  pushes a container off the side edge it runs toward the same way. Locking puts it back, and the
  stored position never changes. The strip's close mark (X, batch 8 CX-3) widens it by the X and a
  matching reserve on the other side, so the label stays centered, and a shown name label pushes the
  strip further out by the label's height plus the gap (D6); both count in the clamp, so the push
  grows with them.
- **In test mode, a container attached to another hangs from that container's preview extent.** A
  previewing container's engine is disabled and keeps a stale rect, so a container attached to it is
  re-placed onto a frame of ours sized to its placeholder block (`Preview.Extent`), where it sits as
  it would beside real auras; ending test mode puts it back on the engine. Its strip sits above its
  own block, in the room its seam makes (batch 10 F1, F2), so it covers none of the parent's
  placeholders, and it is still raised above them. That raise is a frame level: a parent set to a higher strata still draws over it. Test mode ending in combat re-places nothing
  (events-frames-taint-§2): the attached container stays where it was until the first visibility
  pass after combat.
- **Any pair of anchor points is allowed, and an odd one can overlap** (batch 11 G1, G5). A
  container attached to another joins it by two absolute points, and nothing is refused: a pair that
  puts the child over its parent, or has it grow back across it, is drawn as asked ("if it looks
  weird, it's on the user"). Only a pair that is one of batch 9's nine sides under the parent's growth
  gets the seam gap, the chain's spread for the strips and labels, and the side push
  (`Anchors.AttachEdge`); any other pair is placed at its X/Y alone, so its strip and label can overlap
  its parent's. Picked points are absolute: flipping the chain's growth mirrors an Automatic point and
  leaves a picked one where it is.
- **Schema v11 can move a follower that was on the old default side** (batch 11 G4). A stored
  `after-start`, which schemas v9 and v10 stamped on every attachment, becomes Automatic and takes
  G3's default: a Text follower justified Center, or to the end its lines grow toward, moves to its
  parent's center or that end, and an Icons or Bars follower under a Text parent justified Center
  moves to the center. Any other side was converted to the points it sat on and does not move. Pick
  the two points on Layout > Anchor to put one back (`docs/schema.md`, v11).
- **Nothing on screen marks where two containers join** (batch 11 G6). Batch 9's gold diamond at the
  join is gone at the owner's request. The join is named by the strip's tooltip while unlocked
  ("Joined to the *point* of '*parent*'") and by the Layout > Anchor joins line, and
  `/am diagnostics` prints the two points and the side they make (`join=`).
- **A chain spreads out while its strips show, and closes up when they hide** (batch 10 F1, F2).
  Every strip sits above its own block (below it growing up), in its own column, so a follower
  attached below its parent sits one strip row (20px) further along while unlocked, and one more
  while its name label is on, locked or not. The container moves on screen when you lock or unlock;
  its stored offsets do not change. A lock or unlock in combat re-places nothing until combat ends.
  Test mode spreads the chain only while unlocked, since a locked addon shows no strips. A follower
  on the parent's Right (growing right; Left growing left) is pushed along the chain past the
  parent's label row while that label is on, locked or not, and past its strip row while the
  parent's strip is wider than its element (F4). The label's text width is not read (the label can
  sit on secret geometry), so the label row counts even when the name fits the parent's element,
  and whatever the follower's own alignment, so a follower at the parent's bottom end moves too even
  where nothing would meet. A follower on the other side is never pushed, since the parent's strip runs away from it. A
  strip wider than its element still runs over whatever lies beside its column in the direction its
  lines run; only a narrow element's strip can be (batch 11 T11).
- **A long container name is shortened on its strip.** The strip is as wide as its container's
  element (batch 11 T11), so a name that does not fit between the marks ends in "..." there, the TEST
  tag kept whole after it; the strip's tooltip title and the name label show it whole. An element
  narrower than the marks, the pads and 40 px of label (one icon, for example) keeps the strip's
  natural width instead, so its name still reads, and that strip runs past the element.
- **The strip's X turns a container off at once, with no confirmation.** One left click writes
  `container.enabled = false` (batch 8 CX-3); the tooltip and a chat line point at its Enabled
  checkbox on the Containers page (`/am set container.enabled true`, with it selected, works too). There is
  no undo on the strip itself, and a container that others are attached to takes its followers with
  it, as unticking Enabled does. A drag that starts on the X moves nothing.
- **The name label is not clamped to the screen.** Only the drag strip is (batch 8 NL-2). Clamping the
  label would move the container whenever the label is turned on, so a locked container flush with
  the edge on the label's side can show its label partly off screen. On a container attached to
  another the label sits on its own block's before side, as a root's does (batch 10 F3), in the room
  its seam makes; its X/Y offsets move it, and a moved label can meet a neighbor, since the seam
  makes room only for the label's own row. A long name overruns a narrow element,
  since the label does not wrap: past both edges when centered (the Bars and Text default, batch 9
  E7), otherwise away from the edge it is justified to.
- **Size to fit sizes a Text container once, not per aura** (batch 8 AS-2). The engine draws every
  element of a group at one size and aura names are secret in combat, so the size comes from the
  placeholders, the sample names and the worst-case durations. A live name longer than those is not cut
  (batch 9 TX-1, E8): under Size to fit the element's frames do not clip, so the line draws in full
  from its justify point past the box, both ways when centered. That overflow can run over an icon on
  the side it grows toward and, in a horizontal row, over the next element; the layout, the outline
  and the drag strip still use the fitted box. For the same reason a Bounce at Justify vertical Top,
  which gets no headroom, rises above the box instead of being cut there. A hand-set Width (Size to
  fit off) cuts at the box as before. A font that has not loaded yet measures nothing, so the first apply after login can
  use the stored Width and Height and the next one sizes to fit. Defaults on the Text page turns Size
  to fit on (the template's value); Text containers stored before schema v8 keep it off (D7). Size to
  fit is Text-only (batch 9 E6): a bars or icons container stores no value of its own (schema v9
  removes the one an early v8 build stamped), so one switched to Text later starts with it on.
- **`/am diagnostics` cannot always name what a container shows** (batch 8 DG-2, DG-3). While auras are
  secret it reads no aura and calls nothing on an engine button, so `shown=?` and the per-group
  frame count are all it prints. Out of combat a button's shown state can itself be secret (batch 9
  DX-1), so a group can read `shown=?` or `shown=2+1?` and a button be listed as `shown=?`; and a
  button's aura id may still be out of reach, so a shown line can carry only the name or the icon, and the `predicted:` verdict is the addon's own
  reading of its spell lists, not the engine's answer. The report appends to the console, whose
  1500-line buffer can push older trace lines out. While the addon is disabled or stood down it
  builds no container, so after a login made while off the `[Plan]` lines are predictions only,
  and once built they are from the last apply; the header says which (batch 10 F8).
- **A centered or end join on a parent several elements across moves with the parent's aura
  count.** A join on the parent's center or end side is held steady while the parent is empty only on
  an axis where the parent is exactly one element across (batch 11 T9). Where the parent is several
  across (a row of icons under a centered follower), its center really does move as auras come and
  go, and while its engine is empty that center is the engine's 1x1 start corner, so the follower
  sits over the parent's start. Pick the start-side point on that parent to keep the follower still.
- **While unlocked (and not in test mode), an empty chain is laid out from a prediction, and still
  collapses where that cannot be made.** The engine cannot say whether it is empty (its frame count
  is a pool that never shrinks, its size is secret), so the addon predicts it from `C_UnitAuras` and
  `GetWeaponEnchantInfo` (`modules/EmptyWatch.lua`, batch 9 HG-1). Only a parent predicted empty shows
  its one-element placeholder outline and hangs its followers from it; one that holds auras hangs
  them from its engine, past its last aura, as locked. Where the prediction is not knowable (in
  combat, while auras are secret, a secret or raising read, a flag the aura data does not carry, such
  as role or priority auras) the parent counts as not empty, so an empty chain collapses onto itself
  there (the #9 look, each link about 5px under the last): lay such chains out in test mode. The
  prediction is re-read 0.2 s after an aura change (at once on a target or focus switch, so a
  switch never makes a follower jump to the emptied engine and back), so for that moment a follower can sit on the
  placeholder over a new first aura, or past an aura that just ended. It relies on `C_UnitAuras`
  reading a filter string as the engine does (smoke check 191). Combat moves every follower onto its
  engine at the pull (PLAYER_REGEN_DISABLED, before lockdown) and back after it. While the strips
  show, each follower sits one strip row further along the chain (batch 10 F2), so no two strips in a
  chain overlap; locked, the seam is the follower's own spacing again, plus its label's row while its
  label is on. A lock or unlock in combat re-places nothing until combat ends.
- **With "Show the spark on auras without a duration" off, a timed bar's spark sits just inside its
  moving edge, not centered on it.** No binding can tell a region whether its aura has a duration,
  and the duration is secret, so the spark is clipped to the elapsed region, which a timeless aura
  leaves empty (`docs/midnight-quirks.md`). The spark must sit wholly on the elapsed side to be
  clipped, so it moves half its width off center. With the option on (the default) the spark is
  centered, as before. That a zero-duration bar leaves the region empty is still an in-game check
  (`docs/smoke-tests.md`, checks 26 and 63). Moving the spark off the fill onto the elapsed
  background also moves it onto a different backdrop — the elapsed side's background defaults to
  half-opaque and lets whatever sits behind the frame bleed through. So the bar dress
  (`modules/Style_Bars.lua`) keeps the spark additive and desaturates its art in both modes, and
  over the elapsed side it reads as the player's spark color, not the art's native gold (owner
  report 2026-09-14, batch 7 `SP-1`). Normal blending was tried for the clipped spark and painted
  the art's black matte as a box taller than the bar (feedback batch 8 `SP-1`), so the blend is
  never BLEND. Verified in-game only (`docs/smoke-tests.md`, check 85).
