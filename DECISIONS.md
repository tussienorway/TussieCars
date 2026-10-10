# Decisions

## Custom car model

Godot physics bodies were not used. A small integrator is easier to test without a scene tree, and the substeps keep cars from tunneling through barriers. Fun and stable numbers live in `data/balance.json`.

## Pre-rotated sprites

Sixteen frames, frame 0 facing +X. Runtime rotation of one sprite blurred the pixel art.

## Baked ground, live scenery

The road is painted into a PNG by `tools/generate_tracks.py`. Palms, rocks, and lamps are sprites so they can sort with the cars. A final centerline stamp stops barriers from landing on the racing line.

## Menus in code

`UiKit` and `App` build every screen. One theme, fewer scene files, and the same layout on desktop and touch.

## Career cannot soft-lock

Three sponsored entries waive the fee. After that, a scholarship tops the wallet up to the fee. A wrecked car is patched enough to race. Upgrades still cost real prize money.

## AI catch-up

Below Ace, a car that falls far behind gets a small speed bump, and rival speed rises slightly as the player buys engine and gearbox. Ace does not get the catch-up. Rivals still use the same steering and collision code as the player.

## Weapons wait for the green flag

Missiles and mines are locked for the first 2.4 seconds so the grid does not erase itself. AI fire chance is scaled by frame time, so they do not shoot on every cooldown while someone sits in the cone.

## Two-player

Local split-screen replaces the last rival with a guest. The guest does not earn championship points or money. Only player 1 is written into the career.

## Exhibition

Exhibition races do not change money or points.

## Android without Gradle

The APK is packed into the official Godot template and signed locally. That avoids a Gradle download and still produces an arm64 package.

## Nitro

Nitro is a short throttle burst, not a separate physics body. Holding it raises acceleration and the speed cap, cuts grip slightly, and drains a tank that refills on its own. An orange pickup adds charge. Rivals use it on clear straights after the field has spread out. Shift, N, gamepad Y, and the touch BOOST button all map to the same action.

## Drift and slipstream

Hotshot Racing charges a boost by drifting and by sitting in another car's wake. TussieCars uses the same two ideas with its own numbers. Drift is a held action (Space, M, left-stick click, or the touch button): above a speed threshold it loosens the rear, yaws harder, and fills the nitro tank. Slipstream is automatic when a fast car is directly ahead in a narrow lane. It raises the speed cap a little, cuts drag, and also fills the tank. Neither effect copies that game's cars, tracks, or UI.

## Art

Pixel art and chiptune are generated in `tools/generate_assets.py`. Cars are drawn large, lit from the north-west, and scaled back down so the silhouette stays the same size with smoother shading. Track edges, rumble ticks, nitro pads, and barrier contact shadows are baked by `tools/generate_tracks.py`. The race view adds a soft shadow, speed streaks, a warm or cool grade, and a vignette. The font is Silkscreen (OFL). Nothing is taken from Super Cars II or from later arcade racers.

## 3D presentation over the 2D sim

The 1.4.0 race view is fully 3D (procedural ArrayMesh circuits, primitive-built low-poly cars, chase cameras, sun shadows), but RaceSim still integrates in 2D and X/Y maps to world X/Z. That keeps physics, AI, weapons, checkpoints, netcode snapshots, and all 136 tests valid without touching gameplay. The approach follows public Godot guidance: one ArrayMesh quad per grid cell with vertex colors (docs: ArrayMesh procedural geometry), and simple arcade presentation instead of VehicleBody3D suspension physics (KidsCanCode arcade-car recipe), since the sim already drives arcade-correct.

## Art in 3D

Cars are composed from boxes, cylinders, and spheres with shared StandardMaterial3D paint, so the whole field uses a handful of materials. Circuits reuse the tile grid: asphalt, kerbs, sand, water, and walls become colored, height-offset quads and merged boxes. Skid marks are fading ground quads, smoke and sparks are CPUParticles3D (safe on the GL Compatibility renderer used for Android), and the HUD, minimap, pause menu, and touch controls stay 2D CanvasLayers over the 3D view.

## Night races and the countdown fix

Industrial circuits run a night look: dark sky, dim blue sun, lamp glow, neon underglow on every car, and a headlight beam on player cars. The gantry carries three start bulbs that burn red through the countdown and flip green at the gun. A floating marker shows your car, drift smoke takes the color of the surface you slide on, and finishing (or wrecking) your car pops confetti once. The countdown digit once failed to rasterize from a zero-size centered label rect, so it now uses a full-rect centered label.

## Boost pads and guard rails

Every circuit now has two cyan boost strips painted across the road. They fill nitro fast and add a small kick, which rewards line choice without changing the sim's structure. The 3D view renders them as pulsing emissive quads. Guard rails (red/white posts with a top bar) line every road edge that is not already a wall, built into one merged mesh. AI drivers got a small per-difficulty steering wobble (none on Ace) so the field feels human; lap-completion tests still pass.

## One-tap WiFi multiplayer

Joining on the same WiFi is now: host taps QUICK HOST, guests tap the lobby name. Discovery beacons go out the instant hosting starts, the lobby list shows JOIN buttons with track and player counts, a Rescan button covers networks that drop broadcast packets, and name/paint/track/port persist in settings. Manual IP join stays as the fallback for the internet and stubborn guest networks.
