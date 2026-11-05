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

This is a prototype foundation, not the complete game. World-map country management, advanced pathfinding, online multiplayer, LAN/hotspot multiplayer, naval/air forces, and production-grade art are later milestones.

## Project layout

- `project.godot` — Godot project settings
- `scenes/Main.tscn` — main prototype scene
- `scripts/main.gd` — battle loop, controls, A* pathfinding, combat, HUD, and local save/load
- `scripts/terrain.gd` — static isometric terrain and river/road rendering
- `docs/MVP_0.1_FA.md` — technical MVP specification (Persian)
- `docs/ROADMAP_FA.md` — phased development plan (Persian)

## Run

Open this repository as a project in **Godot 4.x**, then run the main scene. The source currently includes the first MVP battle loop, isometric terrain, mobile camera input, unit visuals, basic formations, and a mobile command HUD. It has **not yet been run in Godot or validated on a physical Android device**; full base production, and runtime/export testing remain open. A* pathfinding and local save/load are now implemented in source but still require runtime validation.

## Design decisions

- Setting: modern day, 2026
- Genre: continuous real-time strategy (RTS)
- Camera: isometric-inspired 2D presentation
- Battle scale: large map, streamed/partitioned in later iterations
- Target: Android phones and tablets
- Planned modes: offline AI, online multiplayer, local Wi-Fi/hotspot multiplayer
- Engine: Godot 4.x
