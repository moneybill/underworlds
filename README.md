# Underworlds: Descent into Darkness

A first-person, turn-based dungeon crawler in the style of the classic Wizardry games, built in **Godot 4.7.2** with GDScript.

Create a party at the Proving Grounds, gather it at the Red Dragon Inn, outfit it at the Broken Anvil, and descend four levels of the Maze to take the amulet back from the wizard Werdna.

## Getting started

1. Clone the repo, for example into `C:\projects\underworlds`:
   ```
   git clone https://github.com/moneybill/underworlds C:\projects\underworlds
   ```
2. Open Godot 4.7.2, choose **Import**, and select `project.godot` in that folder.
3. Press **F5** to play.

## Start-up

The game opens on the company screen (set the name in `COMPANY_NAME` in `scripts/ui/menu/splash_scene.gd`), then the title screen. Any click or tap skips the company screen. A tap on the title screen brings up its buttons: Venture Onwards returns to where the last save left the party, or the castle in a new game, and Options opens the options panel.

## The town

The Castle screen is a painted map of the town. Click a building to enter it: the Red Dragon Inn (the tavern), the Drunken Slumber, the Broken Anvil (the forge), the Cathedral of Rebirth, the Proving Grounds, the Maze (the skull cave) and the Edge of Town (the south gate, which also has Exit Game). Buildings that need a party are greyed out until you have one. The roster holds up to 16 characters (`MAX_ROSTER` in `scripts/core/game.gd`). New characters choose male or female and a portrait, shown when they are inspected and changeable at the Proving Grounds. The race screen is mouse only, and clicking a race opens a popup of its base statistics with an (i) explaining each. Outlines and plate positions are in `SPOTS` in `scripts/screens/town_map.gd`.

## Controls

The game is played entirely with the mouse or touch: click or tap a button. In the Maze, the on-screen arrows step forward and turn. Character creation spends bonus points with the `+` and `-` buttons. The keyboard is only used to type into text boxes, such as a new character's name, confirmed with the OK button.

## What's in it

- **Characters:** 5 races, 3 alignments, 8 classes (Fighter, Mage, Priest, Thief, Bishop, Samurai, Lord, Ninja) with the manual's entry requirements, random bonus points, class changes, aging, and level-ups at the Inn.
- **Magic:** 34 mage and priest spells across levels 1–5, spell points per level (max 9), and the slower spell schedules for Bishops, Samurai and Lords.
- **The Castle:** the Red Dragon Inn (alignment-checked parties, divvy gold), the Broken Anvil (buy, sell at half price, uncurse, identify, limited stock), both showing the party's level, class, equipment and gold on portrait cards. Click a card to select that member, then act for them. A portrait another character already has can't be chosen, Temple of Cant (raising can fail into ashes, then lost), Adventurer's Inn (five room types).
- **Equipment:** class restrictions, cursed items, alignment-bound weapons, unidentified finds, rods and potions with charges.
- **The Maze:** four 20×20 levels with doors, secret doors (revealed by MILWA and LOMILWA), darkness, spinners, graffiti and stairs. Layouts are generated from a fixed seed, so they are the same every game and can be mapped on graph paper.
- **Combat:** fought over the Maze view, with up to four monster groups in a 2x2 grid; click a group's card to target it, and a round plays one attack at a time, with each result on the creature and any sound together (Options > Fast Combat Results speeds this up). The party shows as two rows of three portraits, with each character's options under theirs: Fight, Backstab (thieves), Cast Spell (mages, priests, bishops), Dispel (priests, bishops) Use Item (with a magic item) and Parry, plus Run and Back for the whole party. Only the front row fights and takes melee hits, and it can only reach the first two groups; surprises, ambushes, friendly encounters, unidentified monsters, experience split among survivors.
- **Treasure chests:** seven trap types; disarming means typing the trap's name.
- **Losing and saving:** wiped-out parties stay where they fell in the Maze until rescued with INSPECT AREA. The game saves to `user://underworlds_save.json` as you play, and closing the window mid-expedition saves and resumes in the Maze or camp. A fight in progress is not saved.

## Project layout

```
project.godot            Godot 4.7 project (GL Compatibility renderer)
scenes/splash.tscn       Company screen, where the game boots
scenes/title.tscn        Title screen
scenes/main.tscn         The game; its UI is built in code
scripts/data/data.gd     Autoload "Data": races, classes, spells, items, monsters, traps
scripts/core/            Character, dice, and the "Game" autoload (state + save/load)
scripts/maze/            Level data, seeded generator, the first-person view, and the 3D Maze with its torchlight
scripts/combat/          Battle rules and shared spell effects
scripts/screens/         Town, character, maze and combat screens
assets/images/title.webp      The title screen painting (`title_scene.gd`)
assets/images/town_map.webp   The town painting (the map in `town_map.gd`)
assets/images/tavern.webp     The Red Dragon Inn painting (`place_image` in `main.gd`)
assets/images/boltac.webp     The Broken Anvil painting (`place_image` in `main.gd`)
assets/images/inn.webp        The Drunken Slumber painting (`place_image` in `main.gd`)
assets/images/temple.webp     The Cathedral of Rebirth painting (`place_image` in `main.gd`)
assets/images/training.webp   The Proving Grounds painting (`place_image` in `main.gd`)
assets/images/buttons/        Button art: small, medium, large, xlarge, yes and no, each `_normal` and `_pressed`
assets/images/maze/           Maze walls, doors, floors and ceilings (listed at the top of `maze_world.gd`). Wall art is 16:9 shown on 4:3 walls, so paint round shapes about a third wider than tall
assets/images/portraits/      Character portraits (counted in `PORTRAIT_COUNTS` in `data.gd`)
assets/models/fantasy_props/  94 3D props by Quaternius (Fantasy Props MegaKit, CC0), glTF
scripts/ui/main.gd       Layout and the menu system
scripts/ui/ui_style.gd   Palette, fonts and theme
scripts/ui/menu/         Company screen and title screen
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

## Fire effects

The campfire and brazier flames come from the **Vefects Free Fire VFX** pack, which needs the Forward+ renderer. Its licence forbids uploading it to public repositories, so `/Vefects/` is in `.gitignore`. On a fresh clone, copy the pack's `Vefects` folder into the project root; without it, camp shows a simple drawn flame and braziers glow without flames.

## Testing switches

The **Monsters**, **God mode** and **To town** buttons at the top of every screen are for testing. With monsters off no fights start in the Maze; in god mode the party takes no damage or harmful conditions; both reset when the game closes. To town brings the party straight home from the Maze, even mid-fight, as if it had walked out.
