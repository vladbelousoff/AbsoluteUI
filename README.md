# AbsoluteUI

<p align="center"><img src=".github/logo.svg" width="128" alt="AbsoluteUI logo"></p>

A cleaner, more modern look for the default UI. Works on WoW Forever and TBC
Anniversary.

It doesn't replace Blizzard's frames, it reskins them. Everything stays where
Edit Mode puts it, and clicks, targeting, menus and keybinds work like in the
default UI, combat included.

## What's in it

- Player, target, focus and pet frames with 3D portraits (or 2D / class
  icons), absorbs, a damage trail on the health bar and a low health warning.
  Elites, rares and bosses get a colored portrait border.
- Small target of target frames under target and focus
- Target and focus buffs/debuffs, colored by debuff type, your own a bit bigger
- Castbars with spell icon and latency. Yours can also sit above the player
  frame.
- Action bars, bag bar and micro menu. Micro menu and bags can be hidden.
- XP/rep bars and swing timers in the castbar style
- Skins for tooltips, menus, quest tracker, quest and gossip windows, map and
  quest log, loot, bags ([Bagnon](https://www.curseforge.com/wow/addons/bagnon)
  too), character window, spellbook and talents, and the damage meter
- A bunch of bar textures and fonts to pick from

Swing timers and the damage meter are Forever only, TBC doesn't have them. On
TBC the micro menu also keeps Blizzard's buttons.

## Install

Grab the latest release and drop the `AbsoluteUI` folder into
`Interface/AddOns` (`_classic_beta_` for Forever, `_anniversary_` for TBC).
Same zip for both.

## Usage

`/aui` opens the settings. They're also in the AddOns compartment on the
minimap and under Options > AddOns > AbsoluteUI. Positions and sizes are done
in Edit Mode, same as the default UI.

- `/aui` - settings
- `/aui help` - list commands
- `/aui debug` - module state, missing frames and caught errors
- `/aui reset` - back to default settings

## Other addons

Bagnon gets an AbsoluteUI skin unless you picked another one in Bagnon. If
another addon already skins something, turn that skin off in the settings.

## Bugs

Open an issue with the output of `/aui debug` and the Lua error if there is
one (BugSack makes that easy).

## Development

No libs, no build step. `luacheck .` for linting.

One TOC for both clients. `NS.flavor` is `"modern"` on Forever and
`"classic"` on TBC; modules and settings that only exist on one of them have a
`flavor` field. The TBC versions of windows that are completely different
live in `Classic/`.

To release, bump `## Version:` in the TOC, add a changelog entry and push to
main. CI tags it and the [BigWigs packager](https://github.com/BigWigsMods/packager)
does the rest. Pushing a tag by hand works too.

## Credits

Fonts in `Media/Fonts`, each with its own license: PT Sans Narrow, Fira Sans
Condensed, Ubuntu Condensed, Play, Russo One and Philosopher.

## License

MIT, see [LICENSE](LICENSE). The fonts keep their own licenses.
