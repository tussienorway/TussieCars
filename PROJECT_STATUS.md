# Project status

**Status: playable, version 3.1.0, with VR (Meta Quest 3 and PC VR), a podium ceremony, and a How to Play guide.** Pro-built Kenney cars and trackside props, bloom lighting, Forward+ on desktop with automatic Compatibility fallback, start-line grandstands and billboards, speed-sensitive chase camera, Daily Duel (seeded daily race with ghost rival, mutators, and streaks), one-tap WiFi multiplayer, sixteen original circuits in four championships, boost pads, drift, slipstream, online multiplayer for up to 4 drivers, and a hardened Android release are in. Limits are still in `KNOWN_ISSUES.md`.

TussieCars is a playable Godot 4.7.2 game with low-poly 3D cars, procedural 3D circuits, chase cameras, and dynamic shadows. The proven 2D simulation (driving, AI, weapons, checkpoints) runs underneath unchanged, so every race, championship, and netcode path behaves exactly as tested. Sixteen championship circuits in three environments load and start. Windows and Android packages are in `releases/`. From the main menu, Multiplayer hosts or joins a host-authoritative net race over LAN (automatic discovery) or internet (direct IP), with the grid filled to 6 cars by AI.

Verified on 10 October 2026:

- Headless suite: `godot --headless --path /workspace -- --test` — 297 passed, 0 failed.
- Native smoke under xvfb: main menu, championships, garage, settings, a 3D harbor race with chase cam, nitro flame, and split-screen 3D.
- Kenney era: the four bodies are pro-built models (F1-style field, olive Mule and violet Fang livery-tinted, procedural builder kept as fallback), every start line has a grandstand, billboards, checkered flags, tire stacks, and cones, industrial tracks use modern lamp posts, pickups are smaller and brighter, bloom is on, and the chase camera widens with speed and nitro.
- Roads are about 30% wider, guard rails are solid walls, and hitting them costs hull in proportion to speed (a full-speed head-on hit costs about 29 HP). AI weapons are calmer, so a typical race now ends with few or no wrecks. Exhibition opens without a career and lists all 16 circuits.
- 2.9.0: roads widened again (54 px tiles), harder wall hits plus scrape wear, softer wall damage for AI, stuck recovery for AI-driven player cars, two-column Exhibition track picker, touch-drag scrolling in menus. Every circuit verified with `-- --probe`.
- 3.1.0: after the finish orbit, local races cut to a podium (top three cars on gold, silver, and bronze blocks, name boards, Tussie, confetti, a "YOU WIN!" callout) for 3.4 s before the results. Net, split-screen, and VR races skip it. The main menu has a How to Play page, and `BRUKSANVISNING.md` is a full Norwegian user manual.
- 3.0.0 VR: an OpenXR build for Meta Quest (`releases/quest/TussieCars-Quest.apk`, Meta vendor plugin, Gradle build) and PC VR via `TussieCars-VR.bat`. Menus run on a screen in a 3D showroom with laser pointers, races use a chase or roof cam with a dashboard HUD, controller driving and haptics, and the pause menu is clicked with the lasers. On standalone Quest the race drops sun shadows and glow and uses 2x MSAA; physics ticks match the 72 Hz display. Verified with the `--vr-sim` smoke and 29 new tests. It has not been run on a real headset.
- Tussie the cat, a red-and-white long-haired mascot, sits by every start grid and watches your car; it is also on the main menu and in the credits.
- Rival Bounty: each career race names a rival from the standings. Beating them pays 40% of the winner's prize on top of the purse. The rival is marked in 3D, on the minimap, and on the HUD.
- Cinematic finish: on crossing the line, letterbox bars slide in, the camera orbits the car, and place and time are called out. Results wait for the orbit (3.2 s) in local races; net timing is unchanged. In rain every car throws spray, and headlamps are on for all cars at night and in rain.
- Desktop renders Forward+ with ambient occlusion and drops to Compatibility automatically where Vulkan/Direct3D 12 is missing (verified under Wine); Android stays on Compatibility via the mobile renderer override.
- Windows exe for 2.9.0 is exported as a PE32+ binary and packed into `releases/windows/TussieCars-windows.zip`.
- Android ARM64 APK 2.9.0 (versionCode 20) exported and signed, with internet/network-state permissions, adaptive icons, and sensor-landscape orientation verified in the manifest. Not installed on a device or emulator.

The acceptance bar in the brief is met except Android play on hardware, which could not be run here and is recorded as a limitation rather than a pass.
