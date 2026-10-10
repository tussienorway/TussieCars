# Test results

Date: 10 October 2026. Godot 4.7.2.stable.official.ed1daf0bf. Game version 3.1.0.

## Headless suite

Command:

```bash
godot --headless --path /workspace -- --test
```

Result: **297 passed, 0 failed.** Exit code 0. The same suite passes inside the exported Windows exe under Wine.

The suite checks:

- Balance, four vehicles, four championships, the driver roster.
- All seventeen tracks validate (sixteen championship circuits and `test_oval`). Three environments. The index lists sixteen tracks.
- Acceleration, braking, steering, oil versus asphalt, wall damage, car-to-car separation.
- Nitro reaches a higher speed than throttle alone, drains while held, refills when released, and a boost pickup adds charge.
- Slipstream holds a higher speed than the same throttle, fills nitro, and detects a car directly ahead. Drift yaws the car and fills nitro.
- Skipping a checkpoint is rejected. Wrong-way crossings are rejected. Two ordered laps finish the race and fill the result.
- A missile and a mine reduce hit points. A shot on a barrier does not.
- Fees, purses, DNF pay, points, and rising upgrade prices.
- New career money, a locked National series, an engine purchase that raises acceleration, a refused purchase when broke, a paid repair, and a save/load round trip.
- Four simulated Club wins pay a consistent net and unlock National.
- Masters Cup stays locked until Turbo is completed, pays a 2000 fee and an 8000 winner purse, fields tier-3 drivers, and opens on Gull Rock.
- An AI car completes a lap of `test_oval`.
- On `harbor_loop` the player survives the opening and the field leaves the grid.
- Each of the sixteen championship tracks moves the player off the grid within four seconds without destroying them.
- Main menu, settings, and credits expose their buttons.
- Netcode: inputs are sanitized and clamped, neutral input is calm, discovery packets round-trip and reject strangers, paints and names are cleaned, the net roster builds 6 cars with 2 humans first, and a snapshot restores all car positions and the race clock.
- 3D builders: the harbor ground mesh covers every tile with 4 vertices each, walls merge into whole boxes, water sits below asphalt and kerbs sit above it, paints differ, and all four car bodies build with four wheels, two steering pivots, and a nose that matches the sim heading. The 3D view maps sim coordinates onto the ground plane.
- Car sheets, the nitro pickup, explosion, smoke, music, engine, missile audio, the icon, and `scenes/main.tscn` load.
- Daily Duel: the date seed is deterministic and varies across days, Wreckfest arms every rival, Minestorm loads 24 mines, best times and ghosts save, slower replays keep the best, streaks grow on consecutive days and reset after a gap, DNFs score nothing, daily data survives a career reset, and the 3D view builds the translucent ghost, records at race time, and plays it back.
- Kenney era: each body maps to a shipped `.glb`, the model spans a car length with its nose yawed onto +X, effects and body material are present, and the procedural builder stays as fallback. All twelve trackside props load, desktop renders Forward+ while mobile stays Compatible, the start complex spawns 22 props with two grandstands, the race grade has bloom on (darker ambient at night), and the chase camera widens with speed and nitro.

- VR: the panel ray test maps centre and corner pixels and rejects misses and rays that point away. The origin yaw faces the car heading for any angle. Stick deadzone, chase and cockpit eye placement are checked. A laser click presses a real Button through the panel viewport, and a click elsewhere does not. In `VR.sim`, touch controls stay off, a race builds the XR rig, skips split screen, puts the HUD and pause menu on the panel, skips the letterbox and vignette, keeps the rig processing while paused, follows behind the car, toggles lasers with pause, and swaps camera on Y. The lobby hosts the menus on its screen and shows Tussie and your car. The vendors plugin ships Android arm64, the `quest` feature enables OpenXR, and the Quest 3 preset is present.

- Podium: after the orbit the stage is built in the tree with three blocks, Tussie, and the winner on block 1. The camera frames the stage from above the platform, the callout says YOU WIN!, results wait for the podium and then open, and the top three are ranked by place with wrecks skipped. The main menu has How to Play, and the guide covers keyboard, weapons and pickups, and the career.

## VR smoke

`xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy -- --vr-sim --vr-smoke` captures `vr_lobby.png` (showroom, menu screen, laser, Tussie, car on a plinth), `vr_settings.png` (VR camera option), `vr_race.png` (chase rig with the dashboard HUD), `vr_cockpit.png` (roof cam), `vr_pause.png` (pause menu on the HUD with a laser), and `vr_back.png` (back in the lobby after quitting).

The Quest APK manifest was checked with `aapt2`: `com.oculus.intent.category.VR`, `org.khronos.openxr.intent.category.IMMERSIVE_HMD`, `android.hardware.vr.headtracking`, `com.oculus.supportedDevices`, the OpenXR loader and vendors libraries, `--xr_mode_openxr`, minSdk 29, and versionCode 21. The Windows exe passes the suite under Wine with and without `--xr-mode on`.

## Visual smoke

Command:

```bash
xvfb-run -a godot --path /workspace --rendering-driver opengl3 --audio-driver Dummy -- --smoke
```

Exit code 0. Captures are in `docs/previews/`.

- `menu.png` — main menu over the harbor backdrop.
- `help.png` — How to Play guide.
- `podium.png` — podium after the finish: three cars on gold, silver, and bronze, name boards, Tussie, and confetti.
- `garage.png` — Sprint Dart, repairs, ammo, the four cars.
- `race.png` — 3D chase view of the harbor starting grid, kerbs, palms, and the start gantry.
- `race_mid.png` — 3D harbor asphalt, rumble kerbs, nitro bar, and car shadows.
- `race_boost.png` — exhaust flame lit, nitro falling, higher speed, vignette at the edges.
- `split.png` — two 3D chase views of `test_oval` during the countdown, including the yellow guest car.

The audio driver for that run was Dummy, so the speakers were not checked. The smoke log did not report a script error.

## Windows

`releases/windows/TussieCars.exe` is a PE32+ GUI x86-64 executable. `releases/windows/TussieCars-windows.zip` is the same file compressed and is a normal git blob.

The 1.1.0 executable was started under the same Wine 9 override (`dinput8` and XInput builtins disabled). Godot printed its banner, opened OpenGL through Mesa llvmpipe, and fell back to the dummy audio driver. The 1.3.0 exe is exported in this pass and was not started under Wine again. `docs/previews/wine_menu.png` is still the 1.0 menu.

## Android

Export command succeeded (exit 0) and signed the APK with `build/release.keystore`. The log printed "Signed" and "Verifying APK".

`aapt dump badging` (build-tools 36.1.0) printed:

- package `com.tussiecars.arcade`, versionName `2.9.0`, versionCode `20`
- compileSdk 36
- minSdk 24, targetSdk 36
- application label TussieCars, adaptive icon `mipmap-anydpi-v26/icon.xml`

The manifest (`aapt dump xmltree ... AndroidManifest.xml`) confirms `INTERNET`, `ACCESS_NETWORK_STATE`, and `VIBRATE` permissions and `screenOrientation=0xb` (sensor landscape).

`unzip -l` shows only `lib/arm64-v8a/` (`libgodot_android.so` and `libc++_shared.so`).

`aapt` still prints `failed to read attribute 'android:required'` and, on this dump, stopped after the application label. Orientation and the GLES version were not re-read from badging. The export preset is still landscape.

No emulator binary is installed, and no phone was attached. The APK was not installed. `/dev/kvm` exists, which is not the same as a system image.
