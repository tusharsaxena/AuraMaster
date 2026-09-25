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
  all. The KNOWN GAPS comment above `hardCC` (`defaults/Categories.lua:530`) records each one and why
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
  pushes a container off the side edge it runs toward the same way. Locking puts it back, and the
  stored position never changes.
- **In test mode, a container attached to another hangs from that container's preview extent.** A
  previewing container's engine is disabled and keeps a stale rect, so a container attached to it is
  re-placed onto a frame of ours sized to its placeholder block (`Preview.Extent`), where it sits as
  it would beside real auras; ending test mode puts it back on the engine. Its handle lies toward
  its parent, so the strip is raised above every one of the parent's placeholders. That raise is a frame level:
  a parent set to a higher strata still draws over it. Test mode ending in combat re-places nothing
  (events-frames-taint-§2): the attached container stays where it was until the first visibility
  pass after combat.
- **With "Show the spark on auras without a duration" off, a timed bar's spark sits just inside its
  moving edge, not centered on it.** No binding can tell a region whether its aura has a duration,
  and the duration is secret, so the spark is clipped to the elapsed region, which a timeless aura
  leaves empty (`docs/midnight-quirks.md`). The spark must sit wholly on the elapsed side to be
  clipped, so it moves half its width off center. With the option on (the default) the spark is
  centered, as before. That a zero-duration bar leaves the region empty is still an in-game check
  (`docs/smoke-tests.md`, checks 26 and 63). Moving the spark off the fill onto the elapsed
  background also moves it onto a different backdrop — the elapsed side's background defaults to
  half-opaque and lets whatever sits behind the frame bleed through — so `wireSpark`
  (`modules/Style_Bars.lua`) blends the spark normally there instead of additively, or that bleed-
  through reads as "a random yellow-golden spark" (owner report 2026-09-14, `SP-1`); centered mode
  keeps the additive blend, since its backdrop is the opaque fill. Verified in-game only
  (`docs/smoke-tests.md`, check 85).
