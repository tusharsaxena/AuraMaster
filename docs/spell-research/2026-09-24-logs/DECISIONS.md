# Decisions -- 2026-09-24

The owner's rulings on this bundle's review sheet (`REVIEW.csv`), copied from `tools/spell-research/decisions.json` (the durable record; one entry per sheet row, keyed `<proposal key>#<spell id>#<row type>`). `logs.py ingest` applied the accept and move rulings to `defaults/Categories.lua`; a rejected row is never asked again.

Accepted 109, accepted into another category 24, rejected 545, pending 0.

| Row | Ruling | Type | Class | Spell id | Spell | Category | Date | Proposal |
|---|---|---|---|---|---|---|---|---|
| R0001 | reject | move | PRIEST | 41635 | Prayer of Mending | support | 2026-09-25 | `move\|support\|PRIEST\|prayer of mending\|41635` |
| R0002 | accept | correction-add | HUNTER | 186254 | Bestial Wrath | offensiveCDs | 2026-09-25 | `add\|offensiveCDs\|HUNTER\|bestial wrath\|186254,1235388,1285912` |
| R0003 | accept | correction-add | HUNTER | 1235388 | Bestial Wrath | offensiveCDs | 2026-09-25 | `add\|offensiveCDs\|HUNTER\|bestial wrath\|186254,1235388,1285912` |
| R0004 | accept | correction-add | HUNTER | 1285912 | Bestial Wrath | offensiveCDs | 2026-09-25 | `add\|offensiveCDs\|HUNTER\|bestial wrath\|186254,1235388,1285912` |
| R0005 | accept | correction-add | DEATHKNIGHT | 444826 | Chains of Ice | softCC | 2026-09-25 | `add\|softCC\|DEATHKNIGHT\|chains of ice\|444826` |
| R0006 | reject | move | PALADIN | 200025 | Beacon of Virtue | raidCDs | 2026-09-25 | `move\|raidCDs\|PALADIN\|beacon of virtue\|200025` |
| R0007 | accept | correction-add | PRIEST | 1246768 | Power Word: Shield | healing | 2026-09-25 | `add\|healing\|PRIEST\|power word: shield\|1246768` |
| R0008 | accept | correction-add | DEATHKNIGHT | 460501 | Heart Strike | softCC | 2026-09-25 | `add\|softCC\|DEATHKNIGHT\|heart strike\|460501` |
| R0009 | reject | move | PRIEST | 194384 | Atonement | support | 2026-09-25 | `move\|support\|PRIEST\|atonement\|194384` |
| R0010 | accept | correction-add | DRUID | 77761 | Stampeding Roar | movement | 2026-09-25 | `add\|movement\|DRUID\|stampeding roar\|77761,77764` |
| R0011 | accept | correction-add | DRUID | 77764 | Stampeding Roar | movement | 2026-09-25 | `add\|movement\|DRUID\|stampeding roar\|77761,77764` |
| R0012 | reject | move | WARRIOR | 107574 | Avatar | defensives | 2026-09-25 | `move\|defensives\|WARRIOR\|avatar\|107574` |
| R0013 | reject | move | WARRIOR | 190456 | Ignore Pain | defensives | 2026-09-25 | `move\|defensives\|WARRIOR\|ignore pain\|190456` |
| R0014 | accept | correction-add | EVOKER | 367364 | Reversion | healing | 2026-09-25 | `add\|healing\|EVOKER\|reversion\|367364` |
| R0015 | accept | correction-add | PALADIN | 221883 | Divine Steed | movement | 2026-09-25 | `add\|movement\|PALADIN\|divine steed\|221883,221885,221887,254471,254472,254474,276111,276112,294133,363608,453804` |
| R0016 | accept | correction-add | PALADIN | 221885 | Divine Steed | movement | 2026-09-25 | `add\|movement\|PALADIN\|divine steed\|221883,221885,221887,254471,254472,254474,276111,276112,294133,363608,453804` |
| R0017 | accept | correction-add | PALADIN | 221887 | Divine Steed | movement | 2026-09-25 | `add\|movement\|PALADIN\|divine steed\|221883,221885,221887,254471,254472,254474,276111,276112,294133,363608,453804` |
| R0018 | accept | correction-add | PALADIN | 254471 | Divine Steed | movement | 2026-09-25 | `add\|movement\|PALADIN\|divine steed\|221883,221885,221887,254471,254472,254474,276111,276112,294133,363608,453804` |
| R0019 | accept | correction-add | PALADIN | 254472 | Divine Steed | movement | 2026-09-25 | `add\|movement\|PALADIN\|divine steed\|221883,221885,221887,254471,254472,254474,276111,276112,294133,363608,453804` |
| R0020 | accept | correction-add | PALADIN | 254474 | Divine Steed | movement | 2026-09-25 | `add\|movement\|PALADIN\|divine steed\|221883,221885,221887,254471,254472,254474,276111,276112,294133,363608,453804` |
| R0021 | accept | correction-add | PALADIN | 276111 | Divine Steed | movement | 2026-09-25 | `add\|movement\|PALADIN\|divine steed\|221883,221885,221887,254471,254472,254474,276111,276112,294133,363608,453804` |
| R0022 | accept | correction-add | PALADIN | 276112 | Divine Steed | movement | 2026-09-25 | `add\|movement\|PALADIN\|divine steed\|221883,221885,221887,254471,254472,254474,276111,276112,294133,363608,453804` |
| R0023 | accept | correction-add | PALADIN | 294133 | Divine Steed | movement | 2026-09-25 | `add\|movement\|PALADIN\|divine steed\|221883,221885,221887,254471,254472,254474,276111,276112,294133,363608,453804` |
| R0024 | accept | correction-add | PALADIN | 363608 | Divine Steed | movement | 2026-09-25 | `add\|movement\|PALADIN\|divine steed\|221883,221885,221887,254471,254472,254474,276111,276112,294133,363608,453804` |
| R0025 | accept | correction-add | PALADIN | 453804 | Divine Steed | movement | 2026-09-25 | `add\|movement\|PALADIN\|divine steed\|221883,221885,221887,254471,254472,254474,276111,276112,294133,363608,453804` |
| R0026 | reject | correction-add | DEMONHUNTER | 162264 | Metamorphosis | defensives | 2026-09-25 | `add\|defensives\|DEMONHUNTER\|metamorphosis\|162264` |
| R0027 | accept | deletion | PALADIN | 231895 | Avenging Wrath | offensiveCDs | 2026-09-25 | `replace\|offensiveCDs\|PALADIN\|avenging wrath\|454351` |
| R0028 | accept | correction-add | PALADIN | 454351 | Avenging Wrath | offensiveCDs | 2026-09-25 | `replace\|offensiveCDs\|PALADIN\|avenging wrath\|454351` |
| R0029 | accept | correction-add | SHAMAN | 114052 | Ascendance | offensiveCDs | 2026-09-25 | `add\|offensiveCDs\|SHAMAN\|ascendance\|114052,1219480` |
| R0030 | accept | correction-add | SHAMAN | 1219480 | Ascendance | offensiveCDs | 2026-09-25 | `add\|offensiveCDs\|SHAMAN\|ascendance\|114052,1219480` |
| R0031 | accept | correction-add | WARRIOR | 385391 | Spell Reflection | defensives | 2026-09-25 | `add\|defensives\|WARRIOR\|spell reflection\|385391` |
| R0032 | accept | correction-add | PALADIN | 403876 | Divine Protection | defensives | 2026-09-25 | `add\|defensives\|PALADIN\|divine protection\|403876` |
| R0033 | reject | move | PALADIN | 1044 | Blessing of Freedom | support | 2026-09-25 | `move\|support\|PALADIN\|blessing of freedom\|1044` |
| R0034 | accept | move | PRIEST | 10060 | Power Infusion | support | 2026-09-25 | `move\|support\|PRIEST\|power infusion\|10060` |
| R0035 | accept | correction-add | MONK | 1260617 | Soothing Mist | healing | 2026-09-25 | `add\|healing\|MONK\|soothing mist\|1260617` |
| R0036 | accept | correction-add | HUNTER | 186258 | Aspect of the Cheetah | movement | 2026-09-25 | `add\|movement\|HUNTER\|aspect of the cheetah\|186258` |
| R0037 | accept | correction-add | DRUID | 1227806 | Lifebloom | healing | 2026-09-25 | `add\|healing\|DRUID\|lifebloom\|1227806` |
| R0038 | accept | correction-add | MONK | 116706 | Disable | softCC | 2026-09-25 | `add\|softCC\|MONK\|disable\|116706` |
| R0039 | accept | move | EVOKER | 374227 | Zephyr | movement | 2026-09-25 | `move\|movement\|EVOKER\|zephyr\|374227` |
| R0040 | accept | correction-add | DEMONHUNTER | 187827 | Metamorphosis | offensiveCDs | 2026-09-25 | `add\|offensiveCDs\|DEMONHUNTER\|metamorphosis\|187827` |
| R0041 | accept | deletion | EVOKER | 374348 | Renewing Blaze | defensives | 2026-09-25 | `replace\|defensives\|EVOKER\|renewing blaze\|374349` |
| R0042 | accept | correction-add | EVOKER | 374349 | Renewing Blaze | defensives | 2026-09-25 | `replace\|defensives\|EVOKER\|renewing blaze\|374349` |
| R0043 | accept | correction-add | ROGUE | 427773 | Blind | hardCC | 2026-09-25 | `add\|hardCC\|ROGUE\|blind\|427773` |
| R0044 | accept | correction-add | PALADIN | 212641 | Guardian of Ancient Kings | defensives | 2026-09-25 | `add\|defensives\|PALADIN\|guardian of ancient kings\|212641,393108` |
| R0045 | accept | correction-add | PALADIN | 393108 | Guardian of Ancient Kings | defensives | 2026-09-25 | `add\|defensives\|PALADIN\|guardian of ancient kings\|212641,393108` |
| R0046 | accept | correction-add | SHAMAN | 383648 | Earth Shield | healing | 2026-09-25 | `add\|healing\|SHAMAN\|earth shield\|383648` |
| R0047 | reject | move | SHAMAN | 974 | Earth Shield | support | 2026-09-25 | `move\|support\|SHAMAN\|earth shield\|974` |
| R0048 | accept | correction-add | PRIEST | 200196 | Holy Word: Chastise | hardCC | 2026-09-25 | `add\|hardCC\|PRIEST\|holy word: chastise\|200196` |
| R0049 | accept | correction-add | EVOKER | 381732 | Blessing of the Bronze | support | 2026-09-25 | `add\|support\|EVOKER\|blessing of the bronze\|381732,381741,381746,381749,381750,381751,381752,381756,381757` |
| R0050 | accept | correction-add | EVOKER | 381741 | Blessing of the Bronze | support | 2026-09-25 | `add\|support\|EVOKER\|blessing of the bronze\|381732,381741,381746,381749,381750,381751,381752,381756,381757` |
| R0051 | accept | correction-add | EVOKER | 381746 | Blessing of the Bronze | support | 2026-09-25 | `add\|support\|EVOKER\|blessing of the bronze\|381732,381741,381746,381749,381750,381751,381752,381756,381757` |
| R0052 | accept | correction-add | EVOKER | 381749 | Blessing of the Bronze | support | 2026-09-25 | `add\|support\|EVOKER\|blessing of the bronze\|381732,381741,381746,381749,381750,381751,381752,381756,381757` |
| R0053 | accept | correction-add | EVOKER | 381750 | Blessing of the Bronze | support | 2026-09-25 | `add\|support\|EVOKER\|blessing of the bronze\|381732,381741,381746,381749,381750,381751,381752,381756,381757` |
| R0054 | accept | correction-add | EVOKER | 381751 | Blessing of the Bronze | support | 2026-09-25 | `add\|support\|EVOKER\|blessing of the bronze\|381732,381741,381746,381749,381750,381751,381752,381756,381757` |
| R0055 | accept | correction-add | EVOKER | 381752 | Blessing of the Bronze | support | 2026-09-25 | `add\|support\|EVOKER\|blessing of the bronze\|381732,381741,381746,381749,381750,381751,381752,381756,381757` |
| R0056 | accept | correction-add | EVOKER | 381756 | Blessing of the Bronze | support | 2026-09-25 | `add\|support\|EVOKER\|blessing of the bronze\|381732,381741,381746,381749,381750,381751,381752,381756,381757` |
| R0057 | accept | correction-add | EVOKER | 381757 | Blessing of the Bronze | support | 2026-09-25 | `add\|support\|EVOKER\|blessing of the bronze\|381732,381741,381746,381749,381750,381751,381752,381756,381757` |
| R0058 | accept | deletion | DEMONHUNTER | 323996 | The Hunt | softCC | 2026-09-25 | `replace\|softCC\|DEMONHUNTER\|the hunt\|370970` |
| R0059 | accept | correction-add | DEMONHUNTER | 370970 | The Hunt | softCC | 2026-09-25 | `replace\|softCC\|DEMONHUNTER\|the hunt\|370970` |
| R0060 | accept | correction-add | MONK | 122470 | Touch of Karma | defensives | 2026-09-25 | `add\|defensives\|MONK\|touch of karma\|122470` |
| R0061 | accept | correction-add | HUNTER | 1258508 | Intimidation | hardCC | 2026-09-25 | `add\|hardCC\|HUNTER\|intimidation\|1258508` |
| R0062 | reject | move | PALADIN | 156910 | Beacon of Faith | support | 2026-09-25 | `move\|support\|PALADIN\|beacon of faith\|156910` |
| R0063 | reject | move | PALADIN | 53563 | Beacon of Light | support | 2026-09-25 | `move\|support\|PALADIN\|beacon of light\|53563` |
| R0064 | accept | correction-add | DRUID | 252071 | Incarnation: Avatar of Ashamane | offensiveCDs | 2026-09-25 | `add\|offensiveCDs\|DRUID\|incarnation: avatar of ashamane\|252071` |
| R0065 | reject | addition | DEATHKNIGHT | 207203 | Frost Shield | defensives | 2026-09-25 | `addition\|defensives\|DEATHKNIGHT\|frost shield\|207203` |
| R0066 | reject | addition | DRUID | 372505 | Ursoc's Fury | defensives | 2026-09-25 | `addition\|defensives\|DRUID\|ursoc's fury\|372505` |
| R0067 | reject | addition | MONK | 414143 | Yu'lon's Grace | defensives | 2026-09-25 | `addition\|defensives\|MONK\|yu'lon's grace\|414143` |
| R0068 | reject | addition | PALADIN | 209388 | Bulwark of Order | defensives | 2026-09-25 | `addition\|defensives\|PALADIN\|bulwark of order\|209388` |
| R0069 | reject | addition | DEATHKNIGHT | 440290 | Rune Carved Plates | defensives | 2026-09-25 | `addition\|defensives\|DEATHKNIGHT\|rune carved plates\|440290` |
| R0070 | reject | addition | DEATHKNIGHT | 440289 | Rune Carved Plates | defensives | 2026-09-25 | `addition\|defensives\|DEATHKNIGHT\|rune carved plates\|440289` |
| R0071 | reject | addition | PALADIN | 461867 | Sacrosanct Crusade | defensives | 2026-09-25 | `addition\|defensives\|PALADIN\|sacrosanct crusade\|461867` |
| R0072 | reject | addition | SHAMAN | 457387 | Wind Barrier | defensives | 2026-09-25 | `addition\|defensives\|SHAMAN\|wind barrier\|457387` |
| R0073 | reject | addition | DEMONHUNTER | 427901 | Deflecting Dance | defensives | 2026-09-25 | `addition\|defensives\|DEMONHUNTER\|deflecting dance\|427901` |
| R0074 | reject | addition | DEATHKNIGHT | 434034 | Blood-Soaked Ground | defensives | 2026-09-25 | `addition\|defensives\|DEATHKNIGHT\|blood-soaked ground\|434034` |
| R0075 | reject | addition | PRIEST | 377066 | Mental Fortitude | defensives | 2026-09-25 | `addition\|defensives\|PRIEST\|mental fortitude\|377066` |
| R0076 | reject | addition | DEMONHUNTER | 1266619 | First In, Last Out | defensives | 2026-09-25 | `addition\|defensives\|DEMONHUNTER\|first in, last out\|1266619` |
| R0077 | reject | addition | DEMONHUNTER | 1265857 | Revel in Pain | defensives | 2026-09-25 | `addition\|defensives\|DEMONHUNTER\|revel in pain\|1265857` |
| R0078 | reject | addition | WARRIOR | 438591 | Keep Your Feet on the Ground | defensives | 2026-09-25 | `addition\|defensives\|WARRIOR\|keep your feet on the ground\|438591` |
| R0079 | reject | addition | DEATHKNIGHT | 391527 | Umbilicus Eternus | defensives | 2026-09-25 | `addition\|defensives\|DEATHKNIGHT\|umbilicus eternus\|391527` |
| R0080 | reject | addition | PRIEST | 193065 | Protective Light | defensives | 2026-09-25 | `addition\|defensives\|PRIEST\|protective light\|193065` |
| R0081 | accept | addition | MAGE | 235450 | Prismatic Barrier | defensives | 2026-09-25 | `addition\|defensives\|MAGE\|prismatic barrier\|235450` |
| R0082 | reject | addition | DRUID | 385787 | Matted Fur | defensives | 2026-09-25 | `addition\|defensives\|DRUID\|matted fur\|385787` |
| R0083 | reject | addition | MAGE | 449336 | Merely a Setback | defensives | 2026-09-25 | `addition\|defensives\|MAGE\|merely a setback\|449336` |
| R0084 | accept | addition | MAGE | 11426 | Ice Barrier | defensives | 2026-09-25 | `addition\|defensives\|MAGE\|ice barrier\|11426` |
| R0085 | reject | addition | HUNTER | 451447 | Don't Look Back | defensives | 2026-09-25 | `addition\|defensives\|HUNTER\|don't look back\|451447` |
| R0086 | reject | addition | DRUID | 24858 | Moonkin Form | defensives | 2026-09-25 | `addition\|defensives\|DRUID\|moonkin form\|24858` |
| R0087 | reject | addition | ROGUE | 428488 | Exhilarating Execution | defensives | 2026-09-25 | `addition\|defensives\|ROGUE\|exhilarating execution\|428488` |
| R0088 | reject | addition | ROGUE | 386237 | Fade to Nothing | defensives | 2026-09-25 | `addition\|defensives\|ROGUE\|fade to nothing\|386237` |
| R0089 | reject | addition | DRUID | 5487 | Bear Form | defensives | 2026-09-25 | `addition\|defensives\|DRUID\|bear form\|5487` |
| R0090 | reject | addition | MONK | 451253 | Mantra of Purity | defensives | 2026-09-25 | `addition\|defensives\|MONK\|mantra of purity\|451253` |
| R0091 | accept | addition | PALADIN | 389539 | Sentinel | defensives | 2026-09-25 | `addition\|defensives\|PALADIN\|sentinel\|389539` |
| R0092 | move | addition | SHAMAN | 260881 | Spirit Wolf | movement | 2026-09-25 | `addition\|defensives\|SHAMAN\|spirit wolf\|260881` |
| R0093 | reject | addition | DRUID | 1278800 | Natural Resilience | defensives | 2026-09-25 | `addition\|defensives\|DRUID\|natural resilience\|1278800` |
| R0094 | reject | addition | PALADIN | 1287955 | Rune of Void-Tainted Shell | defensives | 2026-09-25 | `addition\|defensives\|PALADIN\|rune of void-tainted shell\|1287955` |
| R0095 | reject | addition | DEMONHUNTER | 1266616 | Demon Muzzle | defensives | 2026-09-25 | `addition\|defensives\|DEMONHUNTER\|demon muzzle\|1266616` |
| R0096 | reject | addition | PALADIN | 1237611 | Palisade's Protection | defensives | 2026-09-25 | `addition\|defensives\|PALADIN\|palisade's protection\|1237611` |
| R0097 | reject | addition | DEMONHUNTER | 263648 | Soul Barrier | defensives | 2026-09-25 | `addition\|defensives\|DEMONHUNTER\|soul barrier\|263648` |
| R0098 | reject | addition | MONK | 451230 | Predictive Training | defensives | 2026-09-25 | `addition\|defensives\|MONK\|predictive training\|451230` |
| R0099 | reject | addition | MONK | 1241059 | Celestial Infusion | defensives | 2026-09-25 | `addition\|defensives\|MONK\|celestial infusion\|1241059` |
| R0100 | reject | addition | DEATHKNIGHT | 454871 | Blood Draw | defensives | 2026-09-25 | `addition\|defensives\|DEATHKNIGHT\|blood draw\|454871` |
| R0101 | reject | addition | EVOKER | 410355 | Stretch Time | defensives | 2026-09-25 | `addition\|defensives\|EVOKER\|stretch time\|410355` |
| R0102 | reject | addition | PRIEST | 586 | Fade | defensives | 2026-09-25 | `addition\|defensives\|PRIEST\|fade\|586` |
| R0103 | reject | addition | DEMONHUNTER | 393009 | Fel Flame Fortification | defensives | 2026-09-25 | `addition\|defensives\|DEMONHUNTER\|fel flame fortification\|393009` |
| R0104 | reject | addition | SHAMAN | 355634 | Windveil | defensives | 2026-09-25 | `addition\|defensives\|SHAMAN\|windveil\|355634` |
| R0105 | reject | addition | DEATHKNIGHT | 1287955 | Rune of Void-Tainted Shell | defensives | 2026-09-25 | `addition\|defensives\|DEATHKNIGHT\|rune of void-tainted shell\|1287955` |
| R0106 | accept | addition | MAGE | 414658 | Ice Cold | defensives | 2026-09-25 | `addition\|defensives\|MAGE\|ice cold\|414658` |
| R0107 | reject | addition | PRIEST | 45242 | Focused Will | defensives | 2026-09-25 | `addition\|defensives\|PRIEST\|focused will\|45242` |
| R0108 | reject | addition | DEMONHUNTER | 1287955 | Rune of Void-Tainted Shell | defensives | 2026-09-25 | `addition\|defensives\|DEMONHUNTER\|rune of void-tainted shell\|1287955` |
| R0109 | accept | addition | DEMONHUNTER | 207771 | Fiery Brand | defensives | 2026-09-25 | `addition\|defensives\|DEMONHUNTER\|fiery brand\|207771` |
| R0110 | move | addition | WARRIOR | 436358 | Demolish | offensiveCDs | 2026-09-25 | `addition\|defensives\|WARRIOR\|demolish\|436358` |
| R0111 | reject | addition | DEATHKNIGHT | 1254638 | Solar Core Igniter | defensives | 2026-09-25 | `addition\|defensives\|DEATHKNIGHT\|solar core igniter\|1254638` |
| R0112 | reject | addition | MAGE | 1287955 | Rune of Void-Tainted Shell | defensives | 2026-09-25 | `addition\|defensives\|MAGE\|rune of void-tainted shell\|1287955` |
| R0113 | reject | addition | PALADIN | 1301739 | Blessed Word | defensives | 2026-09-25 | `addition\|defensives\|PALADIN\|blessed word\|1301739` |
| R0114 | reject | addition | MONK | 1263631 | Awakening Spirit | defensives | 2026-09-25 | `addition\|defensives\|MONK\|awakening spirit\|1263631` |
| R0115 | reject | addition | WARLOCK | 1287955 | Rune of Void-Tainted Shell | defensives | 2026-09-25 | `addition\|defensives\|WARLOCK\|rune of void-tainted shell\|1287955` |
| R0116 | reject | addition | PALADIN | 1277046 | Adjudication | defensives | 2026-09-25 | `addition\|defensives\|PALADIN\|adjudication\|1277046` |
| R0117 | reject | addition | PRIEST | 426401 | Focused Will | defensives | 2026-09-25 | `addition\|defensives\|PRIEST\|focused will\|426401` |
| R0118 | reject | addition | MONK | 448508 | Jade Sanctuary | defensives | 2026-09-25 | `addition\|defensives\|MONK\|jade sanctuary\|448508` |
| R0119 | reject | addition | WARRIOR | 458245 | Second Wind | defensives | 2026-09-25 | `addition\|defensives\|WARRIOR\|second wind\|458245` |
| R0120 | accept | addition | MAGE | 235313 | Blazing Barrier | defensives | 2026-09-25 | `addition\|defensives\|MAGE\|blazing barrier\|235313` |
| R0121 | accept | addition | MONK | 132578 | Invoke Niuzao, the Black Ox | defensives | 2026-09-25 | `addition\|defensives\|MONK\|invoke niuzao, the black ox\|132578` |
| R0122 | reject | addition | MONK | 1287955 | Rune of Void-Tainted Shell | defensives | 2026-09-25 | `addition\|defensives\|MONK\|rune of void-tainted shell\|1287955` |
| R0123 | reject | addition | DRUID | 1287955 | Rune of Void-Tainted Shell | defensives | 2026-09-25 | `addition\|defensives\|DRUID\|rune of void-tainted shell\|1287955` |
| R0124 | move | addition | DRUID | 740 | Tranquility | raidCDs | 2026-09-25 | `addition\|defensives\|DRUID\|tranquility\|740` |
| R0125 | reject | addition | HUNTER | 1287955 | Rune of Void-Tainted Shell | defensives | 2026-09-25 | `addition\|defensives\|HUNTER\|rune of void-tainted shell\|1287955` |
| R0126 | reject | addition | WARRIOR | 1287955 | Rune of Void-Tainted Shell | defensives | 2026-09-25 | `addition\|defensives\|WARRIOR\|rune of void-tainted shell\|1287955` |
| R0127 | reject | addition | DEATHKNIGHT | 374748 | Perseverance of the Ebon Blade | defensives | 2026-09-25 | `addition\|defensives\|DEATHKNIGHT\|perseverance of the ebon blade\|374748` |
| R0128 | reject | addition | DEATHKNIGHT | 1254641 | Rotting Globule | defensives | 2026-09-25 | `addition\|defensives\|DEATHKNIGHT\|rotting globule\|1254641` |
| R0129 | reject | addition | SHAMAN | 1287955 | Rune of Void-Tainted Shell | defensives | 2026-09-25 | `addition\|defensives\|SHAMAN\|rune of void-tainted shell\|1287955` |
| R0130 | reject | addition | DEATHKNIGHT | 1254520 | Gelatinous Protection | defensives | 2026-09-25 | `addition\|defensives\|DEATHKNIGHT\|gelatinous protection\|1254520` |
| R0131 | reject | addition | PALADIN | 1254638 | Solar Core Igniter | defensives | 2026-09-25 | `addition\|defensives\|PALADIN\|solar core igniter\|1254638` |
| R0132 | reject | addition | PRIEST | 1287955 | Rune of Void-Tainted Shell | defensives | 2026-09-25 | `addition\|defensives\|PRIEST\|rune of void-tainted shell\|1287955` |
| R0133 | reject | addition | WARRIOR | 1242032 | Worldsoul Aegis | defensives | 2026-09-25 | `addition\|defensives\|WARRIOR\|worldsoul aegis\|1242032` |
| R0134 | reject | addition | PALADIN | 1254520 | Gelatinous Protection | defensives | 2026-09-25 | `addition\|defensives\|PALADIN\|gelatinous protection\|1254520` |
| R0135 | reject | addition | MONK | 455179 | Elixir of Determination | defensives | 2026-09-25 | `addition\|defensives\|MONK\|elixir of determination\|455179` |
| R0136 | reject | addition | PRIEST | 114214 | Angelic Bulwark | defensives | 2026-09-25 | `addition\|defensives\|PRIEST\|angelic bulwark\|114214` |
| R0137 | reject | addition | DEATHKNIGHT | 1223612 | Ethereal Barrier | defensives | 2026-09-25 | `addition\|defensives\|DEATHKNIGHT\|ethereal barrier\|1223612` |
| R0138 | reject | addition | WARRIOR | 1254520 | Gelatinous Protection | defensives | 2026-09-25 | `addition\|defensives\|WARRIOR\|gelatinous protection\|1254520` |
| R0139 | reject | addition | EVOKER | 1287955 | Rune of Void-Tainted Shell | defensives | 2026-09-25 | `addition\|defensives\|EVOKER\|rune of void-tainted shell\|1287955` |
| R0140 | reject | addition | MONK | 1223612 | Ethereal Barrier | defensives | 2026-09-25 | `addition\|defensives\|MONK\|ethereal barrier\|1223612` |
| R0141 | reject | addition | EVOKER | 431872 | Temporality | defensives | 2026-09-25 | `addition\|defensives\|EVOKER\|temporality\|431872` |
| R0142 | reject | addition | WARRIOR | 386208 | Defensive Stance | defensives | 2026-09-25 | `addition\|defensives\|WARRIOR\|defensive stance\|386208` |
| R0143 | reject | addition | PALADIN | 1223612 | Ethereal Barrier | defensives | 2026-09-25 | `addition\|defensives\|PALADIN\|ethereal barrier\|1223612` |
| R0144 | reject | addition | DEATHKNIGHT | 1263861 | Consumption | defensives | 2026-09-25 | `addition\|defensives\|DEATHKNIGHT\|consumption\|1263861` |
| R0145 | reject | addition | DRUID | 1223612 | Ethereal Barrier | defensives | 2026-09-25 | `addition\|defensives\|DRUID\|ethereal barrier\|1223612` |
| R0146 | reject | addition | WARLOCK | 394810 | Soulburn: Drain Life | defensives | 2026-09-25 | `addition\|defensives\|WARLOCK\|soulburn: drain life\|394810` |
| R0147 | reject | addition | WARRIOR | 1237611 | Palisade's Protection | defensives | 2026-09-25 | `addition\|defensives\|WARRIOR\|palisade's protection\|1237611` |
| R0148 | reject | addition | ROGUE | 1287955 | Rune of Void-Tainted Shell | defensives | 2026-09-25 | `addition\|defensives\|ROGUE\|rune of void-tainted shell\|1287955` |
| R0149 | reject | addition | WARLOCK | 389614 | Abyss Walker | defensives | 2026-09-25 | `addition\|defensives\|WARLOCK\|abyss walker\|389614` |
| R0150 | reject | addition | PRIEST | 421453 | Ultimate Penitence | defensives | 2026-09-25 | `addition\|defensives\|PRIEST\|ultimate penitence\|421453` |
| R0151 | reject | addition | ROGUE | 45182 | Cheating Death | defensives | 2026-09-25 | `addition\|defensives\|ROGUE\|cheating death\|45182` |
| R0152 | reject | addition | DEATHKNIGHT | 1254514 | Coalesced Jelly | defensives | 2026-09-25 | `addition\|defensives\|DEATHKNIGHT\|coalesced jelly\|1254514` |
| R0153 | reject | addition | WARRIOR | 1254638 | Solar Core Igniter | defensives | 2026-09-25 | `addition\|defensives\|WARRIOR\|solar core igniter\|1254638` |
| R0154 | reject | addition | PALADIN | 1254514 | Coalesced Jelly | defensives | 2026-09-25 | `addition\|defensives\|PALADIN\|coalesced jelly\|1254514` |
| R0155 | reject | addition | WARRIOR | 386397 | Battle-Scarred Veteran | defensives | 2026-09-25 | `addition\|defensives\|WARRIOR\|battle-scarred veteran\|386397` |
| R0156 | reject | addition | SHAMAN | 65116 | Stoneform | defensives | 2026-09-25 | `addition\|defensives\|SHAMAN\|stoneform\|65116` |
| R0157 | reject | addition | DRUID | 1254520 | Gelatinous Protection | defensives | 2026-09-25 | `addition\|defensives\|DRUID\|gelatinous protection\|1254520` |
| R0158 | reject | addition | HUNTER | 65116 | Stoneform | defensives | 2026-09-25 | `addition\|defensives\|HUNTER\|stoneform\|65116` |
| R0159 | reject | addition | MAGE | 65116 | Stoneform | defensives | 2026-09-25 | `addition\|defensives\|MAGE\|stoneform\|65116` |
| R0160 | reject | addition | PALADIN | 65116 | Stoneform | defensives | 2026-09-25 | `addition\|defensives\|PALADIN\|stoneform\|65116` |
| R0161 | reject | addition | PALADIN | 1254641 | Rotting Globule | defensives | 2026-09-25 | `addition\|defensives\|PALADIN\|rotting globule\|1254641` |
| R0162 | reject | addition | DRUID | 1263141 | Gloom-Spattered Dreadscale | defensives | 2026-09-25 | `addition\|defensives\|DRUID\|gloom-spattered dreadscale\|1263141` |
| R0163 | reject | addition | MONK | 1254638 | Solar Core Igniter | defensives | 2026-09-25 | `addition\|defensives\|MONK\|solar core igniter\|1254638` |
| R0164 | reject | addition | DEMONHUNTER | 1255367 | Tangle of Vibrant Vines | defensives | 2026-09-25 | `addition\|defensives\|DEMONHUNTER\|tangle of vibrant vines\|1255367` |
| R0165 | reject | addition | MONK | 1263141 | Gloom-Spattered Dreadscale | defensives | 2026-09-25 | `addition\|defensives\|MONK\|gloom-spattered dreadscale\|1263141` |
| R0166 | reject | addition | MONK | 442749 | Niuzao's Protection | defensives | 2026-09-25 | `addition\|defensives\|MONK\|niuzao's protection\|442749` |
| R0167 | reject | addition | DEATHKNIGHT | 433981 | Newly Turned | defensives | 2026-09-25 | `addition\|defensives\|DEATHKNIGHT\|newly turned\|433981` |
| R0168 | reject | addition | WARRIOR | 1254514 | Coalesced Jelly | defensives | 2026-09-25 | `addition\|defensives\|WARRIOR\|coalesced jelly\|1254514` |
| R0169 | reject | addition | DEATHKNIGHT | 391459 | Sanguine Ground | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DEATHKNIGHT\|sanguine ground\|391459` |
| R0170 | reject | addition | DEATHKNIGHT | 463730 | Coagulating Blood | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DEATHKNIGHT\|coagulating blood\|463730` |
| R0171 | reject | addition | PALADIN | 393038 | Strength in Adversity | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|PALADIN\|strength in adversity\|393038` |
| R0172 | reject | addition | DEATHKNIGHT | 273947 | Hemostasis | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DEATHKNIGHT\|hemostasis\|273947` |
| R0173 | reject | addition | MONK | 195630 | Elusive Brawler | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|MONK\|elusive brawler\|195630` |
| R0174 | reject | addition | DEATHKNIGHT | 1264304 | Lifeblood | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DEATHKNIGHT\|lifeblood\|1264304` |
| R0175 | reject | addition | PALADIN | 386652 | Bulwark of Righteous Fury | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|PALADIN\|bulwark of righteous fury\|386652` |
| R0176 | reject | addition | DEATHKNIGHT | 1265968 | Boiling Point | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DEATHKNIGHT\|boiling point\|1265968` |
| R0177 | reject | addition | DEATHKNIGHT | 1265982 | Boiling Point | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DEATHKNIGHT\|boiling point\|1265982` |
| R0178 | reject | addition | PALADIN | 85416 | Grand Crusader | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|PALADIN\|grand crusader\|85416` |
| R0179 | reject | addition | DEATHKNIGHT | 274009 | Voracious | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DEATHKNIGHT\|voracious\|274009` |
| R0180 | reject | addition | PALADIN | 182104 | Shining Light | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|PALADIN\|shining light\|182104` |
| R0181 | reject | addition | PALADIN | 1269179 | Valor | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|PALADIN\|valor\|1269179` |
| R0182 | reject | addition | PALADIN | 1272298 | Light-Blessed Shield | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|PALADIN\|light-blessed shield\|1272298` |
| R0183 | reject | addition | PALADIN | 280375 | Redoubt | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|PALADIN\|redoubt\|280375` |
| R0184 | reject | addition | MONK | 228563 | Blackout Combo | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|MONK\|blackout combo\|228563` |
| R0185 | reject | addition | DRUID | 213708 | Galactic Guardian | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DRUID\|galactic guardian\|213708` |
| R0186 | reject | addition | PALADIN | 188370 | Consecration | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|PALADIN\|consecration\|188370` |
| R0187 | reject | addition | DRUID | 93622 | Gore | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DRUID\|gore\|93622` |
| R0188 | reject | addition | MONK | 383800 | Counterstrike | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|MONK\|counterstrike\|383800` |
| R0189 | reject | addition | WARRIOR | 224324 | Shield Slam! | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|WARRIOR\|shield slam!\|224324` |
| R0190 | reject | addition | MONK | 1260619 | Elevated Stagger | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|MONK\|elevated stagger\|1260619` |
| R0191 | reject | addition | DEMONHUNTER | 203981 | Soul Fragments | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DEMONHUNTER\|soul fragments\|203981` |
| R0192 | reject | addition | MONK | 393515 | Pretense of Instability | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|MONK\|pretense of instability\|393515` |
| R0193 | reject | addition | PALADIN | 327510 | Shining Light | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|PALADIN\|shining light\|327510` |
| R0194 | reject | addition | MONK | 1265307 | Empty Barrel | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|MONK\|empty barrel\|1265307` |
| R0195 | reject | addition | DEATHKNIGHT | 461130 | Visceral Strength | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DEATHKNIGHT\|visceral strength\|461130` |
| R0196 | reject | addition | DRUID | 1251877 | Gift of an Ancient Guardian | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DRUID\|gift of an ancient guardian\|1251877` |
| R0197 | reject | addition | DRUID | 1272376 | Celestial Might | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DRUID\|celestial might\|1272376` |
| R0198 | reject | addition | MONK | 1301477 | Hot Potato | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|MONK\|hot potato\|1301477` |
| R0199 | reject | addition | MONK | 1241109 | Niuzao's Resolve | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|MONK\|niuzao's resolve\|1241109` |
| R0200 | reject | addition | DRUID | 1301286 | Gorestained Claws | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DRUID\|gorestained claws\|1301286` |
| R0201 | reject | addition | DRUID | 441602 | Ravage | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DRUID\|ravage\|441602` |
| R0202 | accept | addition | MONK | 116847 | Rushing Jade Wind | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|MONK\|rushing jade wind\|116847` |
| R0203 | reject | addition | DRUID | 1307881 | Gory Fur | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DRUID\|gory fur\|1307881` |
| R0204 | reject | addition | WARRIOR | 1300681 | Vengeful Shield | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|WARRIOR\|vengeful shield\|1300681` |
| R0205 | reject | addition | DRUID | 400734 | After the Wildfire | activeMitigation | 2026-09-25 | `addition\|activeMitigation\|DRUID\|after the wildfire\|400734` |
| R0206 | move | addition | MONK | 443113 | Strength of the Black Ox | healing | 2026-09-25 | `addition\|raidCDs\|MONK\|strength of the black ox\|443113` |
| R0207 | move | addition | EVOKER | 373862 | Temporal Anomaly | healing | 2026-09-25 | `addition\|raidCDs\|EVOKER\|temporal anomaly\|373862` |
| R0208 | move | addition | EVOKER | 355941 | Dream Breath | healing | 2026-09-25 | `addition\|raidCDs\|EVOKER\|dream breath\|355941` |
| R0209 | move | addition | EVOKER | 1291636 | Temporal Barrier | healing | 2026-09-25 | `addition\|raidCDs\|EVOKER\|temporal barrier\|1291636` |
| R0210 | move | addition | MONK | 406220 | Chi Cocoon | healing | 2026-09-25 | `addition\|raidCDs\|MONK\|chi cocoon\|406220` |
| R0211 | move | addition | EVOKER | 376788 | Dream Breath | healing | 2026-09-25 | `addition\|raidCDs\|EVOKER\|dream breath\|376788` |
| R0212 | reject | addition | PALADIN | 414407 | Veneration | raidCDs | 2026-09-25 | `addition\|raidCDs\|PALADIN\|veneration\|414407` |
| R0213 | move | addition | EVOKER | 409895 | Verdant Embrace | healing | 2026-09-25 | `addition\|raidCDs\|EVOKER\|verdant embrace\|409895` |
| R0214 | move | addition | MONK | 1260681 | Chi Cocoon | healing | 2026-09-25 | `addition\|raidCDs\|MONK\|chi cocoon\|1260681` |
| R0215 | move | addition | EVOKER | 409678 | Chrono Ward | healing | 2026-09-25 | `addition\|raidCDs\|EVOKER\|chrono ward\|409678` |
| R0216 | move | addition | EVOKER | 363534 | Rewind | healing | 2026-09-25 | `addition\|raidCDs\|EVOKER\|rewind\|363534` |
| R0217 | reject | addition | PRIEST | 1263727 | Litany of Lightblind Wrath | raidCDs | 2026-09-25 | `addition\|raidCDs\|PRIEST\|litany of lightblind wrath\|1263727` |
| R0218 | reject | addition | EVOKER | 1263727 | Litany of Lightblind Wrath | raidCDs | 2026-09-25 | `addition\|raidCDs\|EVOKER\|litany of lightblind wrath\|1263727` |
| R0219 | reject | addition | EVOKER | 404381 | Defy Fate | raidCDs | 2026-09-25 | `addition\|raidCDs\|EVOKER\|defy fate\|404381` |
| R0220 | accept | addition | HUNTER | 466904 | Harrier's Cry | raidCDs | 2026-09-25 | `addition\|raidCDs\|HUNTER\|harrier's cry\|466904` |
| R0221 | accept | addition | WARLOCK | 1243972 | Void-touched Drums | raidCDs | 2026-09-25 | `addition\|raidCDs\|WARLOCK\|void-touched drums\|1243972` |
| R0222 | accept | addition | DRUID | 1243972 | Void-touched Drums | raidCDs | 2026-09-25 | `addition\|raidCDs\|DRUID\|void-touched drums\|1243972` |
| R0223 | accept | addition | ROGUE | 1243972 | Void-touched Drums | raidCDs | 2026-09-25 | `addition\|raidCDs\|ROGUE\|void-touched drums\|1243972` |
| R0224 | reject | addition | WARRIOR | 1270731 | Violent Euphoria | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|WARRIOR\|violent euphoria\|1270731` |
| R0225 | accept | addition | WARLOCK | 1276767 | Tyrant's Oblation | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|WARLOCK\|tyrant's oblation\|1276767` |
| R0226 | reject | addition | DRUID | 378990 | Lycara's Teachings | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|DRUID\|lycara's teachings\|378990` |
| R0227 | reject | addition | DRUID | 207640 | Abundance | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|DRUID\|abundance\|207640` |
| R0228 | reject | addition | DEATHKNIGHT | 1310372 | Blood Debt | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|DEATHKNIGHT\|blood debt\|1310372` |
| R0229 | reject | addition | DEATHKNIGHT | 469169 | Swift and Painful | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|DEATHKNIGHT\|swift and painful\|469169` |
| R0230 | reject | addition | DEATHKNIGHT | 1300369 | Relentless Rider's Strength | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|DEATHKNIGHT\|relentless rider's strength\|1300369` |
| R0231 | accept | addition | PRIEST | 373316 | Idol of Y'Shaarj | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|PRIEST\|idol of y'shaarj\|373316` |
| R0232 | reject | addition | DEATHKNIGHT | 433925 | Essence of the Blood Queen | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|DEATHKNIGHT\|essence of the blood queen\|433925` |
| R0233 | reject | addition | MONK | 1238904 | Heart of the Jade Serpent | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|MONK\|heart of the jade serpent\|1238904` |
| R0234 | reject | addition | MONK | 443616 | Heart of the Jade Serpent | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|MONK\|heart of the jade serpent\|443616` |
| R0235 | reject | addition | PALADIN | 1252818 | Akil'zon's Cry of Victory | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|PALADIN\|akil'zon's cry of victory\|1252818` |
| R0236 | reject | addition | DEATHKNIGHT | 1265630 | Chosen of Frostbrood | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|DEATHKNIGHT\|chosen of frostbrood\|1265630` |
| R0237 | reject | addition | MONK | 1252818 | Akil'zon's Cry of Victory | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|MONK\|akil'zon's cry of victory\|1252818` |
| R0238 | reject | addition | EVOKER | 1271783 | Rising Fury | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|EVOKER\|rising fury\|1271783` |
| R0239 | reject | addition | PRIEST | 1304485 | Ancient Madness | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|PRIEST\|ancient madness\|1304485` |
| R0240 | accept | addition | EVOKER | 431698 | Temporal Burst | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|EVOKER\|temporal burst\|431698` |
| R0241 | reject | addition | MAGE | 383874 | Hyperthermia | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|MAGE\|hyperthermia\|383874` |
| R0242 | reject | addition | WARRIOR | 386164 | Battle Stance | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|WARRIOR\|battle stance\|386164` |
| R0243 | reject | addition | EVOKER | 431991 | Time Convergence | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|EVOKER\|time convergence\|431991` |
| R0244 | reject | addition | ROGUE | 457273 | Lingering Darkness | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|ROGUE\|lingering darkness\|457273` |
| R0245 | reject | addition | DEMONHUNTER | 1252818 | Akil'zon's Cry of Victory | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|DEMONHUNTER\|akil'zon's cry of victory\|1252818` |
| R0246 | reject | addition | DRUID | 154797 | Touch of Elune - Night | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|DRUID\|touch of elune - night\|154797` |
| R0247 | reject | addition | DRUID | 154796 | Touch of Elune - Day | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|DRUID\|touch of elune - day\|154796` |
| R0248 | reject | addition | DRUID | 26297 | Berserking | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|DRUID\|berserking\|26297` |
| R0249 | reject | addition | MAGE | 1260277 | Lesser Time Warp | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|MAGE\|lesser time warp\|1260277` |
| R0250 | reject | addition | EVOKER | 1271799 | Risen Fury | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|EVOKER\|risen fury\|1271799` |
| R0251 | reject | addition | MAGE | 26297 | Berserking | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|MAGE\|berserking\|26297` |
| R0252 | reject | addition | SHAMAN | 26297 | Berserking | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|SHAMAN\|berserking\|26297` |
| R0253 | reject | addition | ROGUE | 1214937 | Jackpot | offensiveCDs | 2026-09-25 | `addition\|offensiveCDs\|ROGUE\|jackpot\|1214937` |
| R0254 | accept | addition | SHAMAN | 382024 | Earthliving Weapon | healing | 2026-09-25 | `addition\|healing\|SHAMAN\|earthliving weapon\|382024` |
| R0255 | accept | addition | PRIEST | 77489 | Echo of Light | healing | 2026-09-25 | `addition\|healing\|PRIEST\|echo of light\|77489` |
| R0256 | reject | addition | PALADIN | 432607 | Holy Bulwark | healing | 2026-09-25 | `addition\|healing\|PALADIN\|holy bulwark\|432607` |
| R0257 | reject | addition | MONK | 1265145 | Refreshing Drink | healing | 2026-09-25 | `addition\|healing\|MONK\|refreshing drink\|1265145` |
| R0258 | reject | addition | MAGE | 1285161 | Protective Toadstools | healing | 2026-09-25 | `addition\|healing\|MAGE\|protective toadstools\|1285161` |
| R0259 | reject | addition | SHAMAN | 462568 | Elemental Resistance | support | 2026-09-25 | `addition\|support\|SHAMAN\|elemental resistance\|462568` |
| R0260 | move | addition | PALADIN | 1245369 | Beacon of the Savior | healing | 2026-09-25 | `addition\|support\|PALADIN\|beacon of the savior\|1245369` |
| R0261 | move | addition | PALADIN | 1244893 | Beacon of the Savior | healing | 2026-09-25 | `addition\|support\|PALADIN\|beacon of the savior\|1244893` |
| R0262 | reject | addition | SHAMAN | 1300642 | Condensation | support | 2026-09-25 | `addition\|support\|SHAMAN\|condensation\|1300642` |
| R0263 | reject | addition | PALADIN | 431415 | Sun Sear | support | 2026-09-25 | `addition\|support\|PALADIN\|sun sear\|431415` |
| R0264 | reject | addition | DRUID | 439530 | Symbiotic Blooms | support | 2026-09-25 | `addition\|support\|DRUID\|symbiotic blooms\|439530` |
| R0265 | reject | addition | SHAMAN | 1287665 | Rune of Lingering | support | 2026-09-25 | `addition\|support\|SHAMAN\|rune of lingering\|1287665` |
| R0266 | move | addition | PALADIN | 156322 | Eternal Flame | healing | 2026-09-25 | `addition\|support\|PALADIN\|eternal flame\|156322` |
| R0267 | reject | addition | PALADIN | 157128 | Saved by the Light | support | 2026-09-25 | `addition\|support\|PALADIN\|saved by the light\|157128` |
| R0268 | reject | addition | PRIEST | 47753 | Divine Aegis | support | 2026-09-25 | `addition\|support\|PRIEST\|divine aegis\|47753` |
| R0269 | reject | addition | PALADIN | 1287665 | Rune of Lingering | support | 2026-09-25 | `addition\|support\|PALADIN\|rune of lingering\|1287665` |
| R0270 | reject | addition | PALADIN | 1229746 | Arcanoweave Insight | support | 2026-09-25 | `addition\|support\|PALADIN\|arcanoweave insight\|1229746` |
| R0271 | move | addition | PRIEST | 1253593 | Void Shield | healing | 2026-09-25 | `addition\|support\|PRIEST\|void shield\|1253593` |
| R0272 | reject | addition | DRUID | 1287665 | Rune of Lingering | support | 2026-09-25 | `addition\|support\|DRUID\|rune of lingering\|1287665` |
| R0273 | reject | addition | PRIEST | 390677 | Inspiration | support | 2026-09-25 | `addition\|support\|PRIEST\|inspiration\|390677` |
| R0274 | reject | addition | PALADIN | 1239091 | Lesser Weapon | support | 2026-09-25 | `addition\|support\|PALADIN\|lesser weapon\|1239091` |
| R0275 | reject | addition | PRIEST | 1287665 | Rune of Lingering | support | 2026-09-25 | `addition\|support\|PRIEST\|rune of lingering\|1287665` |
| R0276 | reject | addition | MAGE | 1229746 | Arcanoweave Insight | support | 2026-09-25 | `addition\|support\|MAGE\|arcanoweave insight\|1229746` |
| R0277 | reject | addition | MONK | 1287665 | Rune of Lingering | support | 2026-09-25 | `addition\|support\|MONK\|rune of lingering\|1287665` |
| R0278 | reject | addition | DEMONHUNTER | 1229746 | Arcanoweave Insight | support | 2026-09-25 | `addition\|support\|DEMONHUNTER\|arcanoweave insight\|1229746` |
| R0279 | reject | addition | DRUID | 1229746 | Arcanoweave Insight | support | 2026-09-25 | `addition\|support\|DRUID\|arcanoweave insight\|1229746` |
| R0280 | reject | addition | DEATHKNIGHT | 1229746 | Arcanoweave Insight | support | 2026-09-25 | `addition\|support\|DEATHKNIGHT\|arcanoweave insight\|1229746` |
| R0281 | reject | addition | WARLOCK | 1229746 | Arcanoweave Insight | support | 2026-09-25 | `addition\|support\|WARLOCK\|arcanoweave insight\|1229746` |
| R0282 | reject | addition | PALADIN | 1241866 | Glistening Radiance | support | 2026-09-25 | `addition\|support\|PALADIN\|glistening radiance\|1241866` |
| R0283 | accept | addition | EVOKER | 413984 | Shifting Sands | support | 2026-09-25 | `addition\|support\|EVOKER\|shifting sands\|413984` |
| R0284 | reject | addition | DEMONHUNTER | 1287665 | Rune of Lingering | support | 2026-09-25 | `addition\|support\|DEMONHUNTER\|rune of lingering\|1287665` |
| R0285 | reject | addition | SHAMAN | 1229746 | Arcanoweave Insight | support | 2026-09-25 | `addition\|support\|SHAMAN\|arcanoweave insight\|1229746` |
| R0286 | reject | addition | PALADIN | 432502 | Sacred Weapon | support | 2026-09-25 | `addition\|support\|PALADIN\|sacred weapon\|432502` |
| R0287 | reject | addition | HUNTER | 1229746 | Arcanoweave Insight | support | 2026-09-25 | `addition\|support\|HUNTER\|arcanoweave insight\|1229746` |
| R0288 | reject | addition | PALADIN | 1239002 | Lesser Bulwark | support | 2026-09-25 | `addition\|support\|PALADIN\|lesser bulwark\|1239002` |
| R0289 | reject | addition | DRUID | 1263447 | Duskwraith's Infusion | support | 2026-09-25 | `addition\|support\|DRUID\|duskwraith's infusion\|1263447` |
| R0290 | reject | addition | PALADIN | 461499 | Overflowing Light | support | 2026-09-25 | `addition\|support\|PALADIN\|overflowing light\|461499` |
| R0291 | reject | addition | PRIEST | 1229746 | Arcanoweave Insight | support | 2026-09-25 | `addition\|support\|PRIEST\|arcanoweave insight\|1229746` |
| R0292 | reject | addition | EVOKER | 410263 | Inferno's Blessing | support | 2026-09-25 | `addition\|support\|EVOKER\|inferno's blessing\|410263` |
| R0293 | accept | addition | HUNTER | 34477 | Misdirection | support | 2026-09-25 | `addition\|support\|HUNTER\|misdirection\|34477` |
| R0294 | reject | addition | EVOKER | 1229746 | Arcanoweave Insight | support | 2026-09-25 | `addition\|support\|EVOKER\|arcanoweave insight\|1229746` |
| R0295 | reject | addition | PRIEST | 355851 | Blaze of Light | support | 2026-09-25 | `addition\|support\|PRIEST\|blaze of light\|355851` |
| R0296 | reject | addition | PALADIN | 432496 | Holy Bulwark | support | 2026-09-25 | `addition\|support\|PALADIN\|holy bulwark\|432496` |
| R0297 | reject | addition | WARRIOR | 1229746 | Arcanoweave Insight | support | 2026-09-25 | `addition\|support\|WARRIOR\|arcanoweave insight\|1229746` |
| R0298 | reject | addition | ROGUE | 1229746 | Arcanoweave Insight | support | 2026-09-25 | `addition\|support\|ROGUE\|arcanoweave insight\|1229746` |
| R0299 | reject | addition | MONK | 1229746 | Arcanoweave Insight | support | 2026-09-25 | `addition\|support\|MONK\|arcanoweave insight\|1229746` |
| R0300 | reject | addition | PALADIN | 1266300 | Fanatically Inspired | support | 2026-09-25 | `addition\|support\|PALADIN\|fanatically inspired\|1266300` |
| R0301 | reject | addition | EVOKER | 1287665 | Rune of Lingering | support | 2026-09-25 | `addition\|support\|EVOKER\|rune of lingering\|1287665` |
| R0302 | reject | addition | WARRIOR | 1287665 | Rune of Lingering | support | 2026-09-25 | `addition\|support\|WARRIOR\|rune of lingering\|1287665` |
| R0303 | reject | addition | SHAMAN | 1266300 | Fanatically Inspired | support | 2026-09-25 | `addition\|support\|SHAMAN\|fanatically inspired\|1266300` |
| R0304 | move | addition | EVOKER | 373267 | Lifebind | healing | 2026-09-25 | `addition\|support\|EVOKER\|lifebind\|373267` |
| R0305 | move | addition | DRUID | 102342 | Ironbark | defensives | 2026-09-25 | `addition\|support\|DRUID\|ironbark\|102342` |
| R0306 | reject | addition | DRUID | 1223453 | Ethereal Guard | support | 2026-09-25 | `addition\|support\|DRUID\|ethereal guard\|1223453` |
| R0307 | reject | addition | PRIEST | 372014 | Visage | support | 2026-09-25 | `addition\|support\|PRIEST\|visage\|372014` |
| R0308 | reject | addition | HUNTER | 1287665 | Rune of Lingering | support | 2026-09-25 | `addition\|support\|HUNTER\|rune of lingering\|1287665` |
| R0309 | reject | addition | DEATHKNIGHT | 1287665 | Rune of Lingering | support | 2026-09-25 | `addition\|support\|DEATHKNIGHT\|rune of lingering\|1287665` |
| R0310 | move | addition | PALADIN | 6940 | Blessing of Sacrifice | defensives | 2026-09-25 | `addition\|support\|PALADIN\|blessing of sacrifice\|6940` |
| R0311 | reject | addition | SHAMAN | 1263447 | Duskwraith's Infusion | support | 2026-09-25 | `addition\|support\|SHAMAN\|duskwraith's infusion\|1263447` |
| R0312 | move | addition | MONK | 116849 | Life Cocoon | defensives | 2026-09-25 | `addition\|support\|MONK\|life cocoon\|116849` |
| R0313 | reject | addition | PRIEST | 1307578 | Soulcoil Barrier | support | 2026-09-25 | `addition\|support\|PRIEST\|soulcoil barrier\|1307578` |
| R0314 | reject | addition | WARLOCK | 1287665 | Rune of Lingering | support | 2026-09-25 | `addition\|support\|WARLOCK\|rune of lingering\|1287665` |
| R0315 | reject | addition | PALADIN | 1263447 | Duskwraith's Infusion | support | 2026-09-25 | `addition\|support\|PALADIN\|duskwraith's infusion\|1263447` |
| R0316 | reject | addition | PRIEST | 1263447 | Duskwraith's Infusion | support | 2026-09-25 | `addition\|support\|PRIEST\|duskwraith's infusion\|1263447` |
| R0317 | accept | addition | DEATHKNIGHT | 454863 | Lesser Anti-Magic Shell | support | 2026-09-25 | `addition\|support\|DEATHKNIGHT\|lesser anti-magic shell\|454863` |
| R0318 | reject | addition | PRIEST | 1305846 | Preternatural Antivenom | support | 2026-09-25 | `addition\|support\|PRIEST\|preternatural antivenom\|1305846` |
| R0319 | reject | addition | DRUID | 1242003 | Worldsoul Cradle | support | 2026-09-25 | `addition\|support\|DRUID\|worldsoul cradle\|1242003` |
| R0320 | reject | addition | SHAMAN | 383799 | Time To Shine! | support | 2026-09-25 | `addition\|support\|SHAMAN\|time to shine!\|383799` |
| R0321 | reject | addition | DEATHKNIGHT | 1266300 | Fanatically Inspired | support | 2026-09-25 | `addition\|support\|DEATHKNIGHT\|fanatically inspired\|1266300` |
| R0322 | move | addition | EVOKER | 357170 | Time Dilation | defensives | 2026-09-25 | `addition\|support\|EVOKER\|time dilation\|357170` |
| R0323 | reject | addition | PALADIN | 387804 | Echoing Protection | support | 2026-09-25 | `addition\|support\|PALADIN\|echoing protection\|387804` |
| R0324 | accept | addition | PRIEST | 1300009 | Void Shield (Unfolding Vision) | support | 2026-09-25 | `addition\|support\|PRIEST\|void shield (unfolding vision)\|1300009` |
| R0325 | reject | addition | DRUID | 1266300 | Fanatically Inspired | support | 2026-09-25 | `addition\|support\|DRUID\|fanatically inspired\|1266300` |
| R0326 | reject | addition | PALADIN | 1289063 | Rune of Echoes | support | 2026-09-25 | `addition\|support\|PALADIN\|rune of echoes\|1289063` |
| R0327 | reject | addition | PALADIN | 1307578 | Soulcoil Barrier | support | 2026-09-25 | `addition\|support\|PALADIN\|soulcoil barrier\|1307578` |
| R0328 | reject | addition | SHAMAN | 1307578 | Soulcoil Barrier | support | 2026-09-25 | `addition\|support\|SHAMAN\|soulcoil barrier\|1307578` |
| R0329 | reject | addition | PRIEST | 1242003 | Worldsoul Cradle | support | 2026-09-25 | `addition\|support\|PRIEST\|worldsoul cradle\|1242003` |
| R0330 | move | addition | PRIEST | 33206 | Pain Suppression | defensives | 2026-09-25 | `addition\|support\|PRIEST\|pain suppression\|33206` |
| R0331 | reject | addition | DEMONHUNTER | 1266300 | Fanatically Inspired | support | 2026-09-25 | `addition\|support\|DEMONHUNTER\|fanatically inspired\|1266300` |
| R0332 | reject | addition | WARLOCK | 1266300 | Fanatically Inspired | support | 2026-09-25 | `addition\|support\|WARLOCK\|fanatically inspired\|1266300` |
| R0333 | reject | addition | DEATHKNIGHT | 434107 | Vampiric Aura | support | 2026-09-25 | `addition\|support\|DEATHKNIGHT\|vampiric aura\|434107` |
| R0334 | reject | addition | EVOKER | 403295 | Black Attunement | support | 2026-09-25 | `addition\|support\|EVOKER\|black attunement\|403295` |
| R0335 | reject | addition | MAGE | 1266300 | Fanatically Inspired | support | 2026-09-25 | `addition\|support\|MAGE\|fanatically inspired\|1266300` |
| R0336 | accept | addition | ROGUE | 57934 | Tricks of the Trade | support | 2026-09-25 | `addition\|support\|ROGUE\|tricks of the trade\|57934` |
| R0337 | reject | addition | DRUID | 1307578 | Soulcoil Barrier | support | 2026-09-25 | `addition\|support\|DRUID\|soulcoil barrier\|1307578` |
| R0338 | reject | addition | MONK | 1266300 | Fanatically Inspired | support | 2026-09-25 | `addition\|support\|MONK\|fanatically inspired\|1266300` |
| R0339 | reject | addition | MONK | 1307578 | Soulcoil Barrier | support | 2026-09-25 | `addition\|support\|MONK\|soulcoil barrier\|1307578` |
| R0340 | reject | addition | HUNTER | 372014 | Visage | support | 2026-09-25 | `addition\|support\|HUNTER\|visage\|372014` |
| R0341 | reject | addition | WARRIOR | 1266300 | Fanatically Inspired | support | 2026-09-25 | `addition\|support\|WARRIOR\|fanatically inspired\|1266300` |
| R0342 | reject | addition | SHAMAN | 1289063 | Rune of Echoes | support | 2026-09-25 | `addition\|support\|SHAMAN\|rune of echoes\|1289063` |
| R0343 | reject | addition | DRUID | 1255367 | Tangle of Vibrant Vines | support | 2026-09-25 | `addition\|support\|DRUID\|tangle of vibrant vines\|1255367` |
| R0344 | accept | addition | DRUID | 474750 | Symbiotic Relationship | support | 2026-09-25 | `addition\|support\|DRUID\|symbiotic relationship\|474750` |
| R0345 | reject | addition | DRUID | 383799 | Time To Shine! | support | 2026-09-25 | `addition\|support\|DRUID\|time to shine!\|383799` |
| R0346 | accept | addition | ROGUE | 115834 | Shroud of Concealment | support | 2026-09-25 | `addition\|support\|ROGUE\|shroud of concealment\|115834` |
| R0347 | accept | addition | ROGUE | 1224098 | Tricks of the Trade | support | 2026-09-25 | `addition\|support\|ROGUE\|tricks of the trade\|1224098` |
| R0348 | reject | addition | HUNTER | 1266300 | Fanatically Inspired | support | 2026-09-25 | `addition\|support\|HUNTER\|fanatically inspired\|1266300` |
| R0349 | reject | addition | PRIEST | 1259988 | Consecrated Chalice | support | 2026-09-25 | `addition\|support\|PRIEST\|consecrated chalice\|1259988` |
| R0350 | reject | addition | WARLOCK | 1289063 | Rune of Echoes | support | 2026-09-25 | `addition\|support\|WARLOCK\|rune of echoes\|1289063` |
| R0351 | accept | addition | EVOKER | 360827 | Blistering Scales | support | 2026-09-25 | `addition\|support\|EVOKER\|blistering scales\|360827` |
| R0352 | reject | addition | PALADIN | 383799 | Time To Shine! | support | 2026-09-25 | `addition\|support\|PALADIN\|time to shine!\|383799` |
| R0353 | move | addition | PRIEST | 73325 | Leap of Faith | movement | 2026-09-25 | `addition\|support\|PRIEST\|leap of faith\|73325` |
| R0354 | accept | addition | EVOKER | 375253 | Time Spiral | support | 2026-09-25 | `addition\|support\|EVOKER\|time spiral\|375253` |
| R0355 | accept | addition | EVOKER | 375230 | Time Spiral | support | 2026-09-25 | `addition\|support\|EVOKER\|time spiral\|375230` |
| R0356 | accept | addition | EVOKER | 375226 | Time Spiral | support | 2026-09-25 | `addition\|support\|EVOKER\|time spiral\|375226` |
| R0357 | accept | addition | EVOKER | 375229 | Time Spiral | support | 2026-09-25 | `addition\|support\|EVOKER\|time spiral\|375229` |
| R0358 | reject | addition | SHAMAN | 1254624 | Radiant Blessing | support | 2026-09-25 | `addition\|support\|SHAMAN\|radiant blessing\|1254624` |
| R0359 | accept | addition | DEATHKNIGHT | 474754 | Symbiotic Relationship | support | 2026-09-25 | `addition\|support\|DEATHKNIGHT\|symbiotic relationship\|474754` |
| R0360 | reject | addition | SHAMAN | 386578 | Coached | support | 2026-09-25 | `addition\|support\|SHAMAN\|coached\|386578` |
| R0361 | accept | addition | EVOKER | 375257 | Time Spiral | support | 2026-09-25 | `addition\|support\|EVOKER\|time spiral\|375257` |
| R0362 | reject | addition | DEATHKNIGHT | 434493 | Newly Turned | support | 2026-09-25 | `addition\|support\|DEATHKNIGHT\|newly turned\|434493` |
| R0363 | accept | addition | EVOKER | 406789 | Spatial Paradox | support | 2026-09-25 | `addition\|support\|EVOKER\|spatial paradox\|406789` |
| R0364 | accept | addition | EVOKER | 375256 | Time Spiral | support | 2026-09-25 | `addition\|support\|EVOKER\|time spiral\|375256` |
| R0365 | reject | addition | PRIEST | 1300008 | Power Word: Shield (Unfolding Vision) | support | 2026-09-25 | `addition\|support\|PRIEST\|power word: shield (unfolding vision)\|1300008` |
| R0366 | reject | addition | WARRIOR | 184362 | Enrage | movement | 2026-09-25 | `addition\|movement\|WARRIOR\|enrage\|184362` |
| R0367 | accept | addition | MONK | 443569 | Chi-Ji's Swiftness | movement | 2026-09-25 | `addition\|movement\|MONK\|chi-ji's swiftness\|443569` |
| R0368 | reject | addition | WARRIOR | 262232 | War Machine | movement | 2026-09-25 | `addition\|movement\|WARRIOR\|war machine\|262232` |
| R0369 | accept | addition | DEATHKNIGHT | 48265 | Death's Advance | movement | 2026-09-25 | `addition\|movement\|DEATHKNIGHT\|death's advance\|48265` |
| R0370 | accept | addition | DRUID | 400126 | Forestwalk | movement | 2026-09-25 | `addition\|movement\|DRUID\|forestwalk\|400126` |
| R0371 | reject | addition | HUNTER | 1279347 | Quick Draw | movement | 2026-09-25 | `addition\|movement\|HUNTER\|quick draw\|1279347` |
| R0372 | reject | addition | PALADIN | 431381 | Dawnlight | movement | 2026-09-25 | `addition\|movement\|PALADIN\|dawnlight\|431381` |
| R0373 | reject | addition | DEMONHUNTER | 389847 | Felfire Haste | movement | 2026-09-25 | `addition\|movement\|DEMONHUNTER\|felfire haste\|389847` |
| R0374 | reject | addition | PALADIN | 1277482 | Voidlust | movement | 2026-09-25 | `addition\|movement\|PALADIN\|voidlust\|1277482` |
| R0375 | reject | addition | DRUID | 378991 | Lycara's Teachings | movement | 2026-09-25 | `addition\|movement\|DRUID\|lycara's teachings\|378991` |
| R0376 | accept | addition | SHAMAN | 454025 | Electroshock | movement | 2026-09-25 | `addition\|movement\|SHAMAN\|electroshock\|454025` |
| R0377 | reject | addition | DRUID | 1277482 | Voidlust | movement | 2026-09-25 | `addition\|movement\|DRUID\|voidlust\|1277482` |
| R0378 | accept | addition | DEATHKNIGHT | 444347 | Death Charge | movement | 2026-09-25 | `addition\|movement\|DEATHKNIGHT\|death charge\|444347` |
| R0379 | accept | addition | WARRIOR | 202164 | Bounding Stride | movement | 2026-09-25 | `addition\|movement\|WARRIOR\|bounding stride\|202164` |
| R0380 | accept | addition | DEATHKNIGHT | 434029 | Vampiric Speed | movement | 2026-09-25 | `addition\|movement\|DEATHKNIGHT\|vampiric speed\|434029` |
| R0381 | reject | addition | MAGE | 1277482 | Voidlust | movement | 2026-09-25 | `addition\|movement\|MAGE\|voidlust\|1277482` |
| R0382 | accept | addition | MONK | 450552 | Jade Walk | movement | 2026-09-25 | `addition\|movement\|MONK\|jade walk\|450552` |
| R0383 | accept | addition | WARRIOR | 446044 | Relentless Pursuit | movement | 2026-09-25 | `addition\|movement\|WARRIOR\|relentless pursuit\|446044` |
| R0384 | accept | addition | DRUID | 165961 | Travel Form | movement | 2026-09-25 | `addition\|movement\|DRUID\|travel form\|165961` |
| R0385 | reject | addition | SHAMAN | 1277482 | Voidlust | movement | 2026-09-25 | `addition\|movement\|SHAMAN\|voidlust\|1277482` |
| R0386 | reject | addition | DEMONHUNTER | 1277482 | Voidlust | movement | 2026-09-25 | `addition\|movement\|DEMONHUNTER\|voidlust\|1277482` |
| R0387 | reject | addition | WARLOCK | 1277482 | Voidlust | movement | 2026-09-25 | `addition\|movement\|WARLOCK\|voidlust\|1277482` |
| R0388 | reject | addition | PALADIN | 20271 | Judgment | movement | 2026-09-25 | `addition\|movement\|PALADIN\|judgment\|20271` |
| R0389 | accept | addition | DEATHKNIGHT | 212552 | Wraith Walk | movement | 2026-09-25 | `addition\|movement\|DEATHKNIGHT\|wraith walk\|212552` |
| R0390 | accept | addition | MONK | 119085 | Chi Torpedo | movement | 2026-09-25 | `addition\|movement\|MONK\|chi torpedo\|119085` |
| R0391 | reject | addition | EVOKER | 433874 | Deep Breath | movement | 2026-09-25 | `addition\|movement\|EVOKER\|deep breath\|433874` |
| R0392 | reject | addition | MAGE | 1242775 | Farstrider's Step | movement | 2026-09-25 | `addition\|movement\|MAGE\|farstrider's step\|1242775` |
| R0393 | reject | addition | DEATHKNIGHT | 1277482 | Voidlust | movement | 2026-09-25 | `addition\|movement\|DEATHKNIGHT\|voidlust\|1277482` |
| R0394 | accept | addition | ROGUE | 36554 | Shadowstep | movement | 2026-09-25 | `addition\|movement\|ROGUE\|shadowstep\|36554` |
| R0395 | reject | addition | HUNTER | 1242775 | Farstrider's Step | movement | 2026-09-25 | `addition\|movement\|HUNTER\|farstrider's step\|1242775` |
| R0396 | reject | addition | DEMONHUNTER | 1242775 | Farstrider's Step | movement | 2026-09-25 | `addition\|movement\|DEMONHUNTER\|farstrider's step\|1242775` |
| R0397 | reject | addition | DRUID | 1242775 | Farstrider's Step | movement | 2026-09-25 | `addition\|movement\|DRUID\|farstrider's step\|1242775` |
| R0398 | reject | addition | PRIEST | 1277482 | Voidlust | movement | 2026-09-25 | `addition\|movement\|PRIEST\|voidlust\|1277482` |
| R0399 | reject | addition | HUNTER | 1277482 | Voidlust | movement | 2026-09-25 | `addition\|movement\|HUNTER\|voidlust\|1277482` |
| R0400 | reject | addition | EVOKER | 1277482 | Voidlust | movement | 2026-09-25 | `addition\|movement\|EVOKER\|voidlust\|1277482` |
| R0401 | reject | addition | PALADIN | 24275 | Hammer of Wrath | movement | 2026-09-25 | `addition\|movement\|PALADIN\|hammer of wrath\|24275` |
| R0402 | accept | addition | SHAMAN | 58875 | Spirit Walk | movement | 2026-09-25 | `addition\|movement\|SHAMAN\|spirit walk\|58875` |
| R0403 | reject | addition | WARLOCK | 1242775 | Farstrider's Step | movement | 2026-09-25 | `addition\|movement\|WARLOCK\|farstrider's step\|1242775` |
| R0404 | reject | addition | MONK | 1263345 | Swift as a Coursing River | movement | 2026-09-25 | `addition\|movement\|MONK\|swift as a coursing river\|1263345` |
| R0405 | accept | addition | EVOKER | 442204 | Breath of Eons | movement | 2026-09-25 | `addition\|movement\|EVOKER\|breath of eons\|442204` |
| R0406 | reject | addition | MONK | 1266743 | Reinvigoration | movement | 2026-09-25 | `addition\|movement\|MONK\|reinvigoration\|1266743` |
| R0407 | reject | addition | WARRIOR | 1277482 | Voidlust | movement | 2026-09-25 | `addition\|movement\|WARRIOR\|voidlust\|1277482` |
| R0408 | accept | addition | DRUID | 252216 | Tiger Dash | movement | 2026-09-25 | `addition\|movement\|DRUID\|tiger dash\|252216` |
| R0409 | reject | addition | MONK | 1272850 | Initiator's Edge | movement | 2026-09-25 | `addition\|movement\|MONK\|initiator's edge\|1272850` |
| R0410 | reject | addition | MONK | 1277482 | Voidlust | movement | 2026-09-25 | `addition\|movement\|MONK\|voidlust\|1277482` |
| R0411 | reject | addition | PALADIN | 431752 | Will of the Dawn | movement | 2026-09-25 | `addition\|movement\|PALADIN\|will of the dawn\|431752` |
| R0412 | reject | addition | SHAMAN | 1242775 | Farstrider's Step | movement | 2026-09-25 | `addition\|movement\|SHAMAN\|farstrider's step\|1242775` |
| R0413 | reject | addition | PALADIN | 1242775 | Farstrider's Step | movement | 2026-09-25 | `addition\|movement\|PALADIN\|farstrider's step\|1242775` |
| R0414 | accept | addition | SHAMAN | 468226 | Lightning Conduit | movement | 2026-09-25 | `addition\|movement\|SHAMAN\|lightning conduit\|468226` |
| R0415 | reject | addition | DEATHKNIGHT | 1242775 | Farstrider's Step | movement | 2026-09-25 | `addition\|movement\|DEATHKNIGHT\|farstrider's step\|1242775` |
| R0416 | reject | addition | WARRIOR | 1242775 | Farstrider's Step | movement | 2026-09-25 | `addition\|movement\|WARRIOR\|farstrider's step\|1242775` |
| R0417 | reject | addition | DEATHKNIGHT | 54861 | Nitro Boosts | movement | 2026-09-25 | `addition\|movement\|DEATHKNIGHT\|nitro boosts\|54861` |
| R0418 | reject | addition | ROGUE | 455144 | Acrobatic Strikes | movement | 2026-09-25 | `addition\|movement\|ROGUE\|acrobatic strikes\|455144` |
| R0419 | accept | addition | WARRIOR | 1244157 | Piercing Howl | movement | 2026-09-25 | `addition\|movement\|WARRIOR\|piercing howl\|1244157` |
| R0420 | accept | addition | PALADIN | 394454 | Echoing Freedom | movement | 2026-09-25 | `addition\|movement\|PALADIN\|echoing freedom\|394454` |
| R0421 | reject | addition | ROGUE | 1277482 | Voidlust | movement | 2026-09-25 | `addition\|movement\|ROGUE\|voidlust\|1277482` |
| R0422 | reject | addition | PRIEST | 1242775 | Farstrider's Step | movement | 2026-09-25 | `addition\|movement\|PRIEST\|farstrider's step\|1242775` |
| R0423 | reject | addition | MONK | 1242775 | Farstrider's Step | movement | 2026-09-25 | `addition\|movement\|MONK\|farstrider's step\|1242775` |
| R0424 | reject | addition | ROGUE | 1242775 | Farstrider's Step | movement | 2026-09-25 | `addition\|movement\|ROGUE\|farstrider's step\|1242775` |
| R0425 | reject | addition | EVOKER | 390148 | Flow State | movement | 2026-09-25 | `addition\|movement\|EVOKER\|flow state\|390148` |
| R0426 | reject | addition | EVOKER | 1242775 | Farstrider's Step | movement | 2026-09-25 | `addition\|movement\|EVOKER\|farstrider's step\|1242775` |
| R0427 | accept | addition | WARLOCK | 387633 | Soulburn: Demonic Circle | movement | 2026-09-25 | `addition\|movement\|WARLOCK\|soulburn: demonic circle\|387633` |
| R0428 | reject | addition | WARLOCK | 54861 | Nitro Boosts | movement | 2026-09-25 | `addition\|movement\|WARLOCK\|nitro boosts\|54861` |
| R0429 | reject | addition | EVOKER | 432061 | Motes of Acceleration | movement | 2026-09-25 | `addition\|movement\|EVOKER\|motes of acceleration\|432061` |
| R0430 | reject | addition | EVOKER | 370889 | Twin Guardian | movement | 2026-09-25 | `addition\|movement\|EVOKER\|twin guardian\|370889` |
| R0431 | accept | addition | DRUID | 210053 | Mount Form | movement | 2026-09-25 | `addition\|movement\|DRUID\|mount form\|210053` |
| R0432 | reject | addition | ALL | 1241715 | Might of the Void | consumables | 2026-09-25 | `addition\|consumables\|ALL\|might of the void\|1241715` |
| R0433 | reject | addition | ALL | 1287772 | Rune of Critical Power | consumables | 2026-09-25 | `addition\|consumables\|ALL\|rune of critical power\|1287772` |
| R0434 | reject | addition | ALL | 1287774 | Rune of Burning Haste | consumables | 2026-09-25 | `addition\|consumables\|ALL\|rune of burning haste\|1287774` |
| R0435 | reject | addition | ALL | 1287771 | Rune of Masterful Cunning | consumables | 2026-09-25 | `addition\|consumables\|ALL\|rune of masterful cunning\|1287771` |
| R0436 | reject | addition | ALL | 1252488 | Masterful Hunt | consumables | 2026-09-25 | `addition\|consumables\|ALL\|masterful hunt\|1252488` |
| R0437 | reject | addition | ALL | 1263318 | The Wind Awoken | consumables | 2026-09-25 | `addition\|consumables\|ALL\|the wind awoken\|1263318` |
| R0438 | reject | addition | ALL | 1266686 | Alnsight | consumables | 2026-09-25 | `addition\|consumables\|ALL\|alnsight\|1266686` |
| R0439 | reject | addition | ALL | 1297663 | Halazzi's Rite | consumables | 2026-09-25 | `addition\|consumables\|ALL\|halazzi's rite\|1297663` |
| R0440 | reject | addition | ALL | 1266687 | Alnscorned Essence | consumables | 2026-09-25 | `addition\|consumables\|ALL\|alnscorned essence\|1266687` |
| R0441 | reject | addition | ALL | 1266299 | Fanatical Inspiration | consumables | 2026-09-25 | `addition\|consumables\|ALL\|fanatical inspiration\|1266299` |
| R0442 | reject | addition | ALL | 1241762 | Frenzied Focus | consumables | 2026-09-25 | `addition\|consumables\|ALL\|frenzied focus\|1241762` |
| R0443 | reject | addition | ALL | 1241759 | Genius Insight | consumables | 2026-09-25 | `addition\|consumables\|ALL\|genius insight\|1241759` |
| R0444 | reject | addition | ALL | 1252486 | Hasty Hunt | consumables | 2026-09-25 | `addition\|consumables\|ALL\|hasty hunt\|1252486` |
| R0445 | reject | addition | ALL | 1255504 | Solarflare Prism | consumables | 2026-09-25 | `addition\|consumables\|ALL\|solarflare prism\|1255504` |
| R0446 | reject | addition | ALL | 1252489 | Versatile Hunt | consumables | 2026-09-25 | `addition\|consumables\|ALL\|versatile hunt\|1252489` |
| R0447 | reject | addition | ALL | 1252487 | Focused Hunt | consumables | 2026-09-25 | `addition\|consumables\|ALL\|focused hunt\|1252487` |
| R0448 | reject | addition | ALL | 387028 | Burning Embers | consumables | 2026-09-25 | `addition\|consumables\|ALL\|burning embers\|387028` |
| R0449 | reject | addition | ALL | 1297664 | Akil'zon's Rite | consumables | 2026-09-25 | `addition\|consumables\|ALL\|akil'zon's rite\|1297664` |
| R0450 | reject | addition | ALL | 1295057 | Tidal Insight | consumables | 2026-09-25 | `addition\|consumables\|ALL\|tidal insight\|1295057` |
| R0451 | reject | addition | ALL | 1259230 | Seized Power | consumables | 2026-09-25 | `addition\|consumables\|ALL\|seized power\|1259230` |
| R0452 | reject | addition | ALL | 1285161 | Protective Toadstools | consumables | 2026-09-25 | `addition\|consumables\|ALL\|protective toadstools\|1285161` |
| R0453 | reject | addition | ALL | 1247577 | Akil'zon's Clarity | consumables | 2026-09-25 | `addition\|consumables\|ALL\|akil'zon's clarity\|1247577` |
| R0454 | reject | addition | ALL | 1295898 | Versatile Ritual | consumables | 2026-09-25 | `addition\|consumables\|ALL\|versatile ritual\|1295898` |
| R0455 | reject | addition | ALL | 1254577 | Refueling Orb | consumables | 2026-09-25 | `addition\|consumables\|ALL\|refueling orb\|1254577` |
| R0456 | reject | addition | ALL | 1295582 | Focus of Ula'tek | consumables | 2026-09-25 | `addition\|consumables\|ALL\|focus of ula'tek\|1295582` |
| R0457 | reject | addition | ALL | 281744 | Restlessness | consumables | 2026-09-25 | `addition\|consumables\|ALL\|restlessness\|281744` |
| R0458 | reject | addition | ALL | 1295900 | Hasty Ritual | consumables | 2026-09-25 | `addition\|consumables\|ALL\|hasty ritual\|1295900` |
| R0459 | reject | addition | ALL | 1295901 | Masterful Ritual | consumables | 2026-09-25 | `addition\|consumables\|ALL\|masterful ritual\|1295901` |
| R0460 | reject | addition | ALL | 1241761 | Precision of the Dragonhawk | consumables | 2026-09-25 | `addition\|consumables\|ALL\|precision of the dragonhawk\|1241761` |
| R0461 | reject | addition | ALL | 1295899 | Critical Ritual | consumables | 2026-09-25 | `addition\|consumables\|ALL\|critical ritual\|1295899` |
| R0462 | reject | addition | ALL | 1296714 | Faith in Ula'tek | consumables | 2026-09-25 | `addition\|consumables\|ALL\|faith in ula'tek\|1296714` |
| R0463 | reject | addition | ALL | 1287770 | Rune of the Versatile Warrior | consumables | 2026-09-25 | `addition\|consumables\|ALL\|rune of the versatile warrior\|1287770` |
| R0464 | reject | addition | ALL | 1258223 | Nalorakk's Rage | consumables | 2026-09-25 | `addition\|consumables\|ALL\|nalorakk's rage\|1258223` |
| R0465 | reject | addition | ALL | 1317581 | Venomcursed Ascendance | consumables | 2026-09-25 | `addition\|consumables\|ALL\|venomcursed ascendance\|1317581` |
| R0466 | reject | addition | ALL | 1297655 | Jan'alai's Rite | consumables | 2026-09-25 | `addition\|consumables\|ALL\|jan'alai's rite\|1297655` |
| R0467 | reject | addition | ALL | 1263768 | Light's Blessing | consumables | 2026-09-25 | `addition\|consumables\|ALL\|light's blessing\|1263768` |
| R0468 | reject | addition | ALL | 1258534 | Void Suffusion | consumables | 2026-09-25 | `addition\|consumables\|ALL\|void suffusion\|1258534` |
| R0469 | reject | addition | ALL | 1250533 | Freightrunner's Flask | consumables | 2026-09-25 | `addition\|consumables\|ALL\|freightrunner's flask\|1250533` |
| R0470 | reject | addition | ALL | 1236616 | Light's Potential | consumables | 2026-09-25 | `addition\|consumables\|ALL\|light's potential\|1236616` |
| R0471 | reject | addition | ALL | 1252524 | Blessing of the Capybara | consumables | 2026-09-25 | `addition\|consumables\|ALL\|blessing of the capybara\|1252524` |
| R0472 | reject | addition | ALL | 1264404 | Cosmic Siphon | consumables | 2026-09-25 | `addition\|consumables\|ALL\|cosmic siphon\|1264404` |
| R0473 | reject | addition | ALL | 1250508 | Emberwing Heatwave | consumables | 2026-09-25 | `addition\|consumables\|ALL\|emberwing heatwave\|1250508` |
| R0474 | reject | addition | ALL | 1307927 | Venomcursed Haste | consumables | 2026-09-25 | `addition\|consumables\|ALL\|venomcursed haste\|1307927` |
| R0475 | reject | addition | ALL | 383781 | Algeth'ar Puzzle | consumables | 2026-09-25 | `addition\|consumables\|ALL\|algeth'ar puzzle\|383781` |
| R0476 | reject | addition | ALL | 1293316 | Empowering Venom | consumables | 2026-09-25 | `addition\|consumables\|ALL\|empowering venom\|1293316` |
| R0477 | reject | addition | ALL | 1259317 | Riftwalker's Temptation | consumables | 2026-09-25 | `addition\|consumables\|ALL\|riftwalker's temptation\|1259317` |
| R0478 | reject | addition | ALL | 1262753 | Heart of Ancient Hunger | consumables | 2026-09-25 | `addition\|consumables\|ALL\|heart of ancient hunger\|1262753` |
| R0479 | reject | addition | ALL | 1307910 | Venomcursed Critical Strike | consumables | 2026-09-25 | `addition\|consumables\|ALL\|venomcursed critical strike\|1307910` |
| R0480 | reject | addition | ALL | 1266403 | Sacred Duty | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sacred duty\|1266403` |
| R0481 | reject | addition | ALL | 1255226 | Withered Saptor's Paw | consumables | 2026-09-25 | `addition\|consumables\|ALL\|withered saptor's paw\|1255226` |
| R0482 | reject | addition | ALL | 1272482 | Cosmic Bell | consumables | 2026-09-25 | `addition\|consumables\|ALL\|cosmic bell\|1272482` |
| R0483 | reject | addition | ALL | 1241530 | Adroit Intuition | consumables | 2026-09-25 | `addition\|consumables\|ALL\|adroit intuition\|1241530` |
| R0484 | reject | addition | ALL | 1238467 | Thorn Bloom | consumables | 2026-09-25 | `addition\|consumables\|ALL\|thorn bloom\|1238467` |
| R0485 | reject | addition | ALL | 1308013 | 50-Lb Midnight Salmon | consumables | 2026-09-25 | `addition\|consumables\|ALL\|50-lb midnight salmon\|1308013` |
| R0486 | reject | addition | ALL | 1308012 | Slick and Slimy Gralstone | consumables | 2026-09-25 | `addition\|consumables\|ALL\|slick and slimy gralstone\|1308012` |
| R0487 | reject | addition | ALL | 1306870 | Tattered Tortollan Scroll | consumables | 2026-09-25 | `addition\|consumables\|ALL\|tattered tortollan scroll\|1306870` |
| R0488 | reject | addition | ALL | 1292299 | Seriously Sharp Seashell | consumables | 2026-09-25 | `addition\|consumables\|ALL\|seriously sharp seashell\|1292299` |
| R0489 | reject | addition | ALL | 1308014 | Rotting Voidfin | consumables | 2026-09-25 | `addition\|consumables\|ALL\|rotting voidfin\|1308014` |
| R0490 | reject | addition | ALL | 1292300 | Brittle Torga Totem | consumables | 2026-09-25 | `addition\|consumables\|ALL\|brittle torga totem\|1292300` |
| R0491 | reject | addition | ALL | 1287665 | Rune of Lingering | consumables | 2026-09-25 | `addition\|consumables\|ALL\|rune of lingering\|1287665` |
| R0492 | reject | addition | ALL | 1276677 | Fiber of Living Agony | consumables | 2026-09-25 | `addition\|consumables\|ALL\|fiber of living agony\|1276677` |
| R0493 | reject | addition | ALL | 1265566 | A Restless Soul | consumables | 2026-09-25 | `addition\|consumables\|ALL\|a restless soul\|1265566` |
| R0494 | reject | addition | ALL | 1260615 | Radiant Plume | consumables | 2026-09-25 | `addition\|consumables\|ALL\|radiant plume\|1260615` |
| R0495 | reject | addition | ALL | 1260459 | Nullsight | consumables | 2026-09-25 | `addition\|consumables\|ALL\|nullsight\|1260459` |
| R0496 | reject | addition | ALL | 1307922 | Venomcursed Mastery | consumables | 2026-09-25 | `addition\|consumables\|ALL\|venomcursed mastery\|1307922` |
| R0497 | reject | addition | ALL | 1236994 | Potion of Recklessness | consumables | 2026-09-25 | `addition\|consumables\|ALL\|potion of recklessness\|1236994` |
| R0498 | reject | addition | ALL | 404464 | Flight Style: Skyriding | consumables | 2026-09-25 | `addition\|consumables\|ALL\|flight style: skyriding\|404464` |
| R0499 | reject | addition | ALL | 1244617 | Void Glass | consumables | 2026-09-25 | `addition\|consumables\|ALL\|void glass\|1244617` |
| R0500 | reject | addition | ALL | 1296884 | Rush of Fangs | consumables | 2026-09-25 | `addition\|consumables\|ALL\|rush of fangs\|1296884` |
| R0501 | reject | addition | DEATHKNIGHT | 460605 | Blood Beast | consumables | 2026-09-25 | `addition\|consumables\|DEATHKNIGHT\|blood beast\|460605` |
| R0502 | reject | addition | ALL | 1284698 | Sporelord's Mycelium | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sporelord's mycelium\|1284698` |
| R0503 | reject | addition | ALL | 1239640 | Astral Antenna | consumables | 2026-09-25 | `addition\|consumables\|ALL\|astral antenna\|1239640` |
| R0504 | reject | addition | ALL | 292463 | Embrace of Pa'ku | consumables | 2026-09-25 | `addition\|consumables\|ALL\|embrace of pa'ku\|292463` |
| R0505 | reject | addition | ALL | 1297665 | Nalorakk's Rite | consumables | 2026-09-25 | `addition\|consumables\|ALL\|nalorakk's rite\|1297665` |
| R0506 | reject | addition | ALL | 1254331 | Echoing Roar | consumables | 2026-09-25 | `addition\|consumables\|ALL\|echoing roar\|1254331` |
| R0507 | reject | addition | ALL | 1254180 | Xathuux's Last Roar | consumables | 2026-09-25 | `addition\|consumables\|ALL\|xathuux's last roar\|1254180` |
| R0508 | reject | addition | ALL | 1239641 | Astral Antenna | consumables | 2026-09-25 | `addition\|consumables\|ALL\|astral antenna\|1239641` |
| R0509 | reject | addition | ALL | 452226 | Spiderling | consumables | 2026-09-25 | `addition\|consumables\|ALL\|spiderling\|452226` |
| R0510 | reject | addition | ALL | 1259228 | Gift of Light | consumables | 2026-09-25 | `addition\|consumables\|ALL\|gift of light\|1259228` |
| R0511 | reject | addition | ALL | 458525 | Ascension | consumables | 2026-09-25 | `addition\|consumables\|ALL\|ascension\|458525` |
| R0512 | reject | addition | ALL | 458502 | Ascension | consumables | 2026-09-25 | `addition\|consumables\|ALL\|ascension\|458502` |
| R0513 | reject | addition | ALL | 1289063 | Rune of Echoes | consumables | 2026-09-25 | `addition\|consumables\|ALL\|rune of echoes\|1289063` |
| R0514 | reject | addition | ALL | 345230 | Gladiator's Insignia | consumables | 2026-09-25 | `addition\|consumables\|ALL\|gladiator's insignia\|345230` |
| R0515 | reject | addition | ALL | 383813 | Sleepy Ruby Warmth | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sleepy ruby warmth\|383813` |
| R0516 | reject | addition | ALL | 1259633 | Charge! | consumables | 2026-09-25 | `addition\|consumables\|ALL\|charge!\|1259633` |
| R0517 | reject | addition | ALL | 1262496 | Light Company Guidon | consumables | 2026-09-25 | `addition\|consumables\|ALL\|light company guidon\|1262496` |
| R0518 | reject | addition | ALL | 1305360 | Soul Fang Alacrity | consumables | 2026-09-25 | `addition\|consumables\|ALL\|soul fang alacrity\|1305360` |
| R0519 | reject | addition | ALL | 458524 | Ascendance | consumables | 2026-09-25 | `addition\|consumables\|ALL\|ascendance\|458524` |
| R0520 | reject | addition | ALL | 1250557 | Void Execution Mandate | consumables | 2026-09-25 | `addition\|consumables\|ALL\|void execution mandate\|1250557` |
| R0521 | reject | addition | ALL | 458503 | Ascendance | consumables | 2026-09-25 | `addition\|consumables\|ALL\|ascendance\|458503` |
| R0522 | reject | addition | ALL | 1263357 | Impending Execution | consumables | 2026-09-25 | `addition\|consumables\|ALL\|impending execution\|1263357` |
| R0523 | reject | addition | ALL | 457666 | Dawnthread Lining | consumables | 2026-09-25 | `addition\|consumables\|ALL\|dawnthread lining\|457666` |
| R0524 | reject | addition | ALL | 1214848 | Winds of Mysterious Fortune | consumables | 2026-09-25 | `addition\|consumables\|ALL\|winds of mysterious fortune\|1214848` |
| R0525 | reject | addition | ALL | 1230366 | Radiant Acumen | consumables | 2026-09-25 | `addition\|consumables\|ALL\|radiant acumen\|1230366` |
| R0526 | reject | addition | ALL | 1257183 | Nalorakk's Call to War | consumables | 2026-09-25 | `addition\|consumables\|ALL\|nalorakk's call to war\|1257183` |
| R0527 | reject | addition | ALL | 448730 | Authority of Radiant Power | consumables | 2026-09-25 | `addition\|consumables\|ALL\|authority of radiant power\|448730` |
| R0528 | reject | addition | ALL | 186403 | Sign of Battle | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sign of battle\|186403` |
| R0529 | reject | addition | ALL | 1258887 | Amirdrassil's Swiftness | consumables | 2026-09-25 | `addition\|consumables\|ALL\|amirdrassil's swiftness\|1258887` |
| R0530 | reject | addition | ALL | 1258890 | Shaladrassil's Strength | consumables | 2026-09-25 | `addition\|consumables\|ALL\|shaladrassil's strength\|1258890` |
| R0531 | reject | addition | ALL | 1268058 | Deepening Temptation | consumables | 2026-09-25 | `addition\|consumables\|ALL\|deepening temptation\|1268058` |
| R0532 | reject | addition | ALL | 1258885 | Teldrassil's Tenacity | consumables | 2026-09-25 | `addition\|consumables\|ALL\|teldrassil's tenacity\|1258885` |
| R0533 | reject | addition | ALL | 1258886 | Nordrassil's Sagacity | consumables | 2026-09-25 | `addition\|consumables\|ALL\|nordrassil's sagacity\|1258886` |
| R0534 | reject | addition | ALL | 1235111 | Flask of the Shattered Sun | consumables | 2026-09-25 | `addition\|consumables\|ALL\|flask of the shattered sun\|1235111` |
| R0535 | reject | addition | ALL | 1236118 | Cauterizing Bolts | consumables | 2026-09-25 | `addition\|consumables\|ALL\|cauterizing bolts\|1236118` |
| R0536 | reject | addition | ALL | 1272942 | Telluric Leyblossom | consumables | 2026-09-25 | `addition\|consumables\|ALL\|telluric leyblossom\|1272942` |
| R0537 | reject | addition | ALL | 1247579 | Jan'alai's Warmth | consumables | 2026-09-25 | `addition\|consumables\|ALL\|jan'alai's warmth\|1247579` |
| R0538 | reject | addition | ALL | 1218713 | Explosive Adrenaline | consumables | 2026-09-25 | `addition\|consumables\|ALL\|explosive adrenaline\|1218713` |
| R0539 | reject | addition | ALL | 1218715 | Maybe Stop Blowing Up | consumables | 2026-09-25 | `addition\|consumables\|ALL\|maybe stop blowing up\|1218715` |
| R0540 | reject | addition | ALL | 1265808 | Umbral Plume | consumables | 2026-09-25 | `addition\|consumables\|ALL\|umbral plume\|1265808` |
| R0541 | reject | addition | ALL | 449275 | Nascent Empowerment | consumables | 2026-09-25 | `addition\|consumables\|ALL\|nascent empowerment\|449275` |
| R0542 | reject | addition | ALL | 1239221 | Diamantine Voidcore | consumables | 2026-09-25 | `addition\|consumables\|ALL\|diamantine voidcore\|1239221` |
| R0543 | reject | addition | ALL | 1295735 | Battle Fervor | consumables | 2026-09-25 | `addition\|consumables\|ALL\|battle fervor\|1295735` |
| R0544 | reject | addition | ALL | 1256697 | Find Lumber | consumables | 2026-09-25 | `addition\|consumables\|ALL\|find lumber\|1256697` |
| R0545 | reject | addition | ALL | 1305376 | Devoured Strength | consumables | 2026-09-25 | `addition\|consumables\|ALL\|devoured strength\|1305376` |
| R0546 | reject | addition | ALL | 1297761 | Voracious Heart of Ula'tek | consumables | 2026-09-25 | `addition\|consumables\|ALL\|voracious heart of ula'tek\|1297761` |
| R0547 | reject | addition | ALL | 1235108 | Flask of the Magisters | consumables | 2026-09-25 | `addition\|consumables\|ALL\|flask of the magisters\|1235108` |
| R0548 | reject | addition | ALL | 1260316 | Mark of Frost | consumables | 2026-09-25 | `addition\|consumables\|ALL\|mark of frost\|1260316` |
| R0549 | reject | addition | ALL | 2383 | Find Herbs | consumables | 2026-09-25 | `addition\|consumables\|ALL\|find herbs\|2383` |
| R0550 | reject | addition | ALL | 225787 | Sign of the Warrior | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sign of the warrior\|225787` |
| R0551 | reject | addition | ALL | 1232065 | Food & Drink | consumables | 2026-09-25 | `addition\|consumables\|ALL\|food & drink\|1232065` |
| R0552 | reject | addition | ALL | 2580 | Find Minerals | consumables | 2026-09-25 | `addition\|consumables\|ALL\|find minerals\|2580` |
| R0553 | reject | addition | ALL | 1269918 | Drink | consumables | 2026-09-25 | `addition\|consumables\|ALL\|drink\|1269918` |
| R0554 | reject | addition | ALL | 1291791 | Drink | consumables | 2026-09-25 | `addition\|consumables\|ALL\|drink\|1291791` |
| R0555 | reject | addition | ALL | 415603 | Encapsulated Destiny | consumables | 2026-09-25 | `addition\|consumables\|ALL\|encapsulated destiny\|415603` |
| R0556 | reject | addition | ALL | 449100 | Storm's Fury | consumables | 2026-09-25 | `addition\|consumables\|ALL\|storm's fury\|449100` |
| R0557 | reject | addition | ALL | 471521 | Sign of the Explorer | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sign of the explorer\|471521` |
| R0558 | reject | addition | ALL | 1266184 | Pangolin | consumables | 2026-09-25 | `addition\|consumables\|ALL\|pangolin\|1266184` |
| R0559 | reject | addition | ALL | 449115 | Forged Tenacity | consumables | 2026-09-25 | `addition\|consumables\|ALL\|forged tenacity\|449115` |
| R0560 | reject | addition | ALL | 1293326 | Tattered Amani War Banner | consumables | 2026-09-25 | `addition\|consumables\|ALL\|tattered amani war banner\|1293326` |
| R0561 | reject | addition | ALL | 1266182 | Bear | consumables | 2026-09-25 | `addition\|consumables\|ALL\|bear\|1266182` |
| R0562 | reject | addition | ALL | 1259061 | Favored by Kulzi | consumables | 2026-09-25 | `addition\|consumables\|ALL\|favored by kulzi\|1259061` |
| R0563 | reject | addition | ALL | 1291894 | Soulcoiler Ritual Vessel | consumables | 2026-09-25 | `addition\|consumables\|ALL\|soulcoiler ritual vessel\|1291894` |
| R0564 | reject | addition | ALL | 43308 | Find Fish | consumables | 2026-09-25 | `addition\|consumables\|ALL\|find fish\|43308` |
| R0565 | reject | addition | ALL | 1266197 | Lynx | consumables | 2026-09-25 | `addition\|consumables\|ALL\|lynx\|1266197` |
| R0566 | reject | addition | ALL | 449108 | Artisanal Flourish | consumables | 2026-09-25 | `addition\|consumables\|ALL\|artisanal flourish\|449108` |
| R0567 | reject | addition | ALL | 1250609 | Diverting Power... | consumables | 2026-09-25 | `addition\|consumables\|ALL\|diverting power...\|1250609` |
| R0568 | reject | addition | ALL | 1241764 | Nature's Tenacity | consumables | 2026-09-25 | `addition\|consumables\|ALL\|nature's tenacity\|1241764` |
| R0569 | reject | addition | ALL | 1237842 | Drain Shield | consumables | 2026-09-25 | `addition\|consumables\|ALL\|drain shield\|1237842` |
| R0570 | reject | addition | ALL | 1245025 | Farstrider's Guile | consumables | 2026-09-25 | `addition\|consumables\|ALL\|farstrider's guile\|1245025` |
| R0571 | reject | addition | ALL | 1235110 | Flask of the Blood Knights | consumables | 2026-09-25 | `addition\|consumables\|ALL\|flask of the blood knights\|1235110` |
| R0572 | reject | addition | ALL | 389820 | Under Red Wings | consumables | 2026-09-25 | `addition\|consumables\|ALL\|under red wings\|389820` |
| R0573 | reject | addition | ALL | 335150 | Sign of the Destroyer | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sign of the destroyer\|335150` |
| R0574 | reject | addition | ALL | 71564 | Deadly Precision | consumables | 2026-09-25 | `addition\|consumables\|ALL\|deadly precision\|71564` |
| R0575 | reject | addition | ALL | 1265323 | Despair | consumables | 2026-09-25 | `addition\|consumables\|ALL\|despair\|1265323` |
| R0576 | reject | addition | ALL | 1257988 | Solar Core Igniter | consumables | 2026-09-25 | `addition\|consumables\|ALL\|solar core igniter\|1257988` |
| R0577 | reject | addition | ALL | 1303479 | Sanguine Rancor | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sanguine rancor\|1303479` |
| R0578 | reject | addition | ALL | 1265327 | Desecrated Aura | consumables | 2026-09-25 | `addition\|consumables\|ALL\|desecrated aura\|1265327` |
| R0579 | reject | addition | ALL | 1259352 | Seed of the Devouring Wild | consumables | 2026-09-25 | `addition\|consumables\|ALL\|seed of the devouring wild\|1259352` |
| R0580 | reject | addition | ALL | 1236110 | Charged Bolts | consumables | 2026-09-25 | `addition\|consumables\|ALL\|charged bolts\|1236110` |
| R0581 | reject | addition | ALL | 1224312 | Entertained | consumables | 2026-09-25 | `addition\|consumables\|ALL\|entertained\|1224312` |
| R0582 | reject | addition | ALL | 271107 | Golden Luster | consumables | 2026-09-25 | `addition\|consumables\|ALL\|golden luster\|271107` |
| R0583 | reject | addition | ALL | 1236935 | Critical Overload | consumables | 2026-09-25 | `addition\|consumables\|ALL\|critical overload\|1236935` |
| R0584 | reject | addition | ALL | 1291580 | Ophidian Maw | consumables | 2026-09-25 | `addition\|consumables\|ALL\|ophidian maw\|1291580` |
| R0585 | reject | addition | ALL | 1232585 | Well Fed | consumables | 2026-09-25 | `addition\|consumables\|ALL\|well fed\|1232585` |
| R0586 | reject | addition | ALL | 186401 | Sign of the Skirmisher | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sign of the skirmisher\|186401` |
| R0587 | reject | addition | ALL | 452146 | Egg Sac | consumables | 2026-09-25 | `addition\|consumables\|ALL\|egg sac\|452146` |
| R0588 | reject | addition | DRUID | 1269633 | Echo of Ironfur | consumables | 2026-09-25 | `addition\|consumables\|DRUID\|echo of ironfur\|1269633` |
| R0589 | reject | addition | ALL | 1308559 | Shadow Shard Sliver | consumables | 2026-09-25 | `addition\|consumables\|ALL\|shadow shard sliver\|1308559` |
| R0590 | reject | addition | ALL | 383926 | Bound by Fire and Blaze | consumables | 2026-09-25 | `addition\|consumables\|ALL\|bound by fire and blaze\|383926` |
| R0591 | reject | addition | ALL | 1305981 | Sign of the Dragonflights | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sign of the dragonflights\|1305981` |
| R0592 | reject | addition | ALL | 223143 | Prismatic Bauble | consumables | 2026-09-25 | `addition\|consumables\|ALL\|prismatic bauble\|223143` |
| R0593 | reject | addition | ALL | 1307361 | Killer Instincts | consumables | 2026-09-25 | `addition\|consumables\|ALL\|killer instincts\|1307361` |
| R0594 | reject | addition | ALL | 1253114 | Ever-collapsing Void Fissure | consumables | 2026-09-25 | `addition\|consumables\|ALL\|ever-collapsing void fissure\|1253114` |
| R0595 | reject | addition | ALL | 1260572 | Siphoning Wind | consumables | 2026-09-25 | `addition\|consumables\|ALL\|siphoning wind\|1260572` |
| R0596 | reject | addition | DRUID | 1269645 | Echo of Frenzied Regeneration | consumables | 2026-09-25 | `addition\|consumables\|DRUID\|echo of frenzied regeneration\|1269645` |
| R0597 | reject | addition | ALL | 1252202 | Boon of Azerothian Blessings | consumables | 2026-09-25 | `addition\|consumables\|ALL\|boon of azerothian blessings\|1252202` |
| R0598 | reject | addition | ALL | 1272350 | Blessing of Zeal | consumables | 2026-09-25 | `addition\|consumables\|ALL\|blessing of zeal\|1272350` |
| R0599 | reject | addition | ALL | 1296890 | Ophidian Bone Whistle | consumables | 2026-09-25 | `addition\|consumables\|ALL\|ophidian bone whistle\|1296890` |
| R0600 | reject | addition | ALL | 186406 | Sign of the Critter | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sign of the critter\|186406` |
| R0601 | reject | addition | ALL | 1305773 | Ward of the Uncoiled | consumables | 2026-09-25 | `addition\|consumables\|ALL\|ward of the uncoiled\|1305773` |
| R0602 | reject | addition | DRUID | 1269659 | Gift of Ironfur | consumables | 2026-09-25 | `addition\|consumables\|DRUID\|gift of ironfur\|1269659` |
| R0603 | reject | addition | DRUID | 1269660 | Gift of Maul | consumables | 2026-09-25 | `addition\|consumables\|DRUID\|gift of maul\|1269660` |
| R0604 | reject | addition | DRUID | 1269661 | Gift of Frenzied Regeneration | consumables | 2026-09-25 | `addition\|consumables\|DRUID\|gift of frenzied regeneration\|1269661` |
| R0605 | reject | addition | ALL | 449091 | Keen Prowess | consumables | 2026-09-25 | `addition\|consumables\|ALL\|keen prowess\|449091` |
| R0606 | reject | addition | ALL | 1294727 | Well Fed | consumables | 2026-09-25 | `addition\|consumables\|ALL\|well fed\|1294727` |
| R0607 | reject | addition | ALL | 1233724 | Hearty Well Fed | consumables | 2026-09-25 | `addition\|consumables\|ALL\|hearty well fed\|1233724` |
| R0608 | reject | addition | ALL | 1243843 | Mite-y Feast | consumables | 2026-09-25 | `addition\|consumables\|ALL\|mite-y feast\|1243843` |
| R0609 | reject | addition | ALL | 1295275 | The King's Unyielding Wind | consumables | 2026-09-25 | `addition\|consumables\|ALL\|the king's unyielding wind\|1295275` |
| R0610 | reject | addition | ALL | 274739 | Rictus of the Laughing Skull | consumables | 2026-09-25 | `addition\|consumables\|ALL\|rictus of the laughing skull\|274739` |
| R0611 | reject | addition | ALL | 1244029 | Woven Fate | consumables | 2026-09-25 | `addition\|consumables\|ALL\|woven fate\|1244029` |
| R0612 | reject | addition | ALL | 1272713 | Sentinel's Blessing | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sentinel's blessing\|1272713` |
| R0613 | reject | addition | ALL | 225788 | Sign of the Emissary | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sign of the emissary\|225788` |
| R0614 | reject | addition | ALL | 1247578 | Halazzi's Swiftness | consumables | 2026-09-25 | `addition\|consumables\|ALL\|halazzi's swiftness\|1247578` |
| R0615 | reject | addition | ALL | 1216737 | Interrogate | consumables | 2026-09-25 | `addition\|consumables\|ALL\|interrogate\|1216737` |
| R0616 | reject | addition | ALL | 1294745 | The King's Unyielding Wind | consumables | 2026-09-25 | `addition\|consumables\|ALL\|the king's unyielding wind\|1294745` |
| R0617 | reject | addition | ALL | 1241289 | Arcanoweave Audacity | consumables | 2026-09-25 | `addition\|consumables\|ALL\|arcanoweave audacity\|1241289` |
| R0618 | reject | addition | ALL | 335151 | Sign of the Mists | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sign of the mists\|335151` |
| R0619 | reject | addition | ALL | 1263084 | Toggle Find Lumber | consumables | 2026-09-25 | `addition\|consumables\|ALL\|toggle find lumber\|1263084` |
| R0620 | reject | addition | ALL | 1255367 | Tangle of Vibrant Vines | consumables | 2026-09-25 | `addition\|consumables\|ALL\|tangle of vibrant vines\|1255367` |
| R0621 | reject | addition | ALL | 1253115 | Sealed Chaos Urn | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sealed chaos urn\|1253115` |
| R0622 | reject | addition | ALL | 1217101 | Ethereal Reaping | consumables | 2026-09-25 | `addition\|consumables\|ALL\|ethereal reaping\|1217101` |
| R0623 | reject | addition | ALL | 370667 | Rescue | consumables | 2026-09-25 | `addition\|consumables\|ALL\|rescue\|370667` |
| R0624 | reject | addition | ALL | 1272710 | Crimson Blessing | consumables | 2026-09-25 | `addition\|consumables\|ALL\|crimson blessing\|1272710` |
| R0625 | reject | addition | ALL | 274740 | Zeal of the Burning Blade | consumables | 2026-09-25 | `addition\|consumables\|ALL\|zeal of the burning blade\|274740` |
| R0626 | reject | addition | ALL | 1250491 | Find High-Value Beasts | consumables | 2026-09-25 | `addition\|consumables\|ALL\|find high-value beasts\|1250491` |
| R0627 | reject | addition | ALL | 1272321 | Blessing of Potency | consumables | 2026-09-25 | `addition\|consumables\|ALL\|blessing of potency\|1272321` |
| R0628 | reject | addition | ALL | 1272711 | Veiled Blessing | consumables | 2026-09-25 | `addition\|consumables\|ALL\|veiled blessing\|1272711` |
| R0629 | reject | addition | ALL | 1241806 | Cursed Stone Idol | consumables | 2026-09-25 | `addition\|consumables\|ALL\|cursed stone idol\|1241806` |
| R0630 | reject | addition | ALL | 1310012 | Mutating Elixir | consumables | 2026-09-25 | `addition\|consumables\|ALL\|mutating elixir\|1310012` |
| R0631 | reject | addition | ALL | 1234969 | Ethereal Augmentation | consumables | 2026-09-25 | `addition\|consumables\|ALL\|ethereal augmentation\|1234969` |
| R0632 | reject | addition | ALL | 1254624 | Radiant Blessing | consumables | 2026-09-25 | `addition\|consumables\|ALL\|radiant blessing\|1254624` |
| R0633 | reject | addition | ALL | 1232802 | Araz's Ritual Forge | consumables | 2026-09-25 | `addition\|consumables\|ALL\|araz's ritual forge\|1232802` |
| R0634 | reject | addition | ALL | 292361 | Embrace of Pa'ku | consumables | 2026-09-25 | `addition\|consumables\|ALL\|embrace of pa'ku\|292361` |
| R0635 | reject | addition | ALL | 227723 | Mana Divining Stone | consumables | 2026-09-25 | `addition\|consumables\|ALL\|mana divining stone\|227723` |
| R0636 | reject | addition | ALL | 1270343 | Volatile Power | consumables | 2026-09-25 | `addition\|consumables\|ALL\|volatile power\|1270343` |
| R0637 | reject | addition | ALL | 274741 | Ferocity of the Frostwolf | consumables | 2026-09-25 | `addition\|consumables\|ALL\|ferocity of the frostwolf\|274741` |
| R0638 | reject | addition | ALL | 1285644 | Hearty Well Fed | consumables | 2026-09-25 | `addition\|consumables\|ALL\|hearty well fed\|1285644` |
| R0639 | reject | addition | ALL | 1264337 | Empyrean Swiftness | consumables | 2026-09-25 | `addition\|consumables\|ALL\|empyrean swiftness\|1264337` |
| R0640 | reject | addition | ALL | 1269056 | Hearty Vilebranch Stew | consumables | 2026-09-25 | `addition\|consumables\|ALL\|hearty vilebranch stew\|1269056` |
| R0641 | reject | addition | ALL | 1307470 | Hex Lord's Doom | consumables | 2026-09-25 | `addition\|consumables\|ALL\|hex lord's doom\|1307470` |
| R0642 | reject | addition | ALL | 1282029 | Blinky's Collar | consumables | 2026-09-25 | `addition\|consumables\|ALL\|blinky's collar\|1282029` |
| R0643 | reject | addition | ALL | 431932 | Tempered Potion | consumables | 2026-09-25 | `addition\|consumables\|ALL\|tempered potion\|431932` |
| R0644 | reject | addition | ALL | 1303338 | Drink | consumables | 2026-09-25 | `addition\|consumables\|ALL\|drink\|1303338` |
| R0645 | reject | addition | ALL | 1291581 | Ula'tek's Gift | consumables | 2026-09-25 | `addition\|consumables\|ALL\|ula'tek's gift\|1291581` |
| R0646 | reject | addition | DEATHKNIGHT | 1252818 | Akil'zon's Cry of Victory | consumables | 2026-09-25 | `addition\|consumables\|DEATHKNIGHT\|akil'zon's cry of victory\|1252818` |
| R0647 | reject | addition | ALL | 345228 | Gladiator's Badge | consumables | 2026-09-25 | `addition\|consumables\|ALL\|gladiator's badge\|345228` |
| R0648 | reject | addition | ALL | 1264426 | Void-Touched | consumables | 2026-09-25 | `addition\|consumables\|ALL\|void-touched\|1264426` |
| R0649 | reject | addition | ALL | 443531 | Bolstering Light | consumables | 2026-09-25 | `addition\|consumables\|ALL\|bolstering light\|443531` |
| R0650 | reject | addition | ALL | 1259153 | Wraps of Cosmic Madness | consumables | 2026-09-25 | `addition\|consumables\|ALL\|wraps of cosmic madness\|1259153` |
| R0651 | reject | addition | PRIEST | 211336 | Archbishop Benedictus' Restitution | consumables | 2026-09-25 | `addition\|consumables\|PRIEST\|archbishop benedictus' restitution\|211336` |
| R0652 | reject | addition | ALL | 1293799 | Trovehunter's Bounty | consumables | 2026-09-25 | `addition\|consumables\|ALL\|trovehunter's bounty\|1293799` |
| R0653 | reject | addition | ALL | 404468 | Flight Style: Steady | consumables | 2026-09-25 | `addition\|consumables\|ALL\|flight style: steady\|404468` |
| R0654 | reject | addition | ALL | 335149 | Sign of the Scourge | consumables | 2026-09-25 | `addition\|consumables\|ALL\|sign of the scourge\|335149` |
| R0655 | reject | addition | ALL | 386692 | Dragon Games Equipment | consumables | 2026-09-25 | `addition\|consumables\|ALL\|dragon games equipment\|386692` |
| R0656 | reject | addition | ALL | 1263644 | Seed of Radiant Hope | consumables | 2026-09-25 | `addition\|consumables\|ALL\|seed of radiant hope\|1263644` |
| R0657 | reject | addition | ALL | 389581 | Coaching | consumables | 2026-09-25 | `addition\|consumables\|ALL\|coaching\|389581` |
| R0658 | reject | addition | ALL | 1295885 | Hex Lord's Doom | consumables | 2026-09-25 | `addition\|consumables\|ALL\|hex lord's doom\|1295885` |
| R0659 | reject | addition | ALL | 72968 | Precious's Ribbon | consumables | 2026-09-25 | `addition\|consumables\|ALL\|precious's ribbon\|72968` |
| R0660 | reject | addition | ALL | 455444 | Spelunker's Candle | consumables | 2026-09-25 | `addition\|consumables\|ALL\|spelunker's candle\|455444` |
| R0661 | reject | addition | ALL | 393438 | Draconic Augmentation | consumables | 2026-09-25 | `addition\|consumables\|ALL\|draconic augmentation\|393438` |
| R0662 | reject | addition | ALL | 1245969 | Blood | consumables | 2026-09-25 | `addition\|consumables\|ALL\|blood\|1245969` |
| R0663 | reject | addition | ALL | 267402 | Noxious Venom Gland | consumables | 2026-09-25 | `addition\|consumables\|ALL\|noxious venom gland\|267402` |
| R0664 | reject | addition | ALL | 1294941 | Curse of the Wound | consumables | 2026-09-25 | `addition\|consumables\|ALL\|curse of the wound\|1294941` |
| R0665 | reject | addition | ALL | 1217103 | Ethereal Reconstitution | consumables | 2026-09-25 | `addition\|consumables\|ALL\|ethereal reconstitution\|1217103` |
| R0666 | reject | addition | ALL | 250768 | Whispers of L'ura | consumables | 2026-09-25 | `addition\|consumables\|ALL\|whispers of l'ura\|250768` |
| R0667 | reject | addition | ALL | 154796 | Touch of Elune - Day | consumables | 2026-09-25 | `addition\|consumables\|ALL\|touch of elune - day\|154796` |
| R0668 | reject | addition | WARLOCK | 32752 | Summoning Disorientation | consumables | 2026-09-25 | `addition\|consumables\|WARLOCK\|summoning disorientation\|32752` |
| R0669 | reject | addition | ALL | 404184 | Ground Skimming | consumables | 2026-09-25 | `addition\|consumables\|ALL\|ground skimming\|404184` |
| R0670 | reject | addition | ALL | 1232086 | Well Fed | consumables | 2026-09-25 | `addition\|consumables\|ALL\|well fed\|1232086` |
| R0671 | reject | addition | ALL | 1277461 | Drink | consumables | 2026-09-25 | `addition\|consumables\|ALL\|drink\|1277461` |
| R0672 | reject | addition | ALL | 450720 | Inner Radiance | consumables | 2026-09-25 | `addition\|consumables\|ALL\|inner radiance\|450720` |
| R0673 | reject | addition | ALL | 450706 | Inner Resilience | consumables | 2026-09-25 | `addition\|consumables\|ALL\|inner resilience\|450706` |
| R0674 | reject | addition | ALL | 450699 | "The 50 Verses of Radiance" | consumables | 2026-09-25 | `addition\|consumables\|ALL\|"the 50 verses of radiance"\|450699` |
| R0675 | reject | addition | ALL | 451303 | Volatile Energy | consumables | 2026-09-25 | `addition\|consumables\|ALL\|volatile energy\|451303` |
| R0676 | reject | addition | ALL | 1236998 | Draught of Rampant Abandon | consumables | 2026-09-25 | `addition\|consumables\|ALL\|draught of rampant abandon\|1236998` |
| R0677 | reject | addition | ALL | 450696 | "The 50 Verses of Resilience" | consumables | 2026-09-25 | `addition\|consumables\|ALL\|"the 50 verses of resilience"\|450696` |
| R0678 | reject | addition | ALL | 1233712 | Hearty Well Fed | consumables | 2026-09-25 | `addition\|consumables\|ALL\|hearty well fed\|1233712` |
