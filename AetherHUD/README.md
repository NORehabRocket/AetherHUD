# AetherHUD 2.1

A complete Aion-styled interface for **Azeroth Survivors**: navy glass panels, aether-cyan
glints, gold corner brackets, round portraits in gold bezels, diamond gems and winged
banners. It replaces the game's run HUD, the stock 1.12 frames and the remaining pop-up
text, so everything you see comes from AetherHUD.

## Install

* **Windows / Linux:** copy the `AetherHUD` folder to `benilla-config/AddOns/` next to
  `AzerothSurvivors.exe`, so the file sits at `benilla-config/AddOns/AetherHUD/AetherHUD.toc`.
* **Browser:** Options → AddOns → install `AetherHUD.zip`.

It loads at the next world entry. Turn off any other full UI (PhantomUI, SurvivorsDragonUi)
in the AddOns list; if one is still on, AetherHUD says so in chat.

## The run

| Frame | Where | Replaces |
|---|---|---|
| Run clock: zone, clock, a boss timeline (a diamond for each boss at the time it comes: grey = to come, red glow = alive now, dim = slain, gold = the final boss) and the next boss's countdown, red in its last 10 s. Hover it for the list | top centre | the game's clock |
| Boss bars: every boss alive and every awake guardian, with health, an ENRAGED glow and debuffs counting down. Click one to target it | under the clock | the game's boss bars |
| Banners: every announcement the game makes, and new zones, as winged notices | centre | the game's banners, stock zone text |
| System messages: errors and notices ("Not enough gold...") as a calm line that fades | under the banners | the stock red/yellow error text, raid warnings |
| Run tally: kills, gold, next cache price (red while you can't afford it), enemies, elites, rerolls | right | the game's tally |
| Lairs: each guardian asleep, awake (with health) or gone, and when its lair refills | right | (new) |
| Combat meter: damage, healing, last boss fight, damage taken | bottom right | the game's meter |
| Enemy plates: a slim glass bar under each enemy's name (elites gold, guardians violet, bosses red; your target gets a gold gem). Normal enemies at full health stay hidden until hit | over the enemies | the client's nameplates |
| Combat numbers: your hits over the enemy that took them in the spell school's colour, crits in gold, damage over time small, pets silver; damage you take and healing beside the hero | over the enemies | the client's damage numbers |
| Loot cards: each item you receive slides in with its icon, quality colour and the game's note ("New in your collection!") | left, above the chat | the game's loot notice |
| Level Up button: stored level-ups, opened one by one | right of the experience bar | the game's Level Up! button |
| Revive bar: a party revive in progress, either way | centre | the game's revive bar |
| Low-health glow: the screen edges glow red below 35% health | full screen | (new) |

## You and your party

| Frame | Where | Replaces |
|---|---|---|
| Hero frame: portrait, level gem, health with shield and damage trail, lives, buffs and debuffs (right-click a buff to cancel it). Hover for your run stats | top left | stock player frame and buffs |
| Pet frame | beside the hero | stock pet frame |
| Party frames: class-coloured names, health, down and offline | left | stock party frames |
| Target frame: what the target is to the run, its real health, its debuffs; another hero gets an Inspect button | above the skill bar | stock target frame |

Click any of these to target that unit, right-click it for the game's own unit menu, the
one the stock frames open: whisper, invite, trade, follow, duel, inspect, raid marks, loot
rules, promote, leave party and the rest.
| Skill bar: your six spells and racial with cooldowns and rank gems, talent and jewelry clocks and summons above it, and four buttons: Character, Talents, Inventory, Game menu | bottom centre | stock action bar (hidden; keybinds still work) |
| Experience bar | bottom | stock XP bar |

## Windows

* **Inventory (B):** every bag in one grid, items rimmed in their quality colour, with
  stacks, cooldowns and locked items dimmed; your equipped bags and money underneath.
  Left-click picks up or drops, right-click uses or equips (or sells at a merchant),
  Shift-click links. Bank bags keep their stock windows.
* **Character (C):** your gear in two columns and a weapon row around a large portrait,
  health, damage, haste and crit as headline tiles, and every number of the run on the
  right (offense, defense, utility), with what your gear adds in green. Drag gear on and
  off as usual. The other character tabs stay stock.
* **Inspect:** another hero's gear in the same shape as your character window, rimmed in
  its quality colour, with their name, guild, level, race and class, health, how much gear
  they wear, and each item listed by name on the right. A party member also shows what they
  did this run: damage, per second, their share of the party's and their top spell. Opens
  from the unit menu's Inspect, the target frame's button, or anything else that inspects.
  Hover an item for its tooltip, Shift-click links it, Ctrl-click tries it on. Inspecting
  yourself opens your character window.
* **Chat:** the stock windows in a glass panel, flat tabs (the open one in gold), a glass
  input line, Roboto text, the mouse wheel scrolls (Shift jumps to the top or bottom).
* **Minimap:** round, in a gold ring with a north gem; zone, coordinates and time on a
  plate beneath (a long zone name is shortened); the mouse wheel zooms. The map itself stays
  the game's, with your arrow and its icons; AetherHUD moves its whole cluster.
* **Tooltips, dialogs, the game menu and right-click menus** wear the same glass. A
  tooltip's edge takes the colour of its first line (item quality, enemy reaction), and
  enemies say what they are to the run.

Drag any window by its title. Escape closes it.

## What stays the game's

* The **build** row (spells and jewelry): the addon API has no jewelry data, so the skill
  bar can't stand in for all of it. Tick "Also hide the game's build row" in the options
  if you only want the skill bar.
* The **minimap flag** on the nearest guardian.
* The talent window (the game draws it), the world map and NPC windows (merchant, bank,
  mail), which a survivors run rarely needs.

Every part of the game's HUD that AetherHUD hides, and every client setting it changes
(native damage numbers off, damage over time in the combat log, the combat log's range
raised to 200 yards), comes back when you log out. With the addon disabled the game is as
it was the next time you play. Plates only exist while the client shows nameplates:
AetherHUD turns them on, and `V` toggles them as usual.

## Commands

* `/aether` (or `/ahud`) opens the options: every part on or off, HUD size, number size,
  meter rows, whether full-health enemies get plates, and whether damage taken and
  healing show as numbers. It also has the game's own run settings (store level-ups for
  the Level Up button, buy caches only by right-clicking them, no spell effects; they are
  the same settings the game's Options window keeps) and a button to the game's Options.
* `/aether unlock` lets you drag frames, resize one with the mouse wheel, or right-click
  it to reset it. `/aether lock` when done.
* `/aether demo` fills every frame with a sample run (with sample combat numbers, banners
  and a loot card), so you can see and arrange the HUD outside a run.
* `/aether scale 0.9` sets the overall size. `/aether reset` restores the default layout.

Switching a part on or off takes effect after a UI reload; the options window has a
button for it.

## Credits

By NORehabRocket, MIT license: https://github.com/NORehabRocket/AetherHUD
Roboto font © Google, Apache License 2.0 (`media/Roboto-LICENSE.txt`).
