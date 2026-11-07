# Empire of Lion and Sun

**Modern mobile RTS — Android / Godot 4**

A real-time strategy game set in a modern-day world (starting in 2026). The long-term vision combines a world-management layer with separate large, isometric operational battlefields.

**یادداشت شاخه (۷ نوامبر ۲۰۲۶):** شاخه پیش‌فرض `main` بعداً به پروتوتایپ FPS جداگانه‌ای با نام Strike Zone تغییر کرده است. آخرین وضعیت RTS پیش از آن تغییر، بدون بازنویسی `main` در شاخه `empire-rts-recovery` از commit `b26db0f` نگه‌داری شده و توسعه Empire of Lion and Sun در همین شاخه ادامه می‌یابد.

## Current milestone: MVP 0.1

The first playable milestone focuses on the battle loop only:
- Large 2D battlefield rendered in an isometric-inspired style, with static terrain separated from dynamic units
- Continuous real-time simulation
- Touch/mouse selection, two-finger camera pan, pinch zoom, and group movement formations
- Mobile command HUD with unit recruitment, stop, and select-all controls
- Three unit roles: infantry, tank, and APC
- A* grid pathfinding around a blocked river, with a road bridge
- Basic automatic combat and a simple enemy AI
- Local JSON save/load for the current battle state
- A small resource economy and a win/loss condition

This is a prototype foundation, not the complete game. The source now includes placeable barracks, armor factory and resource depot, construction timers, production queues, resource capacity, building repair/upgrades, and versioned local persistence. Godot headless CI validation is passing. A main menu, continue/new campaign, settings, in-game pause and tutorial have now been added. An ARM64 Android debug APK has now been built successfully in CI, its ZIP integrity and APK signature have been verified, and the artifact is available from the Android Actions run. Physical-device installation and touch/performance testing remain pending. World-map country management, online multiplayer, LAN/hotspot multiplayer, naval/air forces, and production-grade art are later milestones.

## Verified builds

- Godot 4.4.1 headless validation, including mobile input, formation, combat regression and win/loss tests: [successful run on 7 Nov 2026](https://github.com/itsalirezajr-design/Empire-of-Lion-and-Sun/actions/runs/42348704565).
- Latest ARM64 debug APK, built after all gameplay regression tests passed: [download artifact](https://github.com/itsalirezajr-design/Empire-of-Lion-and-Sun/actions/runs/42348704646/artifacts/13564861407). GitHub artifact retention ends 21 Nov 2026. It is debug-signed and is not a release build.

## Project layout

- `project.godot` — Godot project settings
- `scenes/Main.tscn` — main prototype scene
- `scripts/main.gd` — battle loop, controls, A* pathfinding, combat, HUD, and local save/load
- `scripts/terrain.gd` — static isometric terrain and river/road rendering
- `docs/MVP_0.1_FA.md` — technical MVP specification (Persian)
- `docs/ROADMAP_FA.md` — phased development plan (Persian)
- `docs/ANDROID_BUILD_FA.md` — Android APK build, download, and installation guide (Persian)
- `tests/navigation_smoke.gd` and `tests/mobile_input_smoke.gd` — automated battle, economy, persistence, camera-gesture and formation checks

## Run

Open this branch as a project in **Godot 4.x**, then run the main scene. Headless Godot 4.4.1 validation and the existing battle/economy/save tests have passed in CI. New simulated two-finger camera, gesture-isolation, three-unit formation and A* bridge-route tests have also passed in Godot 4.4.1 CI. An ARM64 debug APK was rebuilt after the combat fix and all smoke tests passed; its ZIP integrity and v1/v2/v3 signature checks succeeded. Installation, touch behavior, and performance on a physical Android device remain unverified. A* pathfinding, base construction/production, and versioned local save/load are implemented in source.

## Design decisions

- Setting: modern day, 2026
- Genre: continuous real-time strategy (RTS)
- Camera: isometric-inspired 2D presentation
- Battle scale: large map, streamed/partitioned in later iterations
- Target: Android phones and tablets
- Planned modes: offline AI, online multiplayer, local Wi-Fi/hotspot multiplayer
- Engine: Godot 4.x
