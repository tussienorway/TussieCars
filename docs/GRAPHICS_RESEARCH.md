# Graphics research for TussieCars 1.2

TussieCars is a top-down arcade racer in Godot 4.7.2. The Windows export uses the **Forward+** renderer (Vulkan, Direct3D 12, or Metal). The web export is locked to the **Compatibility** renderer (OpenGL 3 / WebGL 2). Android uses Compatibility as well. This note is what a post-2020 racing game actually turns on, which of those techniques Godot 4 can run, and which of them survive in the browser.

The feature split below follows the official Godot 4.6 renderer comparison, which 4.7.2 still uses: [Overview of renderers](https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html) and [Internal rendering architecture](https://docs.godotengine.org/en/4.6/engine_details/architecture/internal_rendering_architecture.html). Anything marked Forward+ only is skipped at runtime when `RenderingServer.get_current_rendering_method()` is `gl_compatibility`, so the same scene runs in the browser without missing-shader errors.

## What “post-2020” looks like in a racer

The reference look is not a film still. It is the image modern arcade and sim racers ship:

- **Trackmania (2020)** and **Art of Rally** — stylized PBR, a graded sky, bloom on practical lights, fog that separates the hills, and temporal antialiasing so the frame does not shimmer.
- **Wreckfest** and **Forza Horizon 5** — clearcoat car paint, wet-road reflections, decals for rubber and paint, volumetric light in fog and dust, and an upscaler (FSR or DLSS) that includes its own temporal AA.
- **Godot 4 games on Forward+** such as *Road to Vostok* use the same stack the engine exposes directly: AgX tonemapping, volumetric fog, TAA or FSR 2.2, and a panorama sky. The official material and environment docs are the API this project calls. No third-party post stack is required.

The highest-impact pieces for *this* game, in order, are the ones you notice from the chase camera in one second: a photographic sky, textured asphalt and grass, glossy paint with a reflection probe, bloom and SSAO, then a grade. Screen-space reflections, volumetric fog, SDFGI, and FSR 2.2 are the Forward+ layer on top. They do not exist on the web, so the preset menu has to mean something there without them. Motion blur is documented below and is not available in this Godot build.

## Technique notes

### PBR materials

Godot’s `StandardMaterial3D` is a metallic-roughness PBR shader (Burley diffuse, Schlick-GGX specular) on every renderer. Albedo, roughness, metallic, and normal maps are the whole modern-road trick: a flat vertex color reads as a 2014 prototype, a tiled asphalt map with a normal reads as a road.

Compatibility renders the same material. It does not support subsurface scattering. Clearcoat, rim, and normal maps do run, which is why the car paint below is safe on the web. Textures here are CC0 scans from ambientCG, scaled to 512² so the web package stays small.

### Car paint clearcoat

Automotive paint is a colored base under a smooth dielectric coat. `StandardMaterial3D.clearcoat` / `clearcoat_roughness` (and the matching `CLEARCOAT` outputs in spatial shaders) add that second specular lobe. A rim light sells the panel edge in a chase view where the probe only has a sky to reflect. Both terms are part of the standard lighting shader, so they work on Compatibility and Forward+.

A custom flake shader was considered and skipped: the Kenney bodies are already `StandardMaterial3D`, and the test suite checks that the body material stays that type. Raising clearcoat and rim on the existing material gets the showroom read without a second shader path.

### HDRI sky and reflection probes

A procedural sky is a gradient. A panorama sky is a photograph. `PanoramaSkyMaterial` on a `Sky` resource, fed by an equirectangular HDR, lights the ambient term (`AMBIENT_SOURCE_SKY`) and gives reflections a real horizon. This works on Compatibility and Forward+.

Poly Haven 1K HDRIs are CC0. The day sky is Kloppenheim 02 (pure sky) and the rain sky is Kloofendal 48d (partly cloudy), each about 1.4 MB. Night stays procedural: a daylight HDR on an industrial night circuit looks like a mistake, and a third night plate was not worth the download.

`ReflectionProbe` with `UPDATE_ONCE` bakes one cubemap of the track so the clearcoat has something to reflect besides the sky tint. Probes work on every renderer. Compatibility allows two probes per mesh; this game places one track-wide probe from Medium upward. Quest drops it for frame time.

### Glow / bloom

Glow is a post process on the HDR buffer: pixels above `glow_hdr_threshold` bleed into neighboring pixels. It is what makes nitro pads, brake lights, start bulbs, and the cat’s eyes feel lit rather than painted. Supported on Compatibility since Godot 4.3, and on Mobile and Forward+. Low turns it off. Night runs a slightly higher intensity so the practical lights bloom.

### AgX and ACES tonemapping

Both are filmic curves that compress HDR into the display range. Godot’s `Environment` offers Linear, Reinhard, Filmic, ACES (`TONE_MAPPER_ACES`), and AgX (`TONE_MAPPER_AGX`, added in 4.3). Tonemapping runs on all three renderers.

ACES is the curve a lot of 2016–2020 games shipped. It is contrasty and it skews bright saturated colors toward orange and cyan. AgX, from Troy Sobotka’s work and now the Blender/Godot default recommendation, keeps those hues closer to the material. Cyan and red cars stay cyan and red under a bright sky, which matters more here than a fashionably crushed black. v1.2 stays on AgX with a white point around 6 and a small exposure lift, because AgX sits a little darker than the old Filmic curve. ACES remains one line away (`TONE_MAPPER_ACES`) if a harsher grade is ever wanted. It is not a second preset.

### Color grading LUT

`Environment.adjustment_*` (brightness, contrast, saturation, and `adjustment_color_correction`) is supported on every renderer. The correction texture is a 3D LUT stored as a horizontal strip: for a 16³ LUT the image is 256×16, with x = `blue * 16 + red` and y = `green`. `assets/textures/grade_lut.png` is that strip. It lifts contrast, cools the shadows a little, and warms the highlights — the usual “finished game” grade — without a compositor. Low leaves adjustments off so the preset is visible. Compositor effects are Forward+ and Mobile only; a LUT does not need them.

### SSAO and SSIL

Screen-space ambient occlusion darkens creases: car to road, grandstand to ground, wall bases. Godot’s SSAO is derived from Intel ASSAO. **Compatibility gained a simplified SSAO in Godot 4.6.** Mobile still does not have it. Forward+ has the full effect.

SSIL is the indirect-light cousin of SSAO and is **Forward+ only**. Ultra on Windows enables a gentle SSIL. The web preset never asks for it.

### SSR

Screen-space reflections mirror the rendered frame onto rough surfaces. They are the wet-road look in modern racers, and they are **Forward+ only** (half resolution). High and Ultra on Windows turn them on, with more steps on Ultra. Compatibility keeps the wet road as a low-roughness asphalt material plus the reflection probe, which still reads as wet without a screen-space pass.

### Volumetric fog

Depth fog (`fog_enabled`) is a cheap distance fade and works everywhere. Volumetric fog is a froxel grid that lights and shadows the air. It is **Forward+ only** (not Mobile, not Compatibility). High and Ultra on Windows add a thin haze so the far side of the circuit sits in air; rain thickens it. The web build keeps the depth fog it already had.

### SDFGI, VoxelGI, and LightmapGI

| Technique | What it is | Bake? | Forward+ | Compatibility (web) |
| --- | --- | --- | --- | --- |
| SDFGI | Real-time signed-distance GI cascades around the camera | No | Yes | No |
| VoxelGI | Baked voxel GI inside a fixed box | Yes, needs RenderingDevice | Yes | No |
| LightmapGI | Baked lightmaps on UV2 | Yes, editor only, RenderingDevice | Yes | Rendering only, not baking |

The circuits are procedural meshes hundreds of meters across, rebuilt from the track string, with no lightmap UV2. Baking VoxelGI or LightmapGI per track in the editor does not fit, and the web build could not bake them anyway. SDFGI is the one that can follow the chase camera without a bake. Ultra on Windows enables four cascades, a 1.6-unit minimum cell (the world scale is about 10 cm per unit), and a lowered ambient term so the GI does not stack on top of a full sky ambient and blow out. Medium and High leave it off: on a large outdoor mesh the cost is real and the chase camera already gets most of its shape from the sun and SSAO.

### TAA, FSR 2.2, MSAA, FXAA, SMAA

| AA | Compatibility (web) | Mobile | Forward+ |
| --- | --- | --- | --- |
| MSAA 3D | Yes | Yes | Yes |
| TAA | No | No | Yes |
| FSR 2.2 | No | No | Yes |
| FXAA | No | Yes | Yes |
| SMAA (4.6+) | No | Yes | Yes |
| FSR 1.0 spatial upscale | Yes | Yes | Yes |

TAA is Godot’s Spartan-derived temporal pass. FSR 2.2 is AMD’s temporal upscaler, implemented on RenderingDevice, and at a scale of 1.0 it is a high-quality temporal antialias plus RCAS sharpen rather than an upscale. The two should not be stacked. FXAA and SMAA are not available on Compatibility, so the browser cannot use them as a fallback.

v1.2 mapping:

- **Low** — 3D scale 0.75 through FSR 1.0 (works on the web), MSAA off.
- **Medium** — native resolution, MSAA 2×.
- **High** — native. Forward+ uses TAA. Compatibility uses MSAA 4×.
- **Ultra** — Forward+ uses FSR 2.2 at native scale (temporal AA, no MSAA, no separate TAA). Compatibility uses MSAA 4×.

### Motion blur

Older Godot 4 docs describe `Environment.motion_blur_enabled` as a Forward+ post effect. **Godot 4.7.2 does not expose that property** on `Environment`, `CameraAttributesPractical`, or `Camera3D`. The 4.7.2 binary has no `motion_blur` symbol outside an unrelated NVIDIA ray-tracing extension. v1.2 does not invent a fullscreen smear shader to fake it: a chase camera already widens its field of view with speed, and a fake blur would fight the driving line. If a later Godot build puts the property back, Ultra on Forward+ is the place to turn it on.

### Decals

`Decal` nodes project a texture along their Y axis onto whatever they hit. They are supported on **Forward+ and Mobile, not Compatibility**. Oil stains and start-straight chevrons are the racing use. On Forward+ High/Ultra the game places real `Decal` nodes. On Compatibility, and on Low/Medium, the same textures are alpha cards sitting on the asphalt. The read is the same from the chase camera; only the projection method changes.

### Props and foliage

Kenney’s Racing Kit trees (`treeLarge.glb`, `treeSmall.glb`) are CC0 and already in the repo. A seeded scatter on grass cells that are not beside the road gives the horizon something to parallax against. The count follows the preset (6 / 16 / 28 / 40). The scatter does not touch the collision mesh or the driving model.

## Quality presets and the web fallback

Settings stores `graphics` as `auto`, `low`, `medium`, `high`, or `ultra`. Auto is Medium when `OS.has_feature("web")` or `OS.has_feature("mobile")` is set, or when the running method is not Forward+. Auto is High on a Forward+ desktop. Picking Ultra in the browser does not try to enable SSR, SSIL, volumetric fog, SDFGI, TAA, FSR 2.2, or `Decal` nodes. Those flags are computed from the renderer, not from the menu label. Standalone Quest still takes the existing lean path (no shadows, no glow, no probe) on top of that.

`src/graphics/quality.gd` is the only place that decides this. The race view asks it for a profile and applies the result to the `Environment`, the sun, the probe, the foliage count, and the decal path. `Settings.apply_graphics()` pushes the viewport side (MSAA, TAA, FSR) as soon as the menu changes.

## What was left out on purpose

- **VoxelGI and LightmapGI bakes.** Wrong fit for procedural tracks, and the web build cannot bake them.
- **A second tonemapper in the menu.** AgX is the better default for these paint colors. ACES is documented above and is a one-line switch.
- **Depth of field.** It fights a driving camera, and Compatibility does not have it. Motion blur is absent from Godot 4.7.2 entirely, as noted above.
- **PCSS shadows.** Forward+ only, and the chase camera gains more from a tighter shadow map than from contact-hardening penumbras.
- **GPL or unlicensed packs.** Textures are ambientCG CC0, skies are Poly Haven CC0, trees and cars are Kenney CC0. Credits are in `CREDITS.md`.
