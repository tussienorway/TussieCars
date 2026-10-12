# TussieCars

Top-down arcade combat racing in full 3D. Original low-poly cars, circuits, and audio, in the spirit of 1990s club racing. Built with Godot 4.7.2.

A career runs through four championships, sixteen circuits, and a garage. You earn prize money, repair the hull, and buy faster parts and weapons. A local co-driver can replace the last rival.

## Download

**Play in the browser:** [https://tussienorway.github.io/TussieCars/](https://tussienorway.github.io/TussieCars/)

**Bruksanvisning (Norwegian user manual): [BRUKSANVISNING.md](BRUKSANVISNING.md).** The game also has a How to Play page in the main menu.

Ready-made builds are on the [Releases page](https://github.com/tussienorway/TussieCars/releases/latest):

- `TussieCars-Windows-Setup.exe`: Windows 64-bit installer (v1.0.0). It installs for the current user and adds a Start-menu shortcut. Windows SmartScreen warns because the file is unsigned: choose **More info**, then **Run anyway**. PC VR is `TussieCars VR` in the Start menu, or `TussieCars-VR.bat` in the install folder.
- `TussieCars-windows.zip`: older Windows 64-bit zip. Unzip and run `TussieCars.exe`, or `TussieCars-VR.bat` for PC VR.
- `TussieCars.apk`: Android phones (ARM64).
- `TussieCars-Quest.apk`: Meta Quest 2/3/3S/Pro. Sideload it as described under VR below.

The `releases/...` paths mentioned below are where local exports are written. In this repository the builds are attached to the release instead.

## Play from source

Requires Godot 4.7.2.

```bash
godot --path . 
```

Headless checks:

```bash
godot --headless --path . -- --test
```

## Windows

Download `releases/windows/TussieCars-windows.zip` (about 77 MB). Unzip it and run `TussieCars.exe`. That zip is a normal file, so it does not need Git LFS.

`releases/windows/TussieCars.exe` is the same program stored with Git LFS. Use the zip if a download of the exe says the file is in use or the exe you got is only a few lines of text. Keyboard, gamepad, and windowed or fullscreen modes are supported. Saves go to the usual Godot user folder for TussieCars.

This environment launched that executable under Wine 9. The builtin DirectInput library crashes on startup here, so the verified launch used:

```bash
WINEDLLOVERRIDES="dinput8=d;xinput1_3=d;xinput1_4=d;xinput9_1_0=d" wine releases/windows/TussieCars.exe
```

On a Windows PC those overrides are not needed. Gamepads use the left stick, the triggers, Y for nitro, RB, LB, X, and Start.

## Android

`releases/android/TussieCars.apk` is a signed ARM64 package.

- Package: `com.tussiecars.arcade`
- Version: 3.1.0 (code 22)
- minSdk 24, targetSdk 36
- Landscape (sensor), adaptive launcher icon
- Permissions: internet (multiplayer), access-network-state (lobby discovery), vibrate (haptics)

Install with a device connected:

```bash
adb install -r releases/android/TussieCars.apk
```

Touch controls appear automatically on a phone: a steering pad, accelerate, brake, drift, nitro, fire, mine, and rear missile. Menus are large enough to tap. This workspace has no emulator and no phone, so the APK was not installed or played on Android. See `KNOWN_ISSUES.md`.

To rebuild the APK you need the Godot 4.7.2 export templates, Android SDK 36, NDK 29, JDK 21, and a release keystore. The development keystore is created locally (it is not in git) at `build/release.keystore`, alias `turborivals`, store password `turborivals`.

## VR: Meta Quest 3 and PC VR

TussieCars runs in VR with the same races, career, and multiplayer.

- **Menus:** you stand in a neon showroom. The game menus are on a big screen in front of you, Tussie sits on a cushion beside it, and your current car turns on a plinth. Point a controller and pull the trigger to click. The thumbstick scrolls.
- **Racing:** you ride with the car. The chase view (the default and the more comfortable one) floats behind and above the car. The cockpit view sits on the roof. The HUD is a dashboard panel just below your line of sight. Collisions and hits pulse the controllers.
- **Controls:** right trigger is gas, left trigger is brake, and either thumbstick steers. A is nitro, B is drift, right grip fires a missile, left grip drops a mine, and X fires a rear missile. Y switches between chase and cockpit view. The Menu button pauses; while paused, the lasers come back so you can pick Resume, Retire, or Quit. Hold the Meta button to recenter.
- Settings has a "VR camera" option. Split screen is hidden in VR.

### Install on a Quest 3 (standalone)

`releases/quest/TussieCars-Quest.apk` is a signed ARM64 OpenXR build (package `com.tussiecars.vr`, Meta vendor plugin, Quest 2/3/3S/Pro, minSdk 29). It installs next to the phone version.

1. Turn on developer mode for the headset in the Meta Horizon phone app (Devices → your headset → Headset settings → Developer mode). Meta requires a free developer account for this.
2. Connect the headset to a PC with USB-C and accept "Allow USB debugging" inside the headset.
3. Install with `adb install -r releases/quest/TussieCars-Quest.apk`, or drag the APK onto SideQuest.
4. In the headset, open the app library, filter on **Unknown sources**, and start TussieCars VR.

### PC VR (Quest Link, Air Link, SteamVR)

Start Quest Link or SteamVR, then run `TussieCars-VR.bat` from the Windows zip (it runs `TussieCars.exe --xr-mode on`). With no VR runtime, the game falls back to the normal desktop window.

### Testing VR without a headset

```bash
godot --path . -- --vr-sim                # lobby and races with the VR rig; the mouse is the right laser
xvfb-run -a godot --path . --rendering-driver opengl3 --audio-driver Dummy -- --vr-sim --vr-smoke
```

The second command saves `vr_lobby`, `vr_settings`, `vr_race`, `vr_cockpit`, `vr_pause`, and `vr_back` captures in `/tmp/turbo_smoke/`.

### Rebuilding the Quest APK

The Quest preset uses a Gradle build. Run `tools/setup_quest_build.sh` once to unpack Godot's Android build template into `android/build` (gitignored). Then run:

```bash
godot --headless --path . --export-release "Quest 3" releases/quest/TussieCars-Quest.apk
```

The OpenXR vendors plugin 5.1.0 is in `addons/godotopenxrvendors`, trimmed to Android arm64, Windows, and the Linux editor library (binaries in Git LFS).

## Multiplayer

From the main menu choose Multiplayer. One device hosts, the others join — no account, no server. Your name, paint, track, and port are remembered between sessions.

- **Same WiFi:** the host taps QUICK HOST and the lobby broadcasts itself instantly; guests open Multiplayer, see it under "Tap a lobby to join", and tap once — no IP typing. If a lobby does not appear (some guest networks block discovery), tap Rescan or join by IP.
- **Internet or manual join:** the guest types the host's IP and port (default 7777) and presses Join. The host may need to open/port-forward UDP+TCP 7777, plus UDP 7778 for discovery.
- Up to 4 human drivers; the grid fills to 6 cars with AI. The host picks the track. Each device renders its own fullscreen follow-camera.
- Netcode is host-authoritative: guests send inputs, the host simulates and broadcasts snapshots 30 times a second. Races pay no purse and score no points. After the finish everyone returns to the lobby for a rematch.

## Daily Duel

From the main menu choose Daily Duel — no career needed. Every day brings one seeded race: a fixed circuit plus a twist (Night, Minestorm, or Wreckfest).

- Your run is recorded and saved as a translucent ghost car; next time you race the same day, the ghost drives your best lap ahead of you.
- Finish the race to keep a day streak alive (it survives career resets). Career drivers earn a club purse plus a streak bonus.

## Party Grand Prix

Whenever two or more humans race together — WiFi multiplayer or split-screen Exhibition — the game keeps a running Party Grand Prix. Humans score 15-12-10-8-6-4 by finishing order (a wreck still earns 1). The standings, wins, and a crown for the leader show after every race and in the lobby, so a rematch always means something. Leaving multiplayer resets the party.

## Knockout

In Exhibition, tick **Knockout** before picking a track. There are no laps: every 20 seconds the car in last place is knocked out, with a callout on screen and a countdown in the HUD (it turns red when you are the one in danger). The last car standing wins.

## Graphics

The look is stylized arcade, not photorealism: pro-built low-poly cars and trackside props by Kenney (CC0, credited in `assets/kenney/CREDITS.md`), bloom lighting, fog, dynamic shadows, and night floodlighting on industrial circuits.

- Desktop renders with Forward+ (ambient occlusion included) and falls back to Compatibility automatically on older video cards; Android always uses Compatibility for speed and battery.
- Every start line has a grandstand, billboards, checkered flags, tire stacks, and cones. Industrial tracks get modern lamp posts with glowing heads.
- The chase camera widens its field of view with speed and nitro, and shakes on hits.
- Asphalt has a world-space noise detail instead of a tile checker, grass is mowed in diagonal bands, and the grandstands are packed with a cheering crowd.
- Weather: tick **Rain** in Exhibition (or catch a **Monsoon** Daily Duel) for falling rain, a grey sky, thicker fog, shiny wet asphalt, and 20% less grip. Every car throws up a mist of spray at speed and runs with its headlamps on, as it does at night.
- Tussie the cat: the game's mascot, a red-and-white long-haired cat with a fluffy ruff, ear tufts, and a banded tail. It sits beside every start grid, turns its head to follow your car, swishes its tail, and gets excited at the finish. It also sits next to the logo on the main menu and in the credits.
- Cinematic finish: crossing the line slides in letterbox bars and swings the camera around your car while your place and time are shown. Then the camera cuts to a podium: the top three cars on gold, silver, and bronze blocks with name boards, Tussie beside them, and confetti. Then the results open.

## Controls

| Action | Player 1 | Player 2 |
| --- | --- | --- |
| Accelerate | W or Up | I |
| Brake | S or Down | K |
| Steer | A D or Left Right | J L |
| Drift | Space | M |
| Nitro | Shift | N |
| Front missile | C | U |
| Mine | X | O |
| Rear missile | V | P |
| Pause | Esc or Start | |

Keyboard binds can be changed in Settings and are saved. Gamepad Y is nitro, clicking the left stick drifts, X is the rear missile, and RB/LB fire and drop mines.

Drift while you turn to slide and fill the nitro tank, the way arcade racers charge a boost. Sit in the wake of the car ahead and the slipstream does the same, and also lets you go a little faster than your normal top speed. Spend the tank with nitro.

Roads are about 1.7 times as wide as the original tile layouts (every circuit is scaled up, so three cars fit side by side on most straights).

The guard rails are solid and they hurt. A full-speed head-on hit costs about 39 HP, a medium knock 15–25 HP, and scraping along a rail at speed wears about 7 HP per second — all with a red flash, rumble, and a "WALL HIT" callout on bigger hits. Enough wall contact wrecks the car. AI drivers take a third of the wall damage so the field does not destroy itself. Repair pickups on the track and the garage fix the damage. Exhibition needs no career and lists all 16 circuits in a two-column picker; locked series race against club-level rivals.

## Career

You start in a Sprint Dart with $2,800 on Pro difficulty. Club Cup is open. Finish a series in the top 3 to unlock the next one. Entry fees come out when the race starts. Prize money is paid at the flag, unless you are destroyed or time out. If you cannot pay, a few sponsored entries and then a yard scholarship keep the season from locking.

The garage sells engine, top speed, brakes, tires, armor, hull, front missiles, mines, rear missiles, ammo racks, and pit tools, plus three more cars once their series is cleared.

**Rival Bounty.** Every championship race names one driver as your rival — the field's ace at the start of a season, then whoever sits just above you in the points (or right behind, if you lead). Finish ahead of them for a bounty worth 40% of the winner's prize. The rival wears a red marker, shows pink on the minimap, has a live HUD readout, and is called out when you pass or get passed.

## Project map

- `src/` simulation, race view, menus
- `data/` balance, vehicles, drivers, championships, tracks
- `assets/` sprites, tracks, audio, font
- `tests/suite.gd` headless checks
- `tools/` art and track generators
- `docs/` design notes and the technical report
- `releases/` Windows executable and Android APK
