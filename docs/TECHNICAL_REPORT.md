# TussieCars — technical report

10 October 2026. Godot 4.7.2. Version 1.2.0. Limits below still apply.

## Implemented

- Top-down arcade handling: acceleration, braking, speed-sensitive steering, lateral grip, surface drag, oil, water damage, wall hits, and car-to-car bumps. Balance is in `data/balance.json`.
- Nitro: extra acceleration and a higher speed cap while the tank lasts, a small grip cut, slow refill, and an orange pickup. Shift, N, gamepad Y, or the touch BOOST button. Rivals use it on open straights after the first few seconds.
- Drift and slipstream, in the sense of Hotshot Racing's boost loop, with original tuning. Drift (Space, M, left-stick click) slides the car and fills nitro. A fast car directly ahead cuts drag, raises the speed cap slightly, and fills nitro.
- Race loop: standing start, countdown, ordered checkpoints, laps, positions, timer, results, DNF on destruction or the time limit.
- Weapons: front missiles, rear missiles (upgrade), mines (upgrade), limited ammo, explosions, pickups that respawn, AI firing after the green flag.
- Rivals that follow waypoints, brake for corners, offset to pass, reverse out when stuck, and use a small nudge back toward the line. Personalities are aggressive, cautious, and balanced. Rookie, Pro, and Ace scale skill, aggression, damage taken, and prizes.
- Career of three series (Club Cup, National Series, Turbo Championship), four races each, points, entry fees, and prize money. Top 3 advances. Saves to `user://career.json`.
- Garage: eleven upgrade rows, repairs, ammo, and four cars (Sprint Dart, Harbor Viper, Iron Mule, Night Fang).
- Menus: main, new career, continue, championship, briefing, garage, exhibition, settings, pause, results, standings, credits, quit. Fullscreen, shake, touch mode, and keyboard remap are saved.
- Local two-player split-screen. Keyboard for both. Gamepad slots are device 0 and device 1. Touch pad for a phone.
- Twelve original circuits in coastal, desert, and industrial themes, plus `test_oval` for tests. Baked edge lines, rumble ticks, nitro pads, and contact shade beside barriers. Cars are supersampled and lit from one sun. The race view draws a soft shadow, boost flame, skid marks, speed streaks, an environment grade, and a vignette.
- Windows x64 exe, a zip of that exe, and a signed Android arm64 APK. Version 1.2.0, Android versionCode 3.

## Not implemented

- Online play, replays, and a track editor in the game.
- Playing the APK on a device.
- A fresh screenshot of the 1.1.0 exe. It was started under Wine and reached OpenGL, but `wine_menu.png` is still the 1.0 menu.
- Hearing the mix on the Wine run (no WASAPI device).

## Test evidence

See `TEST_RESULTS.md`. Short version: 91 headless checks passed. xvfb smoke showed the menu, garage, a harbor race with the nitro bar and speed streaks, a nitro flame, and split-screen. The new exe is a PE32+ binary and the zip tests clean. `aapt` identified the APK as `com.tussiecars.arcade` 1.2.0. `unzip -l` shows only arm64 libraries. The APK was signed. It was not installed.

## Performance

No formal profile. The headless harbor probe (six cars, 60 Hz, about twelve seconds of race time) finishes in well under a second of CPU. Exports and the visual smoke ran on llvmpipe. The game is 2D with a baked ground texture and a handful of sprites, which is the intended phone budget. Skid marks are a fixed pool of 120 quads. Speed streaks are a pool of 36. It was not measured on ARM hardware.

## Bugs still open

Listed in `KNOWN_ISSUES.md`. The ones that matter: no device pass on Android, Wine needs DirectInput disabled, and rivals can be wrecked quickly once weapons unlock.

## Builds

| Build | Path |
| --- | --- |
| Windows x64 | `releases/windows/TussieCars.exe` |
| Windows zip | `releases/windows/TussieCars-windows.zip` |
| Android arm64 | `releases/android/TussieCars.apk` |

## Windows verification

The 1.1.0 exe was started under Wine 9 on xvfb with DirectInput and XInput builtins disabled. Godot reached OpenGL (Mesa llvmpipe) and fell back to the dummy audio driver. It did not crash on the DirectInput null read. The 1.2.0 exe was exported after that and was not started under Wine. `docs/previews/wine_menu.png` is still the 1.0 menu capture.

## Android verification

Package exported and signed. Badging shows version 1.2.0 / code 3, minSdk 24, targetSdk 36. The archive contains only `lib/arm64-v8a`. **Not installed and not played.** No emulator image and no device.

## Suggested next steps

- Install the APK on a phone and check the steering pad, the BOOST button, landscape insets, and the save path.
- Run the 1.1.0 exe on Windows with a gamepad plugged in.
- Give the slower AI a clearer way through the first corner so fewer of them die before lap one.
- Add a couple of street-shaped circuits if the oval family starts to feel samey.
