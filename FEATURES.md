# Gear Set Colors: features

Everything the addon does, option by option. The settings are in **Options > AddOns > Gear Set Colors**, also opened with `/gsc` or from the addon compartment (the button under the minimap that lists your addons).

## Marking set items in your bags

Every item in your bags that belongs to one of your equipment sets is marked with that set's colour. The sets are the ones you save in the Equipment Manager, in the Character window.

- **Items are recognised by their place in your bags**, as the Equipment Manager itself records them. Two identical rings in two different sets each get their own set's colour.
- **The marks follow your bags:** they update when items move, when you equip a set or a piece of gear, and when you save, change or delete a set.
- **Blizzard's bags**, one window per bag or all bags combined. Bag replacement addons (Bagnon, Baganator, ArkInventory...) draw their own bag windows, which Gear Set Colors doesn't mark. The bank isn't marked either.

## How items are marked

Under "How to mark items", tick any combination:

| Option | Default | What it draws |
|---|---|---|
| Coloured border | On | A coloured frame around the item's slot. |
| Coloured tint over the icon | On | A light wash of the set's colour over the item's icon. |
| Small square per set in the top-right corner | Off | One small square per set, down the slot's top-right corner, up to four. |

**An item in several sets** shows all of them: its border alternates between their colours (top, right, bottom, left), the corner squares show one square per set, and the tint takes the first set's colour.

## Set colours

- **Each set gets a colour by itself** the first time the addon sees it: the first colour of this list that no other set uses yet: red, cyan, yellow, pink, orange, lime, white, brown. Green, blue and purple are left out because they look like the item quality borders.
- **Change a set's colour** on the options page: click the colour box next to its name, pick a colour, and the bags update as you pick. Cancel puts the old colour back.
- **Stop marking a set:** untick "Mark its items" next to it. Its items are no longer marked, and its colour is kept for later.
- **Colours go by set name and are shared by all your characters.** A "Tank" set on one character and a "Tank" set on another have the same colour. The options page lists the sets of the character you are playing.

## In the Equipment Manager

The Character window's Equipment Manager shows a small colour square on the top-left corner of each set's icon, in that set's colour. Click it to change the colour. The square is faded for a set whose items aren't marked.

## Commands

| Command | What it does |
|---|---|
| `/gsc` | Opens the options |

Settings are saved in `WTF\Account\<account>\SavedVariables\GearSetColors.lua`, shared by all your characters.
