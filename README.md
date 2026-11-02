# Underworlds 2: Proving Grounds of the Mad Overlord

A first-person, turn-based dungeon crawler in the style of the classic Wizardry games, built in **Godot 4.7.2** with GDScript.

Create a party at the Training Grounds, gather it at Gilgamesh's Tavern, outfit it at Boltac's Trading Post, and descend four levels of the Maze to take the amulet back from the wizard Werdna.

## Getting started

1. Clone the repo, for example into `C:\projects\underworlds`:
   ```
   git clone https://github.com/moneybill/underworlds C:\projects\underworlds
   ```
2. Open Godot 4.7.2, choose **Import**, and select `project.godot` in that folder.
3. Press **F5** to play.

## Controls

Every menu works like the original manual: press the letter before the `)` (or click the button).

| Where | Keys |
| --- | --- |
| Menus | The option's letter or number; `Enter` picks the highlighted default, `Esc` backs out |
| Maze | `W` / `↑` step forward, `A` / `←` turn left, `D` / `→` turn right, `X` / `↓` about-face |
| Maze | `C` camp, `S` status, `I` inspect area (find lost parties), `M` map notes, `Q` quit expedition |
| Character creation | `↑` / `↓` choose a statistic, `+` / `-` or `←` / `→` spend bonus points |

## What's in it

- **Characters:** 5 races, 3 alignments, 8 classes (Fighter, Mage, Priest, Thief, Bishop, Samurai, Lord, Ninja) with the manual's entry requirements, random bonus points, class changes, aging, and level-ups at the Inn.
- **Magic:** 34 mage and priest spells across levels 1–5, spell points per level (max 9), and the slower spell schedules for Bishops, Samurai and Lords.
- **The Castle:** Tavern (alignment-checked parties, divvy gold), Boltac's (buy, sell at half price, uncurse, identify, limited stock), Temple of Cant (raising can fail into ashes, then lost), Adventurer's Inn (five room types).
- **Equipment:** class restrictions, cursed items, alignment-bound weapons, unidentified finds, rods and potions with charges.
- **The Maze:** four 20×20 levels with doors, secret doors (revealed by MILWA and LOMILWA), darkness, spinners, graffiti and stairs. Layouts are generated from a fixed seed, so they are the same every game and can be mapped on graph paper.
- **Combat:** Fight, Parry, Dispell, Spell, Use, Run and Take Back; only the first three party slots fight and take melee hits; surprises, ambushes, friendly encounters, unidentified monsters, experience split among survivors.
- **Treasure chests:** seven trap types; disarming means typing the trap's name.
- **Losing and saving:** wiped-out or quit parties stay OUT in the Maze until rescued with INSPECT AREA or restarted from Utilities. The game saves to `user://underworlds2_save.json` as you play.

## Project layout

```
project.godot            Godot 4.7 project (GL Compatibility renderer)
scenes/main.tscn         The only scene; the UI is built in code
scripts/data/data.gd     Autoload "Data": races, classes, spells, items, monsters, traps
scripts/core/            Character, dice, and the "Game" autoload (state + save/load)
scripts/maze/            Level data, seeded generator, and the drawn first-person view
scripts/combat/          Battle rules and shared spell effects
scripts/screens/         Town, character, maze and combat screens
scripts/ui/main.gd       Layout, theme, and the lettered-menu system
tools/selftest.gd        Headless smoke test
```

Game data lives in plain dictionaries in `scripts/data/data.gd`, so balancing a monster or adding an item is a one-line change. To get a different dungeon, change `SEED_BASE` in `scripts/maze/maze_gen.gd`.

## Fonts

The game uses system fonts by default. For the intended look, add these free Google Fonts to the `fonts/` folder and they are picked up automatically:

- `fonts/VT323-Regular.ttf` for menus and text
- `fonts/IMFellEnglishSC-Regular.ttf` for titles

## Testing

The smoke test creates a party, drives every town screen, plays a random expedition, fights Werdna, and checks save/load. It uses its own save file.

```
godot --headless --path . --script res://tools/selftest.gd
```

The exit code is the number of failed checks.
