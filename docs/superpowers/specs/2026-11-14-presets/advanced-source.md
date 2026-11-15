# Advanced preset source: the owner's Retail Default profile (2026-11-14)

The 20 containers the Advanced preset is built from, in `containerOrder`, as read from the owner's
SavedVariables. Appearance (`bars`, `icons`, `text`, `label`) and `position` are left out: presets
take appearance from the template and the skin, and place every container on screen. `attach` is kept
as evidence of how the owner stacked them. The two personal custom categories are renamed
`SPECIAL_PLAYER` ("Ka0s Player Buffs", HELPFUL) and `SPECIAL_TARGET` ("Ka0s Target Debuffs", HARMFUL);
their spell lists are not carried.

## 1. [1] PLYR BAR Buffs (All)

- unit `player`, auraType `HELPFUL`, style `bars`, enabled `true`
- attach: mode `screen`, TOPLEFT to BOTTOMLEFT
- categories hidden: `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=any`, `durationMode=any`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=0`, `situations.npcs=every`, `situations.players=every`, `sortDirection=reverse`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=down`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 2. [2] PLYR BAR Wpn Ench (Mine)

- unit `player`, auraType `HELPFUL`, style `bars`, enabled `true`
- attach: mode `container`, container id 1, TOPLEFT to BOTTOMLEFT
- categories hidden: `SPECIAL_PLAYER=hide`, `activeMitigation=hide`, `bigDefensive=hide`, `cancelable=hide`, `castable=hide`, `defensives=hide`, `externals=hide`, `groupBuffs=hide`, `healing=hide`, `important=hide`, `movement=hide`, `offensiveCDs=hide`, `racials=hide`, `raidCDs=hide`, `stances=hide`, `stealable=hide`, `support=hide`, `uncategorized=hide`, `utility=hide`
- filter: `blacklist={}`, `castBy=any`, `durationMode=any`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=0`, `situations.npcs=every`, `situations.players=every`, `sortDirection=reverse`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=down`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 3. [3] PLYR BAR Debuffs (All)

- unit `player`, auraType `HARMFUL`, style `bars`, enabled `true`
- attach: mode `container`, container id 1, TOPLEFT to BOTTOMLEFT
- categories hidden: `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=any`, `durationMode=any`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=0`, `situations.npcs=every`, `situations.players=every`, `sortDirection=reverse`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=down`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 4. [7] PLYR BAR Buffs Short (Mine)

- unit `player`, auraType `HELPFUL`, style `bars`, enabled `true`
- attach: mode `container`, frame `EllesmereUIUnitFrames_Player`, container id 23, BOTTOMRIGHT to TOPRIGHT
- categories hidden: `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=mine`, `durationMode=timed`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=30`, `situations.npcs=every`, `situations.players=every`, `sortDirection=reverse`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=up`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 5. [11] TRGT BAR Buffs (Mine)

- unit `target`, auraType `HELPFUL`, style `bars`, enabled `true`
- attach: mode `container`, frame `EllesmereUIUnitFrames_Target`, container id 18, BOTTOMLEFT to TOPLEFT
- categories hidden: `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=mine`, `durationMode=timed`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=30`, `situations.npcs=every`, `situations.players=every`, `sortDirection=reverse`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=up`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 6. [10] TRGT BAR Debuffs (Mine)

- unit `target`, auraType `HARMFUL`, style `bars`, enabled `true`
- attach: mode `container`, container id 10, TOPLEFT to BOTTOMLEFT
- categories hidden: `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=mine`, `durationMode=timed`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=30`, `situations.npcs=every`, `situations.players=every`, `sortDirection=reverse`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=up`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 7. [17] TRGT ICO Debuffs (All)

- unit `target`, auraType `HARMFUL`, style `icons`, enabled `true`
- attach: mode `frame`, frame `EllesmereUIUnitFrames_Target`, container id 16, TOPLEFT to TOPRIGHT
- categories hidden: none
- filter: `blacklist={}`, `castBy=any`, `durationMode=any`, `hidePermanentEnchants=true`, `maxAuras=16`, `maxDuration=0`, `situations.npcs=every`, `situations.players=every`, `sortDirection=normal`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=false`, `zones.scenario=true`
- layout: `alpha=1`, `axis=horizontal`, `growH=right`, `growV=down`, `level=5`, `lineSpacing=0`, `perLine=8`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 8. [4] PLYR TXT Offensive CD (All)

- unit `player`, auraType `HELPFUL`, style `text`, enabled `true`
- attach: mode `screen`, TOPLEFT to BOTTOMLEFT
- categories hidden: `SPECIAL_PLAYER=hide`, `activeMitigation=hide`, `bigDefensive=hide`, `cancelable=hide`, `castable=hide`, `defensives=hide`, `externals=hide`, `groupBuffs=hide`, `healing=hide`, `important=hide`, `movement=hide`, `racials=hide`, `raidCDs=hide`, `stances=hide`, `stealable=hide`, `support=hide`, `uncategorized=hide`, `utility=hide`, `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=any`, `durationMode=any`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=0`, `situations.npcs=every`, `situations.players=every`, `sortDirection=normal`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=down`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=2`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 9. [5] PLYR TXT Defensive CD (All)

- unit `player`, auraType `HELPFUL`, style `text`, enabled `true`
- attach: mode `container`, container id 13, TOPLEFT to BOTTOMLEFT
- categories hidden: `SPECIAL_PLAYER=hide`, `activeMitigation=hide`, `bigDefensive=hide`, `cancelable=hide`, `castable=hide`, `externals=hide`, `groupBuffs=hide`, `healing=hide`, `important=hide`, `movement=hide`, `offensiveCDs=hide`, `racials=hide`, `raidCDs=hide`, `stances=hide`, `stealable=hide`, `support=hide`, `uncategorized=hide`, `utility=hide`, `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=any`, `durationMode=any`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=0`, `situations.npcs=every`, `situations.players=every`, `sortDirection=normal`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=down`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=2`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 10. [6] PLYR TXT Raid CD (All)

- unit `player`, auraType `HELPFUL`, style `text`, enabled `true`
- attach: mode `container`, container id 14, TOPLEFT to BOTTOMLEFT
- categories hidden: `SPECIAL_PLAYER=hide`, `activeMitigation=hide`, `bigDefensive=hide`, `cancelable=hide`, `castable=hide`, `defensives=hide`, `externals=hide`, `groupBuffs=hide`, `healing=hide`, `important=hide`, `movement=hide`, `offensiveCDs=hide`, `racials=hide`, `stances=hide`, `stealable=hide`, `support=hide`, `uncategorized=hide`, `utility=hide`, `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=any`, `durationMode=any`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=0`, `situations.npcs=every`, `situations.players=every`, `sortDirection=normal`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=down`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=2`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 11. [18] TRGT ICO Buffs (All)

- unit `target`, auraType `HELPFUL`, style `icons`, enabled `true`
- attach: mode `container`, container id 12, TOPLEFT to BOTTOMLEFT
- categories hidden: none
- filter: `blacklist={}`, `castBy=any`, `durationMode=any`, `hidePermanentEnchants=true`, `maxAuras=16`, `maxDuration=0`, `situations.npcs=every`, `situations.players=every`, `sortDirection=normal`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=false`, `zones.scenario=true`
- layout: `alpha=1`, `axis=horizontal`, `growH=right`, `growV=down`, `level=5`, `lineSpacing=0`, `perLine=8`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 12. [12] TRGT BAR CC (All)

- unit `target`, auraType `HARMFUL`, style `bars`, enabled `true`
- attach: mode `container`, container id 22, TOPLEFT to BOTTOMLEFT
- categories hidden: `SPECIAL_TARGET=hide`, `bleed=hide`, `boss=hide`, `ccSnare=hide`, `crowdControl=hide`, `curse=hide`, `disease=hide`, `dispellable=hide`, `dispels=hide`, `fromNonPlayers=hide`, `fromPlayers=hide`, `groupDispellable=hide`, `magic=hide`, `poison=hide`, `priority=hide`, `racialDebuffs=hide`, `raid=hide`, `raidInCombat=hide`, `role=hide`, `uncategorizedDebuffs=hide`, `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=any`, `durationMode=timed`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=30`, `situations.npcs=every`, `situations.players=every`, `sortDirection=reverse`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=false`, `zones.none=true`, `zones.party=true`, `zones.pvp=false`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=up`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 13. [13] TRGT BAR CD PLYR (All)

- unit `target`, auraType `HELPFUL`, style `bars`, enabled `true`
- attach: mode `container`, frame `EllesmereUIUnitFrames_Target`, container id 28, BOTTOMLEFT to TOPLEFT
- categories hidden: `SPECIAL_PLAYER=hide`, `bigDefensive=hide`, `cancelable=hide`, `castable=hide`, `externals=hide`, `groupBuffs=hide`, `healing=hide`, `important=hide`, `racials=hide`, `stances=hide`, `stealable=hide`, `uncategorized=hide`, `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=any`, `durationMode=timed`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=30`, `situations.npcs=every`, `situations.players=every`, `sortDirection=reverse`, `sortMethod=expirationOnly`, `unitFilter.kind=player`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=false`, `zones.none=true`, `zones.party=true`, `zones.pvp=false`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=up`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 14. [8] PLYR BAR Buffs CD (Mine)

- unit `player`, auraType `HELPFUL`, style `bars`, enabled `true`
- attach: mode `container`, frame `EllesmereUIUnitFrames_Player`, container id 26, BOTTOMLEFT to TOPLEFT
- categories hidden: `SPECIAL_PLAYER=hide`, `bigDefensive=hide`, `cancelable=hide`, `castable=hide`, `externals=hide`, `groupBuffs=hide`, `healing=hide`, `important=hide`, `racials=hide`, `stances=hide`, `stealable=hide`, `support=hide`, `uncategorized=hide`, `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=any`, `durationMode=timed`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=30`, `situations.npcs=every`, `situations.players=every`, `sortDirection=reverse`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=up`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 15. [20] FOCS BAR Buffs (Mine)

- unit `focus`, auraType `HELPFUL`, style `bars`, enabled `true`
- attach: mode `frame`, frame `EllesmereUIUnitFrames_Focus`, container id 18, BOTTOMLEFT to TOPLEFT
- categories hidden: `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=mine`, `durationMode=timed`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=0`, `situations.npcs=every`, `situations.players=every`, `sortDirection=reverse`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=up`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 16. [19] FOCS BAR Debuffs (Mine)

- unit `focus`, auraType `HARMFUL`, style `bars`, enabled `true`
- attach: mode `container`, container id 24, TOPLEFT to BOTTOMLEFT
- categories hidden: `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=mine`, `durationMode=timed`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=0`, `situations.npcs=every`, `situations.players=every`, `sortDirection=reverse`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=up`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 17. [9] PLYR BAR Buffs Special (All)

- unit `player`, auraType `HELPFUL`, style `bars`, enabled `true`
- attach: mode `frame`, frame `EllesmereUIUnitFrames_Player`, BOTTOMRIGHT to TOPRIGHT
- categories hidden: `activeMitigation=hide`, `bigDefensive=hide`, `cancelable=hide`, `castable=hide`, `defensives=hide`, `externals=hide`, `groupBuffs=hide`, `healing=hide`, `important=hide`, `movement=hide`, `offensiveCDs=hide`, `racials=hide`, `raidCDs=hide`, `stealable=hide`, `support=hide`, `uncategorized=hide`, `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=mine`, `durationMode=any`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=0`, `situations.npcs=every`, `situations.players=every`, `sortDirection=reverse`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=up`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 18. [16] TRGT BAR Special (All)

- unit `target`, auraType `HARMFUL`, style `bars`, enabled `true`
- attach: mode `frame`, frame `EllesmereUIUnitFrames_Target`, container id 10, BOTTOMLEFT to TOPLEFT
- categories hidden: `SPECIAL_PLAYER=hide`, `activeMitigation=hide`, `bigDefensive=hide`, `bleed=hide`, `boss=hide`, `cancelable=hide`, `castable=hide`, `ccRoot=hide`, `ccSnare=hide`, `crowdControl=hide`, `curse=hide`, `defensives=hide`, `disease=hide`, `dispellable=hide`, `dispels=hide`, `externals=hide`, `fromNonPlayers=hide`, `fromPlayers=hide`, `groupBuffs=hide`, `groupDispellable=hide`, `hardCC=hide`, `healing=hide`, `important=hide`, `magic=hide`, `movement=hide`, `offensiveCDs=hide`, `poison=hide`, `priority=hide`, `racialDebuffs=hide`, `racials=hide`, `raid=hide`, `raidCDs=hide`, `raidInCombat=hide`, `role=hide`, `stances=hide`, `stealable=hide`, `support=hide`, `uncategorized=hide`, `uncategorizedDebuffs=hide`, `utility=hide`, `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=mine`, `durationMode=any`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=0`, `situations.npcs=every`, `situations.players=every`, `sortDirection=reverse`, `sortMethod=expirationOnly`, `unitFilter.kind=all`, `unitFilter.reaction=all`, `whitelist.445474=true`, `zones.arena=true`, `zones.none=true`, `zones.party=true`, `zones.pvp=true`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=up`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 19. [14] TRGT BAR CD NPC (All)

- unit `target`, auraType `HELPFUL`, style `bars`, enabled `true`
- attach: mode `container`, frame `EllesmereUIUnitFrames_Target`, container id 30, BOTTOMLEFT to TOPLEFT
- categories hidden: `SPECIAL_PLAYER=hide`, `activeMitigation=hide`, `defensives=hide`, `groupBuffs=hide`, `healing=hide`, `movement=hide`, `offensiveCDs=hide`, `racials=hide`, `raidCDs=hide`, `stances=hide`, `support=hide`, `uncategorized=hide`, `utility=hide`, `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=any`, `durationMode=timed`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=0`, `situations.npcs=every`, `situations.players=every`, `sortDirection=reverse`, `sortMethod=expirationOnly`, `unitFilter.kind=npc`, `unitFilter.reaction=all`, `whitelist={}`, `zones.arena=false`, `zones.none=true`, `zones.party=true`, `zones.pvp=false`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=up`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

## 20. [15] TRGT BAR STEAL (All)

- unit `target`, auraType `HELPFUL`, style `bars`, enabled `false`
- attach: mode `container`, frame `EllesmereUIUnitFrames_Target`, container id 27, BOTTOMLEFT to TOPLEFT
- categories hidden: `SPECIAL_PLAYER=hide`, `activeMitigation=hide`, `bigDefensive=hide`, `cancelable=hide`, `castable=hide`, `defensives=hide`, `externals=hide`, `groupBuffs=hide`, `healing=hide`, `important=hide`, `movement=hide`, `offensiveCDs=hide`, `racials=hide`, `raidCDs=hide`, `stances=hide`, `support=hide`, `uncategorized=hide`, `utility=hide`, `weaponEnchants=hide`
- filter: `blacklist={}`, `castBy=any`, `durationMode=timed`, `hidePermanentEnchants=true`, `maxAuras=0`, `maxDuration=0`, `situations.npcs=every`, `situations.players=every`, `sortDirection=reverse`, `sortMethod=expirationOnly`, `unitFilter.kind=npc`, `unitFilter.reaction=hostile`, `whitelist={}`, `zones.arena=false`, `zones.none=true`, `zones.party=true`, `zones.pvp=false`, `zones.raid=true`, `zones.scenario=true`
- layout: `alpha=1`, `axis=vertical`, `growH=right`, `growV=up`, `level=5`, `lineSpacing=2`, `perLine=0`, `scale=1`, `spacing=0`, `strata=MEDIUM`
- behavior: `cancelOnRightClick=true`, `clickThrough=false`, `tooltipAnchor=ANCHOR_BOTTOMLEFT`, `tooltipInCombat=true`, `tooltips=true`

