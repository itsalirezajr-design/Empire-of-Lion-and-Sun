# Empire of Lion and Sun

**Modern mobile RTS — Android / Godot 4**

A real-time strategy game set in a modern-day world (starting in 2026). The long-term vision combines a world-management layer with separate large, isometric operational battlefields.

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

This is a prototype foundation, not the complete game. The source now includes placeable barracks, armor factory and resource depot, construction timers, production queues, resource capacity, building repair/upgrades, and versioned local persistence. Godot headless CI validation is passing. A main menu, continue/new campaign, settings, in-game pause and tutorial have now been added. Android debug export is being automated; a successful artifact and physical-device test are still pending. World-map country management, online multiplayer, LAN/hotspot multiplayer, naval/air forces, and production-grade art are later milestones.

## Project layout

- `project.godot` — Godot project settings
- `scenes/Main.tscn` — main prototype scene
- `scripts/main.gd` — battle loop, controls, A* pathfinding, combat, HUD, and local save/load
- `scripts/terrain.gd` — static isometric terrain and river/road rendering
- `docs/MVP_0.1_FA.md` — technical MVP specification (Persian)
- `docs/ROADMAP_FA.md` — phased development plan (Persian)
- `docs/ANDROID_BUILD_FA.md` — Android APK build, download, and installation guide (Persian)

## Run

Open this repository as a project in **Godot 4.x**, then run the main scene. The source currently includes the first MVP battle loop, isometric terrain, mobile camera input, unit visuals, basic formations, and a mobile command HUD. It has **not yet been run in Godot or validated on a physical Android device**; headless Godot CI validation is now passing, including the expanded phase 1/2 smoke tests. Interactive desktop/mobile playtesting and physical Android device testing remain open; an Android debug APK CI build has been added and is awaiting its first verified result. A* pathfinding, base construction/production, and versioned local save/load are implemented in source.

## Design decisions

- Setting: modern day, 2026
- Genre: continuous real-time strategy (RTS)
- Camera: isometric-inspired 2D presentation
- Battle scale: large map, streamed/partitioned in later iterations
- Target: Android phones and tablets
- Planned modes: offline AI, online multiplayer, local Wi-Fi/hotspot multiplayer
- Engine: Godot 4.x
