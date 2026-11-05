# Empire of Lion and Sun

**Modern mobile RTS — Android / Godot 4**

A real-time strategy game set in a modern-day world (starting in 2026). The long-term vision combines a world-management layer with separate large, isometric operational battlefields.

## Current milestone: MVP 0.1

The first playable milestone focuses on the battle loop only:
- Large 2D battlefield rendered in an isometric-inspired style
- Continuous real-time simulation
- Touch/mouse selection and movement commands
- Three unit roles: infantry, tank, and APC
- Basic automatic combat and a simple enemy AI
- A small resource economy and a win/loss condition

This is a prototype foundation, not the complete game. World-map country management, advanced pathfinding, online multiplayer, LAN/hotspot multiplayer, naval/air forces, and production-grade art are later milestones.

## Project layout

- `project.godot` — Godot project settings
- `scenes/Main.tscn` — main prototype scene
- `scripts/main.gd` — first playable battle-loop prototype
- `docs/MVP_0.1_FA.md` — technical MVP specification (Persian)
- `docs/ROADMAP_FA.md` — phased development plan (Persian)

## Run

Open this repository as a project in **Godot 4.x**, then run the main scene. The prototype has not yet been validated on a physical Android device; test and tune performance before treating it as release-ready.

## Design decisions

- Setting: modern day, 2026
- Genre: continuous real-time strategy (RTS)
- Camera: isometric-inspired 2D presentation
- Battle scale: large map, streamed/partitioned in later iterations
- Target: Android phones and tablets
- Planned modes: offline AI, online multiplayer, local Wi-Fi/hotspot multiplayer
- Engine: Godot 4.x
