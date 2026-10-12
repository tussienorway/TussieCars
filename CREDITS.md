# Credits

Code and art shipped with TussieCars, and the third-party pieces reused for the driving model and the track. Everything listed here is used under a licence that allows it (CC0 or the project's own original code). No GPL code and no unlicensed assets are included.

## Original

The race simulation, friction-circle handling, AI, UI, tracks, and audio are original to TussieCars.

The tyre model is an arcade friction circle written for the existing kinematic car: one grip budget shared by braking and cornering, less grip at high speed, and weight transfer that loosens the rear under braking and the nose under power. It was written for this project. Public friction-circle descriptions informed the approach. MIT raycast-vehicle projects were reviewed and not copied, because they drive a `RigidBody3D` and this game keeps a 2D simulation for checkpoints, netcode, and the test suite. Those reviews included:

- [DAShoe1/Godot-Easy-Vehicle-Physics](https://github.com/DAShoe1/Godot-Easy-Vehicle-Physics) (MIT)
- [Dechode/Godot-AdvancedVehicle](https://github.com/Dechode/Godot-AdvancedVehicle) (MIT)
- [jreo03/g-rcp2](https://github.com/jreo03/g-rcp2) VitaVehicle (MIT)

## Kenney

Author: Kenney (https://kenney.nl)

The cars and trackside props in `assets/kenney/` come from the Car Kit and the Racing Kit. Both packs are [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/). Full texts: `assets/kenney/LICENSE-car-kit.txt` and `assets/kenney/LICENSE-racing-kit.txt`. See `assets/kenney/CREDITS.md` for the file list and the local change that embedded the car-kit colormap.

## ambientCG

Author: ambientCG (Lennart Demes), https://ambientcg.com

- Asphalt030, 1K JPG color and roughness, downloaded from https://ambientcg.com/view?id=Asphalt030
- Licence: [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)
- Local change: both maps were scaled to 512×512 JPEG so the web build stays small. Shipped as `assets/textures/asphalt_color.jpg` and `assets/textures/asphalt_roughness.jpg`.

Poly Haven CC0 HDRIs were considered for the sky. The tonemapped panoramas are tens of megabytes, which is a poor fit for the web build, so the sky stays a procedural Godot sky tuned per track environment.
