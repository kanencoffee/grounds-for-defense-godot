# Grounds for Defense — Godot 4

> **© 2026 Kanen Coffee, LLC. All Rights Reserved.**
> Proprietary software. See [LICENSE](./LICENSE) for terms.

Coffee-themed tower defense + quality-control teaching tool, ported from the [Phaser version](https://github.com/kanencoffee/grounds-for-defense) to Godot 4.

You're a coffee geek in training. Bad coffee — stale lots, pre-ground bags, charred roasts, watered-down brews, reheated milk, and Pod-zilla — is coming for your cup. Match the right inspection tool to each defect type. Don't drink the swill.

## Quickstart

1. Install **Godot 4.3+** ([download](https://godotengine.org/download/))
2. Open Godot, click **Import** → select `project.godot` from this repo
3. Hit the **Play** button (F5). Godot will prompt you to set `scenes/main.tscn` as the main scene if it isn't already — accept.

The first import takes ~10 seconds while Godot rasterizes the SVGs. After that it boots in <1s.

## Controls

| Action | Input |
|---|---|
| Place tower | Click an empty slot ring → pick from popup |
| Sell tower | Click an existing tower (refunds 60% of cost) |
| Start wave | Click "Start Wave" button (top right) or press Space |
| Perfect Shot ability | Press **P** to arm, then click an enemy (500 dmg, 45s CD) |

## What's in the MVP

- 4 towers: Drip, Espresso, Milk Frother, Cold Brew
- 4 enemies: Stale Bean, Pre-Ground, Reheated Milk, K-Pod Tyrant (boss)
- 10 waves
- Larger sprites (~2× the Phaser version) — easier to read at a glance
- Damage numbers, hp bars, idle bob animations

## Roadmap (post-MVP)

- [ ] Audio (SFX + ambient music) — port from Phaser's procedural Web Audio
- [ ] Remaining 3 towers (Grinder, Pour-Over, Aeropress) and 2 enemies (Watery Cup, Burnt Bean)
- [ ] Particles / hit sparks
- [ ] Tower upgrade tier
- [ ] Mobile / web export

## Architecture

Single-file game logic in `scripts/main.gd` — all entities (towers, enemies, projectiles, HUD) are spawned programmatically at runtime. No per-entity `.tscn` scenes needed. This keeps the project flat and easy to edit from any IDE.

`assets/` holds the SVG sprite set. Godot rasterizes them at import time, so they look crisp at any zoom.

## License

MIT — same as the Phaser version.
