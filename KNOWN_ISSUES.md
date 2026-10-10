# Known issues

## Android was not played

`releases/android/TussieCars.apk` is a signed arm64 package (1.3.0, code 4). This machine has the SDK and KVM, and no emulator image and no device. The APK was not installed. Touch controls, the on-screen pad, haptics, safe-area margins, keep-screen-on, and Android save paths are implemented and untested on hardware. The manifest was verified with `aapt`: INTERNET, ACCESS_NETWORK_STATE, and VIBRATE permissions, sensor-landscape orientation, and an adaptive icon.

`aapt` warns that some `android:required` attributes are the string `false` rather than a boolean. That comes from the Godot export template. `unzip -l` shows only `lib/arm64-v8a`.

## Multiplayer was not played against a second device

The netcode path is covered by headless tests (input sanitizing, discovery round-trip, snapshot restore) and the lobby/race flow compiles and runs through the same race view as single-player, but no two-device session was run here: no second phone or PC was available. Known limits by design:

- No host migration: if the host leaves, the race ends for everyone.
- Internet play needs the host reachable (same network, or UDP+TCP 7777 and UDP 7778 opened/forwarded).
- The host pausing pauses the simulation for all guests.
- Client car motion is smoothed from snapshots; on high-latency links it can look steppy.

## Windows was launched under Wine, not on Windows

The 1.1.0 exe starts under Wine when DirectInput and XInput builtins are disabled. The 1.2.0 build was exported after that check and was not launched again:

`WINEDLLOVERRIDES="dinput8=d;xinput1_3=d;xinput1_4=d;xinput9_1_0=d"`

The 1.1.0 launch reached OpenGL (Mesa llvmpipe) and then the dummy audio driver. Without the override, Wine 9 null-derefs during startup. A real Windows PC was not available. WASAPI had no device in Wine, so that launch was silent. `docs/previews/wine_menu.png` is the 1.0 menu. The Wine framebuffer on that older capture drew a narrow repeated strip down the left edge. The same menu captured from native Godot on Linux does not show that strip.

## Gamepad and touch

Keyboard play and the remap screen were exercised. No gamepad was connected. Touch layout is in the race view and was not used on a touchscreen. Settings can force touch on.

## Combat is lethal if you sit in a cone

After the 2.4 second green-flag lock, missiles hurt. In a headless harbor probe one rival was destroyed in the first twelve seconds while the player finished a lap at about two thirds health. That is intended pressure, and a cautious player can still lose a car in a pile-up.

## Split-screen scope

Two-player was smoke-tested on `test_oval` (both halves showed the circuit, the field, and the countdown). It was not played through a full championship round.

## Tracks

All twelve championship tracks start and move the player in the automated sweep. They are closed circuits with different lengths, kinks, surfaces, and one crossing (`mesa_cross`). Several are still oval-like with wobbles rather than street maps.

## Development keystore

The Android release key is `build/release.keystore` (gitignored). Alias and password are `turborivals`. It is a development key, not a Play Store key.

## 3D is new and hardware-unproven

The 1.4.0 race view renders in 3D and was verified through xvfb screenshots (chase cam, shadows, split-screen, boost flame, particles). Frame rate on a real phone or a low-end PC was not measured. The scene is light by design (one ground mesh, one wall mesh, primitive cars with shared materials, CPU particles, a single shadowed sun), but mobile GPUs may still want the shadow distance or particle counts tuned after a first on-device run.

## VR was not run on a headset

There is no headset here. The Quest APK is built, signed, and its manifest is checked, and the VR code is tested with `--vr-sim` (desktop camera, mouse as laser). Frame rate on Quest 3, controller pose names on the Meta runtime, comfort of the chase rig, and HUD readability are unverified. The phone LineEdit fields (multiplayer name and IP) may not bring up a keyboard inside the headset. Defaults are filled in, and LAN lobbies join with one click.
