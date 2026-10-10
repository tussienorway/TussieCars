# Architecture

Godot 4.7.2, GDScript, 3D presentation over a 2D sim, GL Compatibility. Viewport 1280×720, canvas stretch, landscape on handheld. The project root is the Godot project.

## Layout

| Path | Role |
| --- | --- |
| `src/sim/` | Pure race simulation. No nodes. |
| `src/race/race_view.gd` | Sprites, camera, HUD, touch, pause. |
| `src/ui/` | Menus built in code. |
| `src/autoload/` | Settings, career, audio. |
| `data/` | JSON balance, roster, championships, tracks. |
| `assets/` | Generated art and audio. |
| `tests/suite.gd` | Headless assertions, started with `--test`. |

Autoloads, in order: Settings, Game, AudioDirector. They stay active while the tree is paused.

## Simulation

Cars are not physics bodies. `CarSim.integrate` updates heading and velocity. `CarSim.move` steps the hull and slides off blocking tiles. `CarSim.separate` pushes overlapping cars apart. Drag uses an exponential decay so a long frame cannot reverse the car.

Heading 0 is +X. Sprites are 16 pre-rotated frames. The body is not rotated at runtime.

Tracks are JSON. Each row is a string of tiles (32 px). `A` asphalt, `D` dirt, `S` sand, `C` curb, `O` oil, `W` water, `G` ground, `B` barrier, `F` finish paint. Waypoints, checkpoint segments, grid slots, pickups, and decor live in the same file. `TrackValidator` checks size, checkpoint count, and that the centerline is reachable.

`RaceSim` owns the countdown, lap gates, AI, shots, mines, and pickups. Crossing a checkpoint counts only if it is the next one and the car travels with the circuit. The finish segment is index 0 and is not armed at the start. Nitro, drift, and slipstream are flags on the same integrate step. Drift loosens grip and fills the tank. Slipstream raises the speed cap when a rival is directly ahead.

## Career

`Game` stores `user://career.json` (version 1). Tests point `career_path` at `user://test_career.json`. Money, upgrades, ammo, hull, and championship points are in that file. Settings live in `user://settings.json`.

## Presentation

The ground is a baked PNG with edge lines, rumble ticks, nitro pads, and darker ground beside barriers. Cars are filtered smooth and lit from one direction. A boost flame, soft shadow, speed streaks, and a pool of skid quads are drawn in the race view. A full-screen grade and vignette sit under the HUD. The solo camera follows the player with a little lookahead and eases out while nitro is lit. Two-player mode turns that camera off and renders the same world through two sub-viewports.

Menus are a `CanvasLayer` so the camera does not drag them. Button callbacks are deferred so a screen can free itself.

## Audio

WAV streams. Music and the engine loop. SFX uses a small pool. Buses Music and SFX are created at runtime.

## Export

`export_presets.cfg` builds `releases/windows/TussieCars.exe` (embedded pck, x86_64) and `releases/android/TussieCars.apk` (arm64-v8a, Gradle off, signed with the local release keystore).
