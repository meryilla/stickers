# Stickers
An AFBaseExpansion script which allows players to pick from a selection of animated sprites and then send them to the HUD of another player.

Simply say `stickers` in chat and this will bring up the menu.

I originally added this to S/v/en Co-op as part of an April Fools joke. It's pretty stupid but plenty of servers run equally annoying plugins so I'm sure someone out there will like this.

## Setup

This script requires Zode's AFBase plugin in order to work: https://github.com/Zode/AFBase

1. Download the latest release 
2. Extract to either `svencoop_addons/` or `svencoop/`
3. Find your AFBaseExpansions.as script and make the following changes:
- At top of the file add `#include "AFBaseExpansions/stickers"`
- Within the AFBaseCallExpansions function add `Stickers_Call();` 
4. Add your own animated sprites and adjust the `stickersprites.txt` accordingly (details below)

There are an assortment of random sprites in this repo ready to use but you will probably want to replace these with something else. 

## Adding Sprites

To add your own sprites you will need to update the `stickersprites.txt` in `/plugins/AFBaseExpansions`. Each sprite should have it's own entry in the following format:

`<path> <number_of_frames> <framerate>`

e.g.

`stickers/cirno 7 20`

This would add `cirno.spr` found in `sprites/stickers/cirno.spr`, set the number of frames to display as `7` with an fps of `20`.

Sprites are picked up from this file and precached upon every mapchange.

Some things to bear in mind when adding animated sprites:

* Due to game limitations the max number of frames supported is 255. An entry with a value higher than this will not display correctly
* Try to keep the size of the sprite down, prefably below 300x on each dimension. Unless you are deliberately trying to piss players off
* More frames = larger sprite size. e.g. `kufufu.spr` that comes as an example is 255 frames and is ~12mb in size. Players won't appreciate having to download a load of these.