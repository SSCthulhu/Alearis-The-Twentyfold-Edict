# Alearis: The Twentyfold Edict (Web)

Cel-shaded 2.5D vertical action-platformer roguelite — **Vite + Three.js + TypeScript**.  
World art, audio, UI glyphs, and music are generated in code. Production actor
meshes and animations use the CC0 KayKit character packs by Kay Lousberg.

## Run

```bash
cd web
npm install
npm run dev
```

Open the URL Vite prints (default `http://localhost:5173`).

## Controls

| Action | Keys |
|--------|------|
| Move | `WASD` / Arrows |
| Jump / Double Jump | `Space` |
| Dash / Roll (2 charges) | `Shift` |
| Light Attack | `J` / LMB |
| Heavy Attack | `K` / RMB |
| Ultimate | `U` / `F` |
| Defend | `L` / `Q` |
| Invoke Dice Meter | `R` (at 100 charge) |
| Interact (chest / orb) | `W` / Jump / Light near target |
| Drop Ascension Orb | Heavy while carrying |
| Pause / Settings | `Esc` |

## Run Flow

**Main Menu → Character Select (Knight / Rogue / Mage) → World 1–3 → Final Boss → Victory / Death**

Each world: Floors 1–4 combat, Floor 5 boss. After combat floors: chest → 5 modifier cards. After world bosses: victory dice roll → relic pick (max 3). After World 3: final boss selected by dice (`1→A … 20→E`).

Full run target: **15–20 minutes**.

## Dice Is Law

- `dice_min` / `dice_max` clamped 1–20 (default start 10–10; meta escalate after final clear)
- All meaningful RNG via `run_seed` + domain streams (`modifier_options`, `victory_reward`, `relic_choices`, `final_boss`, `encounter`, `boss_projectiles`, `dice_meter`, …)
- Floor modifiers: world contracts with deltas −2/−1/0/+1/+2 (`0` = heal only); reset on world change
- Dice Meter: charge from kills / elites / perfect dodge / damage milestones / boss kill / fast clear → Council vs Divine events (temporary; never run-ending)
- Victory roll → relic band: ≤8 Survival, ≤14 Core, else Greed/Damage

## Worlds & Bosses

| World | Identity | Boss |
|-------|----------|------|
| 1 | Frost / pale gold (vertical) | **Kallos, the Frost Golem** |
| 2 | Void teal / magenta + portals | **Vesperra, Gate of Hollow Stars** |
| 3 | Forge amber / cobalt (horizontal) | **CRIT-0N, the Forge Equation** |
| Final | Dice-realm white gold / umber | Pale Wager · Choir of Broken Sevens · Umbra of the Bent Die · Aureline the Loaded Saint · **Twentyfold Sovereign** |

Boss loop: Ascension Charge orb → charge at stations → deliver to socket → DPS window → adds / patterns cycle.

## Architecture Map

```
src/
  Game.ts                 # Loop, floor flow, harness API (window.__ALEARIS__)
  core/                   # RunState, SeededRng, EventBus, types
  dice/                   # Range, meter, Council, modifiers, victory rolls
  relics/                 # Database (~40), effects, offers
  player/                 # Input, controller, combat, health, buffs/debuffs
  enemies/                # Platform-aware cast + specializations
  boss/                   # Ascension, controller, identities, bullets, visuals
  world/                  # ArenaBuilder, Encounter, FloorProgression
  render/                 # CelMaterial (ramp/matcap/outlines), SkyDome, PostPipeline
  camera/                 # Locked side PerspectiveCamera + cinematics
  combat/                 # Projectiles (instanced), damage numbers, statuses
  vfx/                    # Hard-edged cel VFX pools
  audio/                  # Web Audio engine, SFX, per-world music beds
  ui/                     # Canvas HUD + crafted screen panels
  performance/            # Adaptive pixel ratio + particle budgets
harness/                  # Playwright retina screenshot scenarios
```

## Screenshots / Critics

```bash
npm run screenshots
```

Frames land in `harness/frames/`. Drive scenarios via:

```js
await window.__ALEARIS__.setScenario('orb_carry') // menu | combat | dps_window | …
```

## Art Direction

NPR / Wind Waker–modern cel shading: quantized ramp lighting, inverted-hull outlines, Sobel interior edges, Fresnel rim, banded specular, fake matcap reflections — **never PBR**.

## Scripts

| Script | Purpose |
|--------|---------|
| `npm run dev` | Local play |
| `npm run build` | Production bundle |
| `npm run typecheck` | Strict TS |
| `npm run screenshots` | Playwright harness |

## Note on the Godot Repo

The parent repository’s Godot project is **design reference only**. This `web/`
game does not port meshes, textures, audio, shaders, or scenes from Godot.
KayKit assets are independently licensed under CC0; see
`public/assets/kaykit/LICENSE_KAYKIT.txt`.
