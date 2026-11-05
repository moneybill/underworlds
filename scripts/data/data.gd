extends Node
## Static game data: races, classes, spells, items, monsters, traps.
## Autoloaded as `Data`. Everything here is plain dictionaries so designers can edit it.

const STATS := ["str", "iq", "pie", "vit", "agi", "luk"]
const STAT_NAMES := {"str": "STRENGTH", "iq": "I.Q.", "pie": "PIETY", "vit": "VITALITY", "agi": "AGILITY", "luk": "LUCK"}

const RACES := {
	"HUMAN":  {"str": 8,  "iq": 8,  "pie": 5,  "vit": 8,  "agi": 8,  "luk": 9},
	"ELF":    {"str": 7,  "iq": 10, "pie": 10, "vit": 6,  "agi": 9,  "luk": 6},
	"DWARF":  {"str": 10, "iq": 7,  "pie": 10, "vit": 10, "agi": 5,  "luk": 6},
	"GNOME":  {"str": 7,  "iq": 7,  "pie": 10, "vit": 8,  "agi": 10, "luk": 7},
	"HOBBIT": {"str": 5,  "iq": 7,  "pie": 7,  "vit": 6,  "agi": 10, "luk": 15},
	"HALF-ORC": {"str": 11, "iq": 5, "pie": 7, "vit": 10, "agi": 8, "luk": 7},
}
const RACE_TEXT := {
	"HUMAN": "Humans are steady",
	"ELF": "Elves are clever and agile",
	"DWARF": "Dwarves are strong and pious",
	"GNOME": "Gnomes are clever and lucky",
	"HOBBIT": "Hobbits are agile and lucky",
	"HALF-ORC": "Half-orcs are strong and tough",
}
## What each race adds to a rolled score. A statistic that isn't listed gets nothing.
## Names by the sex they suit. Choosing a RANDOM name at creation draws on both, as the sex is chosen later.
const MALE_NAMES := [
	"ALDRIC", "THORNE", "GARRICK", "DARIUS", "KAELEN", "BORIN", "DRAVEN", "ELDRIC", "MAGNUS", "THERON",
	"RODERIC", "VALEN", "CEDRIC", "TORVALD", "FENRIC", "LUCIAN", "KELLAN", "DARIAN", "ALARIC", "BROM",
	"CORVUS", "MALRIC", "TAVIAN", "ORIN", "HADRIAN", "ZEPHYR", "KAEL", "RAGNAR", "BASTIAN", "ELDON",
	"VARRIC", "SYLAS", "RONAN", "GARRON", "LEORIC", "DRUSTAN", "EVANDER", "CALDER", "OSRIC", "FENRIS",
	"ARDAN", "MEREK", "TALON", "SOREN", "DAROK", "KELRIC", "VAELOR", "THALION", "MORDECAI", "BRYNJAR",
	"ORYN", "KAEDOR", "RURIK", "ALISTAIR", "CORWIN", "JARETH", "MALAKAI", "TORREN", "EAMON", "VALRIC",
	"ENDRIC", "DAIN", "ARIC", "VARIAN", "LORCAN", "FAELAN", "GARRUS", "TIBER", "CAELUM", "ORMUND",
	"BAELOR", "CASSIAN", "WULFRIC", "ISKANDER", "THERIC", "DORIAN", "HALVARD", "MERRICK", "ZEVRAN", "ARVETH",
	"KORRIN", "BELRIC", "TAVROS", "ELDRAN", "FENWICK", "MAELOR", "VORIAN", "AEMON", "DRAKAR", "SILVAN",
	"OTHRIC", "BRYNDEN", "VEYRON", "ARCTURUS", "ROTHGAR", "JORVIK", "THADDEUS", "ZORATH",
	"VIKTOR", "WESLEY",
]
const FEMALE_NAMES := [
	"AELARA", "SERAPHINE", "ELOWEN", "MORRIGAN", "LYRA", "ISOLDE", "THALIA", "VESPER", "ARWEN", "KAELA",
	"FREYA", "ASTRID", "SYLVARA", "EVELINE", "NYX", "VALERIA", "ISADORA", "ELIRA", "BRYNN", "MORGANA",
	"CALISTA", "SELENE", "RHIANNON", "ALTHEA", "RAVENNA", "LIORA", "DRUSILLA", "AMARA", "FAELWEN", "YSOLDE",
	"KESTREL", "THESSA", "ROWENA", "BELLADONNA", "SERILDA", "AVELINE", "NERISSA", "ELYSIA", "VAELA", "MIRABEL",
	"FREYJA", "ELARA", "ISMARA", "SABLE", "TAMSIN", "CALYRA", "VEYRA", "ORIANA", "MAELIS", "ZARIA",
	"CELESTIA", "FENELLA", "ARADIA", "LYSANDRA", "EVELARA", "THALINDRA", "KAELIS", "MORWEN", "ALIRA", "SELVARA",
	"AZURA", "BRIELLE", "CERYS", "DELYTH", "ELARIA", "FIORA", "GALADRIEL", "HESTIA", "ILLYRIA", "JESSAMINE",
	"KALINDRA", "LUNARA", "MELISANDE", "NERYS", "OPHELIA", "PERSEPHONE", "QUENARA", "ROSWYN", "SAPHIRA", "TALINDRA",
	"UMBRA", "VALLERIA", "WYNORA", "XANTHE", "YAVANNA", "ZAFIRA", "ANWEN", "BRYNNA", "CORISANDE", "DAELITH",
	"EOWYN", "FIORWYN", "GWENDOLYN", "HALIA", "IRIDESSA", "JYNARA", "KALLISTA", "LIRIEN", "MYRANDA", "ZEPHYRA",
]
const CHARACTER_NAMES := MALE_NAMES + FEMALE_NAMES  # first names
const LAST_NAMES := [
	"ASHFORD", "BLACKTHORN", "STORMBORN", "IRONWOOD", "RAVENSHADE", "THORNFIELD", "SILVERBROOK", "GRIMWALD", "WINTERMERE",
	"GOLDCREST", "DARKWATER", "WOLFSBANE", "EMBERFALL", "STONEHELM", "NIGHTINGALE", "FROSTBANE", "RAVENCREST", "OAKENSHIELD",
	"BRIGHTBLADE", "SHADOWMERE", "BLOODWORTH", "STORMVALE", "IRONHEART", "DUSKWALKER", "THORNWALL", "MOONSHADOW", "FIREBRAND",
	"BLACKWATER", "SILVERTHORN", "GRIMSTONE", "WILDMERE", "ASHENFORD", "GOLDHAVEN", "WINTERBORN", "REDWYNE", "NIGHTSHADE",
	"STORMBREAKER", "FLINTLOCK", "DARKMOOR", "RAVENWOOD", "EMBERSTONE", "FROSTFALL", "HIGHCASTLE", "WOLFSHEAR", "THORNBROOK",
	"STEELHEART", "DUSKRUNNER", "BRIGHTWATER", "SHADOWBROOK", "IRONVALE", "CROWHURST", "BLACKWELL", "SILVERWIND", "ASHENVALE",
	"BLOODMOON", "STONEBRIDGE", "WINTERCREST", "GOLDTHORN", "FIRESTONE", "RAVENHALL", "GRIMSHAW", "OAKHEART", "STORMWATCH",
	"DARKHAVEN", "THORNCREST", "FROSTWOOD", "EMBERWYN", "BLACKSTONE", "MOONCREST", "IRONFORGE", "SILVERMERE", "WOLFHEART",
	"ASHBOURNE", "NIGHTBROOK", "REDTHORN", "SHADOWFALL", "BRIGHTFORGE", "STONEWARD", "RAVENSCAR", "GOLDWATER", "GRIMLOCK",
	"WINTERHALL", "BLOODSTONE", "STORMHOLD", "FROSTHOLM", "EMBERWOOD", "THORNMERE", "IRONCLAD", "DARKTHORN", "SILVERKEEP",
	"ASHWALKER", "RAVENMARK", "WOLFCREST", "MOONVALE", "STEELBROOK", "FIRECREST", "STONEFALL", "NIGHTWIND", "STORMRIDER",
	"STORMREAVER", "DREADMOOR", "ASHENBLADE", "RAVENHART", "IRONBANE", "SHADOWFANG", "BLOODRAVEN", "GRIMSHADOW", "FROSTBORN",
	"NIGHTREIGN", "SILVERFANG", "THORNBLOOD", "DUSKBANE", "BLACKFYRE", "IRONVEIL", "VEXMOOR", "RAVENSTORM", "GRIMWARD",
	"SHADOWBORN", "FROSTVEIL", "BLOODTHORN", "NIGHTFALL", "STEELGRAVE", "CROWBANE", "DARKWHISPER", "THORNWICK", "BLACKMOOR",
	"SILVERVEIN", "WRAITHWOOD", "EMBERHEART", "DREADWIND", "GRIMFANG", "STORMCREST", "IRONCLAW", "FROSTGRAVE", "THORNBREAKER",
	"BLACKHOLLOW", "STEELTHORN", "WOLFHART", "EMBERSTORM", "DARKBANE", "STORMFANG", "NIGHTREAVER", "SHADOWCREST", "THORNVALE",
	"BLACKRIDGE", "DREADFANG", "FIRESTORM", "MOONVEIL", "GRIMHOLT", "ASHENFALL", "IRONMARK", "SILVERBLADE", "BLOODREIGN",
	"SHADOWEND", "THORNHELM", "EMBERGRAVE", "GRIMVALE", "ASHENVEIL", "RAVENFALL", "DREADSTONE", "BLACKSPIRE", "STEELWIND",
	"THORNSHADOW", "BLOODFANG", "EVERDARK",
]
## Titles for later: nothing uses them yet.
const MALE_TITLES := ["SIR", "LORD", "DUKE", "BARON", "MARQUIS"]
const FEMALE_TITLES := ["LADY", "DUCHESS", "DAME", "BARONESS", "MARQUESS"]
const LAST_NAME_CHANCE := 50  # percent of random names, for characters and mercenaries, that have a last name
const MAX_NAME := 24  # room for the longest first and last name together
const ALIGNMENTS := ["GOOD", "NEUTRAL", "EVIL"]
const RACE_ALIGNMENTS := {"HALF-ORC": ["NEUTRAL", "EVIL"]}  # a race not listed can be any of them
const RACE_BONUS := {
	"HUMAN": {"str": 1, "iq": 1, "pie": 1, "vit": 1, "agi": 1, "luk": 1},
	"ELF": {"iq": 2, "agi": 2},
	"DWARF": {"str": 2, "pie": 2},
	"GNOME": {"str": -1, "iq": 2, "luk": 3},
	"HOBBIT": {"agi": 2, "luk": 2},
	"HALF-ORC": {"str": 3, "iq": -2, "agi": 1, "vit": 2},
}
## Each statistic's full name and what it does, for the race screen.
const STAT_INFO := {
	"str": ["Strength", "Strength affects your skill and damage in combat."],
	"iq": ["Intelligence", "Intelligence influences your ability to cast magic spells."],
	"pie": ["Piety", "Piety influences your ability to cast priest spells."],
	"vit": ["Vitality", "Vitality affects your ability to withstand damage."],
	"agi": ["Agility", "Agility helps you avoid attacks and to open treasure chests."],
	"luk": ["Luck", "Luck comes to your aid in many mysterious ways."],
}
const ALIGNS := ["GOOD", "NEUTRAL", "EVIL"]
## How many portraits a new character can choose from, by sex: assets/images/portraits/male_1.webp and on.
const PORTRAIT_COUNTS := {"MALE": 59, "FEMALE": 58}

## al: allowed alignment initials. M / P: [first character level that learns that school, levels per extra spell level].
const CLASSES := {
	"FIGHTER": {"ab": "FIG", "l": "F", "req": {"str": 11}, "al": "GNE", "hd": 10, "xp": 1000, "war": true},
	"MAGE":    {"ab": "MAG", "l": "M", "req": {"iq": 11}, "al": "GNE", "hd": 4, "xp": 1100, "M": [1, 2]},
	"PRIEST":  {"ab": "PRI", "l": "P", "req": {"pie": 11}, "al": "GE", "hd": 8, "xp": 1050, "P": [1, 2], "dispel": 1},
	"THIEF":   {"ab": "THI", "l": "T", "req": {"agi": 11}, "al": "NE", "hd": 6, "xp": 900, "thief": true},
	"BISHOP":  {"ab": "BIS", "l": "B", "req": {"iq": 12, "pie": 12}, "al": "GE", "hd": 6, "xp": 1250, "M": [1, 4], "P": [4, 4], "dispel": 4, "ident": true},
	"SAMURAI": {"ab": "SAM", "l": "S", "req": {"str": 15, "iq": 11, "pie": 10, "vit": 14, "agi": 10}, "al": "GN", "hd": 8, "hp0": 6, "xp": 1250, "war": true, "M": [4, 3]},
	"LORD":    {"ab": "LOR", "l": "L", "req": {"str": 15, "iq": 12, "pie": 12, "vit": 15, "agi": 14, "luk": 15}, "al": "G", "hd": 10, "xp": 1300, "war": true, "P": [4, 3], "dispel": 9},
	"NINJA":   {"ab": "NIN", "l": "N", "req": {"str": 17, "iq": 17, "pie": 17, "vit": 17, "agi": 17, "luk": 17}, "al": "E", "hd": 6, "xp": 1450, "war": true, "ninja": true},
}

## name: [school, level, when (C combat, K camp, A any, X chest), target, description]
## Order matters: within a level, spells are learned in this order.
const SPELLS := {
	"HALITO":    ["M", 1, "C", "mon",   "Fireball, 1d8 to one monster"],
	"MOGREF":    ["M", 1, "C", "self",  "Caster AC -2 for the fight"],
	"KATINO":    ["M", 1, "C", "grp",   "Puts a group of monsters to sleep"],
	"DUMAPIC":   ["M", 1, "K", "none",  "Reveals your position and facing"],
	"DILTO":     ["M", 2, "C", "grp",   "Darkness: a group is easier to hit"],
	"SOPIC":     ["M", 2, "C", "self",  "Caster AC -4 for the fight"],
	"MAHALITO":  ["M", 3, "C", "grp",   "Big fire, 4d6 to a group"],
	"MOLITO":    ["M", 3, "C", "grp",   "Sparks, 3d6 to half a group"],
	"MORLIS":    ["M", 4, "C", "grp",   "Fear: a group is much easier to hit"],
	"DALTO":     ["M", 4, "C", "grp",   "Blizzard, 6d6 to a group"],
	"LAHALITO":  ["M", 4, "C", "grp",   "Flame storm, 6d6 to a group"],
	"MADALTO":   ["M", 5, "C", "grp",   "Frost, 8d8 to a group"],
	"MAKANITO":  ["M", 5, "C", "all",   "Kills every monster below level 8"],
	"KALKI":     ["P", 1, "C", "party", "Party AC -1 for the fight"],
	"DIOS":      ["P", 1, "A", "ally",  "Heals 1d8 hit points"],
	"BADIOS":    ["P", 1, "C", "mon",   "Harms one monster, 1d8"],
	"MILWA":     ["P", 1, "A", "none",  "Light: see farther and spot secret doors"],
	"PORFIC":    ["P", 1, "C", "self",  "Caster AC -4 for the fight"],
	"MATU":      ["P", 2, "C", "party", "Party AC -2 for the fight"],
	"CALFO":     ["P", 2, "X", "none",  "Names the trap on a chest (95%)"],
	"MANIFO":    ["P", 2, "C", "grp",   "Paralyzes a group"],
	"MONTINO":   ["P", 2, "C", "grp",   "Silences a group of spell casters"],
	"LOMILWA":   ["P", 3, "A", "none",  "Light that lasts the whole expedition"],
	"DIALKO":    ["P", 3, "A", "ally",  "Cures sleep and paralysis"],
	"LATUMAPIC": ["P", 3, "A", "none",  "Shows the true names of monsters"],
	"BAMATU":    ["P", 3, "C", "party", "Party AC -4 for the fight"],
	"DIAL":      ["P", 4, "A", "ally",  "Heals 2d8 hit points"],
	"BADIAL":    ["P", 4, "C", "mon",   "Harms one monster, 2d8"],
	"LATUMOFIS": ["P", 4, "A", "ally",  "Cures poison"],
	"MAPORFIC":  ["P", 4, "A", "none",  "Party AC -2 for the expedition"],
	"DIALMA":    ["P", 5, "A", "ally",  "Heals 3d8 hit points"],
	"BADIALMA":  ["P", 5, "C", "mon",   "Harms one monster, 3d8"],
	"LITOKAN":   ["P", 5, "C", "grp",   "Pillar of flame, 3d8 to a group"],
	"DI":        ["P", 5, "K", "ally",  "Raises a dead companion (may fail)"],
}
const SPELL_DAMAGE := {"HALITO": "1d8", "BADIOS": "1d8", "BADIAL": "2d8", "BADIALMA": "3d8", "MAHALITO": "4d6",
	"MOLITO": "3d6", "DALTO": "6d6", "LAHALITO": "6d6", "MADALTO": "8d8", "LITOKAN": "3d8"}

## slot: W weapon, A armor, S shield, H helm, U usable (potion/scroll/rod), R carried
const ALL_CLASSES := "FMPTBSLN"
const ITEMS := {
	"dagger":   {"name": "DAGGER", "unk": "WEAPON", "slot": "W", "cls": "FMTSLN", "price": 5, "dmg": "1d4"},
	"staff":    {"name": "STAFF", "unk": "WEAPON", "slot": "W", "cls": ALL_CLASSES, "price": 10, "dmg": "1d5"},
	"ssword":   {"name": "SHORT SWORD", "unk": "SWORD", "slot": "W", "cls": "FTSLN", "price": 15, "dmg": "1d6"},
	"lsword":   {"name": "LONG SWORD", "unk": "SWORD", "slot": "W", "cls": "FSLN", "price": 25, "dmg": "1d8"},
	"mace":     {"name": "ANOINTED MACE", "unk": "MACE", "slot": "W", "cls": "FPBSLN", "price": 30, "dmg": "2d3"},
	"flail":    {"name": "ANOINTED FLAIL", "unk": "MACE", "slot": "W", "cls": "FPBSLN", "price": 150, "dmg": "1d7+1"},
	"robes":    {"name": "ROBES", "unk": "ARMOR", "slot": "A", "cls": ALL_CLASSES, "price": 15, "ac": 1},
	"leather":  {"name": "LEATHER ARMOR", "unk": "ARMOR", "slot": "A", "cls": "FPTBSLN", "price": 50, "ac": 2},
	"chain":    {"name": "CHAIN MAIL", "unk": "ARMOR", "slot": "A", "cls": "FPSLN", "price": 90, "ac": 3},
	"breast":   {"name": "BREAST PLATE", "unk": "ARMOR", "slot": "A", "cls": "FPSLN", "price": 200, "ac": 4},
	"plate":    {"name": "PLATE MAIL", "unk": "ARMOR", "slot": "A", "cls": "FPSLN", "price": 750, "ac": 5},
	"sshield":  {"name": "SMALL SHIELD", "unk": "SHIELD", "slot": "S", "cls": "FPTSLN", "price": 20, "ac": 2},
	"lshield":  {"name": "LARGE SHIELD", "unk": "SHIELD", "slot": "S", "cls": "FPSLN", "price": 40, "ac": 3},
	"helm":     {"name": "HELM", "unk": "HELM", "slot": "H", "cls": "FSLN", "price": 100, "ac": 1},
	"pdios":    {"name": "POTION OF DIOS", "unk": "POTION", "slot": "U", "cls": ALL_CLASSES, "price": 200, "spell": "DIOS", "ch": 1},
	"plato":    {"name": "POTION OF LATUMOFIS", "unk": "POTION", "slot": "U", "cls": ALL_CLASSES, "price": 300, "spell": "LATUMOFIS", "ch": 1},
	"skatino":  {"name": "SCROLL OF KATINO", "unk": "SCROLL", "slot": "U", "cls": ALL_CLASSES, "price": 500, "spell": "KATINO", "ch": 1},
	"sbadios":  {"name": "SCROLL OF BADIOS", "unk": "SCROLL", "slot": "U", "cls": ALL_CLASSES, "price": 500, "spell": "BADIOS", "ch": 1},
	"ssword1":  {"name": "SHORT SWORD +1", "unk": "SWORD", "slot": "W", "cls": "FTSLN", "price": 600, "dmg": "1d6+1", "hit": 1},
	"lsword1":  {"name": "LONG SWORD +1", "unk": "SWORD", "slot": "W", "cls": "FSLN", "price": 1000, "dmg": "1d8+1", "hit": 1},
	"mace1":    {"name": "MACE +1", "unk": "MACE", "slot": "W", "cls": "FPBSLN", "price": 800, "dmg": "2d3+1", "hit": 1},
	"sswordc":  {"name": "SHORT SWORD -1", "unk": "SWORD", "slot": "W", "cls": "FTSLN", "price": 300, "dmg": "1d6-1", "hit": -1, "curse": true},
	"leather1": {"name": "LEATHER +1", "unk": "ARMOR", "slot": "A", "cls": "FPTBSLN", "price": 1500, "ac": 3},
	"leatherc": {"name": "LEATHER -1", "unk": "ARMOR", "slot": "A", "cls": "FPTBSLN", "price": 300, "ac": 1, "curse": true},
	"chain1":   {"name": "CHAIN MAIL +1", "unk": "ARMOR", "slot": "A", "cls": "FPSLN", "price": 1500, "ac": 4},
	"lshield1": {"name": "LARGE SHIELD +1", "unk": "SHIELD", "slot": "S", "cls": "FPSLN", "price": 1500, "ac": 4},
	"helm1":    {"name": "HELM +1", "unk": "HELM", "slot": "H", "cls": "FSLN", "price": 3000, "ac": 2},
	"rodflame": {"name": "ROD OF FLAME", "unk": "ROD", "slot": "U", "cls": ALL_CLASSES, "price": 2000, "spell": "MAHALITO", "ch": 12},
	"staffmog": {"name": "STAFF OF MOGREF", "unk": "STAFF", "slot": "W", "cls": ALL_CLASSES, "price": 3000, "dmg": "1d5", "spell": "MOGREF", "ch": 10},
	"ringheal": {"name": "RING OF HEALING", "unk": "RING", "slot": "R", "cls": ALL_CLASSES, "price": 6000, "regen": 1},
	"lsword2":  {"name": "LONG SWORD +2", "unk": "SWORD", "slot": "W", "cls": "FSLN", "price": 4000, "dmg": "1d8+2", "hit": 2},
	"plate1":   {"name": "PLATE MAIL +1", "unk": "ARMOR", "slot": "A", "cls": "FPSLN", "price": 3000, "ac": 6},
	"evilsw":   {"name": "EVIL SWORD +3", "unk": "SWORD", "slot": "W", "cls": "FSLN", "price": 8000, "dmg": "1d10+3", "hit": 3, "align": "E"},
	"holymace": {"name": "HOLY MACE +2", "unk": "MACE", "slot": "W", "cls": "FPBSLN", "price": 6000, "dmg": "2d4+2", "hit": 2, "align": "G"},
	"cusinart": {"name": "BLADE CUSINART", "unk": "SWORD", "slot": "W", "cls": "FSLN", "price": 15000, "dmg": "1d12+4", "hit": 3},
	"amulet":   {"name": "WERDNA'S AMULET", "unk": "AMULET", "slot": "R", "cls": ALL_CLASSES, "price": 0, "quest": true},
}
## The picture of every item, under ITEM_ICON_DIR.
const ITEM_ICON_DIR := "res://assets/images/"
const ITEM_ICONS := {
	"dagger": "Weapons/Dagger.png", "staff": "Weapons/Staff.png", "ssword": "Weapons/ShortSword.png",
	"lsword": "Weapons/Longsword.png", "mace": "Weapons/AnoitedMace.png", "flail": "Weapons/AnoitedFlail.png",
	"ssword1": "Weapons/SwortSword+1.png", "lsword1": "Weapons/Longsword+1.png", "mace1": "Weapons/Mace+1.png",
	"sswordc": "Weapons/CursedShortSword.png", "staffmog": "Weapons/Staff+1.png", "lsword2": "Weapons/Longsword+2.png",
	"evilsw": "Weapons/EvilSword+3.png", "holymace": "Weapons/Mace+2.png", "cusinart": "Weapons/BladeCuisinart.png",
	"robes": "Armor/Robes.png", "leather": "Armor/LeatherArmor.png", "breast": "Armor/BreastPlate.png",
	"plate": "Armor/PlateMail.png", "sshield": "Armor/SmallShield.png", "lshield": "Armor/LargeShield.png",
	"helm": "Armor/Helm.png", "leather1": "Armor/LeatherArmor+1.png", "leatherc": "Armor/LeatherArmor.png",
	"lshield1": "Armor/LargeShield+1.png", "helm1": "Armor/Helm+1.png", "plate1": "Armor/PlateMail+1.png",
	"chain": "Armor/ChainMail.png", "chain1": "Armor/ChainMail+1.png",
	"pdios": "PotionsScrolls/PotionofDios.png", "plato": "PotionsScrolls/PotionofLatumodis.png",
	"skatino": "PotionsScrolls/ScrollKatino.png", "sbadios": "PotionsScrolls/ScrollBadios.png",
	"rodflame": "PotionsScrolls/RodofFlame.png", "ringheal": "PotionsScrolls/RingofHealing.png",
	"amulet": "PotionsScrolls/WerdnaAmulet.png",
}
## Until it is identified, a magic or cursed item shows the picture of the plain one it looks like.
const ITEM_LOOKS_LIKE := {
	"ssword1": "ssword", "sswordc": "ssword", "lsword1": "lsword", "lsword2": "lsword", "evilsw": "lsword",
	"cusinart": "lsword", "mace1": "mace", "holymace": "mace", "staffmog": "staff", "leather1": "leather",
	"leatherc": "leather", "chain1": "chain", "lshield1": "lshield", "helm1": "helm", "plate1": "plate",
	"plato": "pdios", "sbadios": "skatino",  # an unknown potion or scroll looks like the common one
}


## The path of an item's picture, or "" if it has none.
static func item_icon(id: String, known := true) -> String:
	var shown: String = id if known else ITEM_LOOKS_LIKE.get(id, id)
	return ITEM_ICON_DIR + ITEM_ICONS[shown] if ITEM_ICONS.has(shown) else ""


## The Broken Anvil's opening stock. -1 means he never runs out.
const SHOP_START := {"dagger": -1, "staff": -1, "ssword": -1, "lsword": -1, "mace": -1, "flail": 3, "robes": -1,
	"leather": -1, "chain": -1, "breast": 4, "plate": 2, "sshield": -1, "lshield": -1, "helm": 4, "pdios": 6, "plato": 3, "skatino": 2}
const LOOT := [[],
	["pdios", "pdios", "sbadios", "skatino", "ssword1", "sswordc", "leatherc", "helm", "lshield", "plato"],
	["pdios", "plato", "lsword1", "mace1", "leather1", "chain1", "sswordc", "leatherc", "rodflame", "lshield1"],
	["lsword1", "mace1", "chain1", "lshield1", "helm1", "rodflame", "staffmog", "ringheal", "evilsw", "holymace"],
	["lsword2", "plate1", "helm1", "ringheal", "evilsw", "holymace", "cusinart", "rodflame"],
]
const TRAPS := ["TRAPLESS CHEST", "POISON NEEDLE", "GAS BOMB", "CROSSBOW BOLT", "EXPLODING BOX", "STUNNER", "TELEPORTER"]

## look: picture used by the combat view
const MONS := {
	"SLIME":   {"n": "BUBBLY SLIME", "u": "SLIME", "look": "blob", "lv": 1, "hp": [3, 8], "ac": 8, "atk": ["1d4"], "xp": 30, "g": [1, 5]},
	"ORC":     {"n": "ORC", "u": "MAN-LIKE CREATURE", "look": "humanoid", "lv": 1, "hp": [3, 9], "ac": 10, "atk": ["1d6"], "xp": 35, "g": [2, 6]},
	"KOBOLD":  {"n": "KOBOLD", "u": "SMALL HUMANOID", "look": "humanoid", "lv": 1, "hp": [2, 7], "ac": 10, "atk": ["1d4"], "xp": 25, "g": [2, 6], "friendly": true},
	"SKEL":    {"n": "SKELETON", "u": "SKELETON", "look": "undead", "lv": 1, "hp": [4, 10], "ac": 9, "atk": ["1d6"], "xp": 40, "g": [1, 5], "undead": true},
	"MIMIC":   {"n": "MIMIC", "u": "CHEST", "look": "mimic", "lv": 1, "hp": [6, 12], "ac": 8, "atk": ["1d6"], "xp": 60, "g": [1, 2], "sleep_res": 50},
	"RAT":     {"n": "GIANT RAT", "u": "SMALL ANIMAL", "look": "beast", "lv": 1, "hp": [2, 6], "ac": 8, "atk": ["1d3"], "xp": 22, "g": [2, 6]},
	"MAGE1":   {"n": "LVL 1 MAGE", "u": "MAN IN ROBE", "look": "robe", "lv": 1, "hp": [3, 7], "ac": 10, "atk": ["1d4"], "xp": 50, "g": [1, 3], "sp": ["HALITO", "KATINO"]},
	"PRIEST1": {"n": "LVL 1 PRIEST", "u": "MAN IN ROBE", "look": "robe", "lv": 1, "hp": [4, 9], "ac": 8, "atk": ["1d6"], "xp": 50, "g": [1, 3], "sp": ["BADIOS", "DIOS"], "friendly": true},
	"ZOMBIE":  {"n": "ZOMBIE", "u": "CORPSE-LIKE CREATURE", "look": "undead", "lv": 2, "hp": [8, 18], "ac": 8, "atk": ["1d8"], "xp": 90, "g": [2, 5], "undead": true},
	"TOAD":    {"n": "GIANT TOAD", "u": "AMPHIBIAN", "look": "beast", "lv": 2, "hp": [8, 16], "ac": 7, "atk": ["1d6"], "xp": 100, "g": [1, 4], "poison": true},
	"HWAY":    {"n": "HIGHWAYMAN", "pl": "HIGHWAYMEN", "u": "MAN IN LEATHER", "look": "humanoid", "lv": 2, "hp": [8, 16], "ac": 7, "atk": ["1d8"], "xp": 110, "g": [2, 5]},
	"MAGE3":   {"n": "LVL 3 MAGE", "u": "MAN IN ROBE", "look": "robe", "lv": 3, "hp": [8, 14], "ac": 9, "atk": ["1d4"], "xp": 160, "g": [1, 3], "sp": ["HALITO", "KATINO", "MAHALITO"]},
	"SPIDER":  {"n": "HUGE SPIDER", "u": "INSECT", "look": "beast", "lv": 2, "hp": [6, 14], "ac": 6, "atk": ["1d6"], "xp": 110, "g": [1, 4], "poison": true},
	"GAS":     {"n": "GAS CLOUD", "u": "CLOUD", "look": "cloud", "lv": 2, "hp": [5, 10], "ac": 6, "atk": ["1d2"], "xp": 120, "g": [1, 3], "breath": "1d6", "sleep_res": 100},
	"GHOUL":   {"n": "GHOUL", "u": "CORPSE-LIKE CREATURE", "look": "undead", "lv": 4, "hp": [16, 30], "ac": 6, "atk": ["1d4", "1d4", "1d6"], "xp": 280, "g": [1, 4], "undead": true, "para": true},
	"GARG":    {"n": "GARGOYLE", "u": "STATUE", "look": "daemon", "lv": 4, "hp": [18, 32], "ac": 5, "atk": ["1d6", "1d6"], "xp": 320, "g": [1, 3], "sleep_res": 60},
	"PRIEST5": {"n": "LVL 5 PRIEST", "u": "MAN IN ROBE", "look": "robe", "lv": 5, "hp": [16, 26], "ac": 6, "atk": ["1d8"], "xp": 300, "g": [1, 3], "sp": ["BADIAL", "DIAL", "MANIFO"]},
	"DRAGPUP": {"n": "DRAGON PUPPY", "pl": "DRAGON PUPPIES", "u": "SMALL DRAGON", "look": "dragon", "lv": 4, "hp": [20, 30], "ac": 5, "atk": ["1d8"], "xp": 400, "g": [1, 2], "breath": "2d6"},
	"BUSH":    {"n": "BUSHWACKER", "u": "MAN IN LEATHER", "look": "humanoid", "lv": 4, "hp": [16, 28], "ac": 4, "atk": ["1d10"], "xp": 260, "g": [2, 4]},
	"VAMP":    {"n": "VAMPIRE", "u": "MAN IN BLACK", "look": "undead", "lv": 7, "hp": [40, 60], "ac": 0, "atk": ["1d10", "1d6"], "xp": 900, "g": [1, 3], "undead": true, "para": true},
	"MAGE7":   {"n": "LVL 7 MAGE", "u": "MAN IN ROBE", "look": "robe", "lv": 7, "hp": [24, 36], "ac": 6, "atk": ["1d4"], "xp": 800, "g": [1, 3], "sp": ["MAHALITO", "LAHALITO", "KATINO"]},
	"DAEMON":  {"n": "MINOR DAEMON", "u": "DEMON", "look": "daemon", "lv": 6, "hp": [35, 50], "ac": 2, "atk": ["2d6", "1d8"], "xp": 850, "g": [1, 2], "sleep_res": 70},
	"GIANT":   {"n": "HILL GIANT", "u": "LARGE HUMANOID", "look": "humanoid", "lv": 6, "hp": [45, 60], "ac": 3, "atk": ["3d6"], "xp": 900, "g": [1, 2]},
	"TOADMAN": {"n": "TOADFOLK SCOUT", "u": "HOODED CREATURE", "look": "humanoid", "lv": 2, "hp": [6, 14], "ac": 8, "atk": ["1d6"], "xp": 90, "g": [2, 5]},
	"LIZARD":  {"n": "LIZARDMAN", "pl": "LIZARDMEN", "u": "SCALED HUMANOID", "look": "humanoid", "lv": 3, "hp": [12, 22], "ac": 6, "atk": ["1d6", "1d4"], "xp": 180, "g": [2, 4]},
	"BASILISK": {"n": "BASILISK", "u": "GREAT LIZARD", "look": "beast", "lv": 5, "hp": [28, 42], "ac": 3, "atk": ["1d10"], "xp": 650, "g": [1, 2], "para": true, "sleep_res": 40},
	"FROST":   {"n": "FROST GIANT", "u": "LARGE HUMANOID", "look": "humanoid", "lv": 7, "hp": [55, 75], "ac": 2, "atk": ["3d8"], "xp": 1200, "g": [1, 2]},
	"FIREG":   {"n": "FIRE GIANT", "u": "LARGE HUMANOID", "look": "humanoid", "lv": 8, "hp": [65, 85], "ac": 1, "atk": ["4d6"], "xp": 1500, "g": [1, 2], "sleep_res": 50},
	"GDAEMON": {"n": "GREATER DAEMON", "u": "DEMON", "look": "daemon", "lv": 8, "hp": [60, 80], "ac": -1, "atk": ["2d8", "2d6"], "xp": 1700, "g": [1, 1], "sleep_res": 85},
	"REDDRAG": {"n": "RED DRAGON", "u": "DRAGON", "look": "dragon", "lv": 9, "hp": [80, 100], "ac": -2, "atk": ["2d8", "1d10"], "xp": 2200, "g": [1, 1], "breath": "5d6", "sleep_res": 80},
	"YETI":    {"n": "YETI", "u": "SHAGGY HUMANOID", "look": "humanoid", "lv": 5, "hp": [32, 46], "ac": 4, "atk": ["2d6", "1d8"], "xp": 620, "g": [1, 2], "sleep_res": 20},
	"SPAWN":   {"n": "VAMPIRE SPAWN", "pl": "VAMPIRE SPAWN", "u": "CLOAKED FIGURE", "look": "undead", "lv": 5, "hp": [24, 36], "ac": 4, "atk": ["1d8", "1d4"], "xp": 600, "g": [1, 3], "undead": true, "para": true},
	"DLORD":   {"n": "DAEMON LORD", "u": "DEMON", "look": "daemon", "lv": 9, "hp": [85, 110], "ac": -3, "atk": ["2d8", "2d6"], "xp": 2600, "g": [1, 1], "sp": ["MAHALITO", "LAHALITO", "KATINO"], "sleep_res": 90},
	"WERDNA":  {"n": "WERDNA", "pl": "WERDNA", "u": "MAN IN ROBES", "look": "boss", "lv": 10, "hp": [110, 130], "ac": -3, "atk": ["2d6"], "xp": 6000, "g": [1, 1],
		"sp": ["LAHALITO", "MAHALITO", "MADALTO", "KATINO"], "sleep_res": 100, "boss": true},
}
const MON_BY_LEVEL := [[],
	["SLIME", "ORC", "KOBOLD", "SKEL", "MIMIC", "RAT", "MAGE1", "PRIEST1"],
	["ZOMBIE", "TOAD", "HWAY", "MAGE3", "SPIDER", "GAS", "SKEL", "ORC", "TOADMAN"],
	["GHOUL", "GARG", "PRIEST5", "DRAGPUP", "BUSH", "MAGE3", "ZOMBIE", "LIZARD", "BASILISK", "YETI", "SPAWN"],
	["VAMP", "MAGE7", "DAEMON", "GIANT", "GHOUL", "DRAGPUP", "FROST", "FIREG", "GDAEMON", "REDDRAG", "DLORD"],
]
const GRAFFITI := [[],
	["SCRAWLED ON THE WALL: \"TURN BACK, LITTLE HEROES. -W\"", "A NOTICE: \"BY ORDER OF TREBOR, ALL LOOT BELONGS TO THE CROWN. (HA!)\""],
	["CARVED IN THE STONE: \"THE WALLS LIE. ONLY LIGHT TELLS THE TRUTH.\"", "SCRATCHED HERE: \"MAP EVERY SQUARE OR YOU WILL WANDER FOREVER.\""],
	["WRITTEN IN SOOT: \"THE FLOOR TURNS UNDER YOUR FEET.\"", "A WARNING: \"HE WAITS BELOW THE FOURTH STAIR.\""],
	["LETTERS OF FIRE: \"WERDNA SLEEPS WHERE THE MAZE ENDS.\"", "A CLAW-MARKED SIGN: \"NO ONE RUNS FROM THE ARCHMAGE.\""],
]
## The Drunken Slumber rooms: [name, hit points per week, gold per week]
const ROOMS := [["STABLES", 0, 0], ["COMMON ROOM", 1, 10], ["SHARED ROOM", 3, 50], ["PRIVATE ROOM", 7, 200], ["KING'S SUITE", 10, 500]]


func alignments_for(race: String) -> Array:
	return RACE_ALIGNMENTS.get(race, ALIGNMENTS)


func spells_at(school: String, lvl: int) -> Array:
	var out := []
	for n in SPELLS:
		if SPELLS[n][0] == school and SPELLS[n][1] == lvl:
			out.append(n)
	return out


func xp_needed(cls_name: String, lvl: int) -> int:
	return int(round(CLASSES[cls_name]["xp"] * pow(1.72, lvl - 1)))


## The names of the portraits for one sex, as Character.portrait stores them.
func portraits(sex: String) -> Array:
	var names := []
	for i in PORTRAIT_COUNTS[sex]:
		names.append("%s_%d" % [sex.to_lower(), i + 1])
	return names
