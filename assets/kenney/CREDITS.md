# Third-party art credit

The 3D cars and trackside props in `assets/kenney/` (`.glb` models) come from
two packs by Kenney (https://kenney.nl):

- Car Kit — `race.glb`, `race-future.glb`, `sedan-sports.glb`,
  `hatchback-sports.glb`, `cone.glb`, `debris-tire.glb`
- Racing Kit — `raceCarWhite.glb`, `raceCarGreen.glb`, `raceCarOrange.glb`,
  `raceCarRed.glb`, `grandStand.glb`, `billboard.glb`, `fenceStraight.glb`,
  `lightPostModern.glb`, `overheadLights.glb`, `tent.glb`, `treeSmall.glb`,
  `treeLarge.glb`, `flagCheckers.glb`, `roadBump.glb`, `pylon.glb`

Both packs are released under Creative Commons Zero (CC0,
https://creativecommons.org/publicdomain/zero/1.0/): free for personal,
educational, and commercial use, no attribution required. Credited here
anyway — thanks, Kenney!

Local changes to the shipped files: the car-kit `.glb` files had their
external `Textures/colormap.png` reference embedded into the binary chunk
so each model is a single self-contained file. The palette texture itself
is kept at `assets/kenney/Textures/colormap.png` for reference. Full
license texts: `assets/kenney/LICENSE-car-kit.txt` and
`assets/kenney/LICENSE-racing-kit.txt`.
