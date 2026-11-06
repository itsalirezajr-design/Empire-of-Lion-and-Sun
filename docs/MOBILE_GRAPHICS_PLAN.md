# Strike Zone — Android Graphics & Performance Plan

## Target device profile

- Reference device: POCO X6 Pro
- SoC: MediaTek Dimensity 8300-Ultra
- RAM target profile: 12 GB
- Display: 120 Hz capable; the game will target a stable 60 FPS first, not assume 120 FPS.
- Platform: Android, landscape orientation
- Engine: Godot 4.x

This is a design target, not a performance guarantee. Actual frame rate, thermals, battery use, and visual quality must be measured on the physical phone.

## Visual target

A grounded, realistic tactical FPS look inspired by competitive PC shooters, adapted for mobile:
- Warm, sunlit urban combat spaces with believable stone, concrete, metal, wood, dust, and fabric materials.
- Readable silhouettes and clean sightlines; visual detail must not obscure enemies.
- Detailed first-person weapon and hands, with reload, firing, recoil, and inspect-ready animation hooks.
- Distinctive team/player silhouettes, readable hit feedback, restrained muzzle flash and impact effects.
- Competitive HUD: minimap, round timer, team score, ammo, health, armor, crosshair, and touch controls.

All art must be original or properly licensed. Do not copy Counter-Strike maps, models, logos, sounds, or other proprietary assets.

## First vertical slice: “Old Quarter — Bombsite B”

Build one compact, polished playable area before expanding:
1. A sunlit stone lane leading into a courtyard.
2. Bombsite B courtyard with two approaches, cover crates, barrels, and a central landmark.
3. A short indoor connector and one elevated firing position.
4. One player weapon with first-person hands, firing, recoil, reload, and muzzle flash.
5. One target/bot archetype with basic idle, patrol, take-cover, and hit reactions.
6. Touch HUD and a practice-round loop.

The first slice should prove the complete mobile pipeline, not attempt a full multiplayer game.

## Rendering strategy

- Start with Godot's Mobile renderer on supported Vulkan Android devices; keep a Compatibility renderer fallback only if device testing requires it.
- Do not plan around desktop-only features such as Nanite or Lumen. Use baked/static lighting where practical and a small number of carefully controlled dynamic lights.
- Prefer static environment geometry, baked lightmaps, simple material shaders, and limited transparent effects.
- Use compressed textures (ASTC where supported, with a safe fallback); reserve the highest texture resolution for the first-person weapon and nearby hero assets.
- Use LODs for distant props, occlusion culling where useful, mesh/material atlases, and MultiMesh for repeated props.
- Keep draw calls, shadow-casting lights, particles, and overdraw under control.
- Use real-time shadows selectively; test shadow quality and distance on-device.
- Provide scalable settings for render scale, texture quality, shadows, effects, and frame cap.

## Initial performance presets

These are starting configurations to benchmark, not promises:

| Setting | Balanced (default target) | Performance |
|---|---|---|
| Frame cap | 60 FPS | 60 FPS |
| Render scale | 100%, dynamic reduction if needed | 85–90% |
| Textures | High for weapon, medium/high for world | Medium |
| Shadows | Medium, short/medium distance | Low, shorter distance |
| Effects | Medium | Low |
| Anti-aliasing | 2x MSAA if stable | Off or low-cost option |
| Environment detail | High near player, LOD at distance | More aggressive LOD |

If sustained 60 FPS is not stable after thermal soak, reduce render scale and shadow cost first. A stable 45 FPS option may be preferable to unstable 60 FPS on some devices.

## Mobile controls

- Left virtual stick for movement.
- Right-side drag area for camera look.
- Fire, aim, reload, jump, crouch, and weapon switch buttons.
- Customizable button size, position, and opacity.
- Optional gyro aiming and aim sensitivity sliders.
- Keep touch targets large enough for landscape play and avoid covering the center sightline.

## Quality and acceptance tests

Test on the actual POCO X6 Pro:
- Cold start and first-match loading time.
- 15–20 minute sustained play session to check heat and throttling.
- Average FPS and 1% low frame rate in the courtyard and during combat.
- Memory use, battery drain, shader stutter, and device temperature.
- Touch latency, camera control, and UI scaling.
- Test at native resolution and reduced render scale.

Do not label a preset “60 FPS” as achieved until the physical-device test confirms sustained performance.

## Build order

1. Finish first-person movement, camera response, and firing feel.
2. Tune weapon handling: spread, recoil, recovery, reload feedback, and weapon switching.
3. Add attacker/defender teams, timed rounds, planting, and defusing.
4. Add tactical bots with patrol, cover use, target selection, and team behavior.
5. Finish touch HUD and Android export; keep the prototype and release outputs separate.
6. Profile on the actual POCO X6 Pro and tune from measured results.
7. Add LAN sessions.
8. Add online matchmaking and authoritative multiplayer only after the offline round loop is stable.

## Current status

The repository is now Strike Zone, a first-person tactical shooter prototype; the former strategy-game direction is out of scope. Implemented foundations include first-person movement, multitouch look/move, a hitscan rifle, reload/ammo, target practice, movement/air/burst spread, and recoverable camera/weapon recoil. Automated weapon-ballistics tests and a headless main-scene smoke test now run in GitHub Actions; the latest run on 2026-11-06 passed.

The procedural arena and weapon are still greybox prototypes. Team rounds, bomb objectives, tactical bots, final touch UX, Android export validation, LAN, and online play remain future work. No physical-device performance or input test is claimed until it is actually run.
