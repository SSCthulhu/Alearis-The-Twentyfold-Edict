# Alearis: The Twentyfold Edict — Art Bible

**Medium**: Browser, Vite + Three.js + TypeScript, WebGL2.
**Assets**: Environment art, ramps, VFX, and UI are generated at runtime.
Characters use CC0 KayKit meshes, textures, and animations by Kay Lousberg;
procedural figures remain the runtime fallback.
**Camera**: Locked side-on 2.5D. Everything is authored for a single viewing hemisphere; we never pay for detail the camera cannot see.

---

## 1. The Target

The reference the team agreed on is a cel-shaded boat racer: thick ink outlines, chunky flat-bottomed clouds with hard shadow shelves, posterized water and terrain, saturated but *controlled* palettes, and a HUD that feels printed rather than debug-drawn.

We are not making that game. We are stealing its **level of commitment**.

The house style is **Wind Waker–modern mythic**: a storybook-graphic world where every surface is a deliberate shape with a deliberate color, lit by two or three hard light bands, wrapped in ink, and stacked into vertical arenas that feel like illustrated plates rather than gray test levels.

The single question for any asset is: **would this read as intentional if you paused the game and printed the frame as a poster?** If the answer is "it reads as placeholder geometry with a lighting model on it," it is not shippable.

### The three failure modes we are correcting

1. **Graybox platforms.** Platforms currently read as neutral slabs with a rim light. A frost arena must read as *ice* from silhouette and color alone, with zero text labels.
2. **Mannequin characters.** Figures are single-value color blobs. Characters need color *blocking* — separated garment, skin, metal, and accent zones with different values, so the silhouette breaks into readable parts at gameplay distance.
3. **Flat empty skies.** A vertical platformer shows more sky than anything else. The sky is the single largest surface in every frame and must carry the most graphic identity.

---

## 2. Color System

### 2.1 Palette contract

Every world defines a closed palette. Nothing in a world may sample a color outside its palette family without an explicit narrative reason (Ascension gold, damage red, dice violet). A palette is not a mood board — it is a hard constraint.

Each `WorldPalette` carries:

| Field | Role |
| --- | --- |
| `skyTop` / `skyMid` / `skyBot` | Three-stop vertical sky gradient, quantized into bands |
| `skyBandCount` | How many posterization steps the sky gradient is cut into |
| `cloud` / `cloudShadow` | Cloud lit face and cloud underside shelf — must differ by at least 15% value |
| `sun` | Disc color; separate from `accent` so the sun is not forced to match UI gold |
| `fog` | Depth recession target for parallax layers |
| `accent` | The world's one loud color — used for interactables, gates, and gameplay-critical reads |
| `ink` | Outline color. Never pure black; always the world's darkest hue-shifted tone |
| `platform` / `platformEdge` / `platformDeep` | Top face, front lip, and shadowed underside of walkable geometry |
| `ambient` / `keyLight` / `fillLight` / `rim` | Scene lighting tint set |
| `ramp` | Four explicit toon band colors for this world's diffuse ramp |

### 2.2 Value discipline

Three value tiers, always:

- **Foreground (playable):** highest value contrast, most saturation, full outline weight. The player, enemies, boss, orb, and any surface you can stand on.
- **Midground (readable):** desaturated toward `fog` by 30–45%, thinner outlines, no specular banding.
- **Background (atmospheric):** desaturated toward `fog` by 55–75%, outlines optional or hairline, silhouette-only forms.

If a background element competes with the player silhouette for attention, it is wrong regardless of how nice it looks in isolation.

### 2.3 World 1 — Kallos Frost (the reference implementation)

Frost is not "white and gray." Frost is **cyan-and-cream with violet shadows**. The defining decision: ice shadows are *blue-violet*, ice lights are *warm cream*. That temperature split is what separates a frost world from a graybox.

| Slot | Hex | Notes |
| --- | --- | --- |
| Sky top | `#3f7fc4` | Real saturated blue, not pale wash |
| Sky mid | `#8fc4e8` | |
| Sky bottom | `#eaf4fb` | Cold haze at the horizon |
| Cloud lit | `#ffffff` | |
| Cloud shadow | `#a9c9e6` | Hard shelf under every puff |
| Sun | `#fff3c8` | |
| Accent | `#ffc94a` | Gold — gates, chests, interactables |
| Ink | `#16283c` | Deep blue-black; never `#000` |
| Platform top | `#d8f2ff` | Ice sheet |
| Platform edge | `#57b6e4` | Saturated cyan lip — this is the shape-reader |
| Platform deep | `#2f6f9e` | Shadowed underside / crevasse |
| Ramp bands | `#4a6f9c` → `#7fa6c8` → `#bcd8ee` → `#ffffff` | Cold shadow into warm-white light |

### 2.4 Worlds 2–4 identities (short form)

- **World 2 — Void Portals:** near-black violet field, magenta and teal as the only two chromatic voices. Ink is almost the background color, so silhouettes are carried by rim light instead of outline.
- **World 3 — Forge Arcs:** hot orange ambience against cold tesla-blue accents. The complementary clash *is* the identity. Metal is dark and desaturated so the glow reads.
- **World 4 — Dice Realm:** twilight violet sky, rose midband, gold horizon. Porcelain-ivory platforms with dark violet edges. Reads as a lit gaming table at dusk.

### 2.5 Colour pipeline (non-negotiable)

Three.js converts every `THREE.Color` from sRGB into linear working space on construction, but it only applies the matching linear→sRGB *output* encoding to its own built-in materials. Custom `ShaderMaterial`s get no encoding at all.

That means a hand-authored NPR shader will write linear values straight into an sRGB framebuffer, and every palette hex will render substantially darker and more saturated than the value written in this document. A `#57b6e4` cyan lands on screen as a near-navy. This single mismatch is enough to make a fully committed palette read as graybox.

The rules:

1. **Every custom NPR fragment shader ends with `alearisEncode()`** (exported from `CelMaterial.ts`). Cel surfaces, outlines, the sky, and the post composite all do this.
2. **Every render target that receives beauty output declares `texture.colorSpace = THREE.SRGBColorSpace`.** Without it, three skips encoding for built-in materials drawn into that target, so unlit `MeshBasicMaterial` VFX render darker than the cel surfaces around them.
3. **Ramp and matcap textures store linear values**, because custom shaders get no automatic sampler decode either. `writeRampBands` relies on `THREE.Color`'s already-linear channels for exactly this reason.
4. **Procedural surface textures are authored around mid-grey** and used as a symmetric multiplier, which makes them colour-space agnostic.

If a colour on screen does not match the hex in §2.3, assume this pipeline before re-tuning the palette.

### 2.6 The sky is only ever seen through a slit

The camera is locked side-on, so it sees roughly `d.y ∈ [-0.35, +0.35]` of the dome — a narrow horizontal band, not a hemisphere. Two consequences that are easy to get wrong:

- **Compress the gradient into the visible band.** Spreading `skyBot → skyMid → skyTop` across the full hemisphere puts the entire interesting range off-screen and leaves a flat wash. The vertical ramp is remapped so the full three-stop gradient lands inside the camera's slice.
- **Cloud UVs must be angularly uniform.** A mapping that normalises azimuth to −1..1 while leaving elevation in raw units is roughly π times denser vertically than horizontally, which stretches cloud cells until one puff spans the whole screen. Both axes are in radians.

---

## 3. Outline Rules

Outlines are the signature of the style. They are not optional and they are not uniform.

### 3.1 Two-system approach

1. **Inverted hull** (`createOutlineMesh`) — carries the *silhouette*. Back-faced, pushed along smoothed normals, view-distance compensated so width stays roughly constant on screen.
2. **Sobel post pass** (`PostPipeline`) — carries *interior creases* only. Its threshold must stay high enough that it never doubles the hull outline into a fat smear.

### 3.2 Width hierarchy

Width is a statement about importance. Assign by role, never by convenience:

| Role | Hull width |
| --- | --- |
| Player, boss | `0.045` |
| Enemies | `0.038` |
| Walkable platform bodies | `0.035` |
| Platform lips, props, gates | `0.020–0.026` |
| Small details (pips, rivets, crests) | `0.008–0.016` |
| Midground parallax slabs | `0.018` |
| Far background | none — silhouette against sky is enough |

### 3.3 Ink color

Ink is always `palette.ink` — a hue-shifted near-black that belongs to the world. Pure black is banned; it flattens the frame and reads as a rendering bug against saturated skies.

Emissive elements (glow strips, orb cores, portal cores, damage numbers) get **no outline**. Outlines say "solid object"; emissives say "light."

---

## 4. Sky Rules

The sky is the largest single surface. It gets the most attention.

### 4.1 Non-negotiables

- **Posterized gradient.** The vertical ramp is cut into `skyBandCount` discrete steps with a small dither at the seams so banding reads as *deliberate silkscreen*, not as 8-bit color loss. Never ship a smooth `mix()` wash.
- **Chunky clouds with flat bottoms.** Clouds are built from summed metaball-style blobs thresholded to a hard alpha edge. Their bottoms are flatter than their tops. A cloud that is a soft noise smear is a failed cloud.
- **Cloud ink.** Every cloud gets a dark contour band derived from the same field the cloud alpha comes from — the cloud silhouette is inked exactly like a mesh would be.
- **Cloud shelf shading.** Two-tone only: lit top face in `cloud`, hard shadow shelf in `cloudShadow`, with the split driven by the sun direction. No gradient between them.
- **Layered drift.** At least two cloud strata moving at different speeds. Parallax in the sky sells vertical motion better than any parallax on the ground, because a vertical platformer's camera travels *up*.
- **A real sun.** A hard-edged disc with a thin inked ring and a discrete halo step. Not a bloom blob.

### 4.2 Per-world sky treatment

- **W1 Frost:** bright banded blue, thick cumulus, high cloud coverage, warm sun low-right.
- **W2 Void:** near-black bands, sparse torn storm sheets, no sun — a cold void-eye instead.
- **W3 Forge:** ember-lit smoke strata, heavy coverage near the horizon, sun occluded.
- **W4 Dice:** the widest band count, big slow flat-bottomed puffs over a rose/gold horizon.

---

## 5. Character Silhouette Rules

### 5.1 Silhouette first

Read at a glance, at gameplay distance, in pure black. If two character types are indistinguishable as filled black shapes, one of them is wrong. Distinguishing features must be *structural* — helmet crest, hood peak, shoulder mass, cape, weapon length — never texture.

### 5.2 Color blocking (the mannequin fix)

Every figure is divided into **at least four value zones**:

1. **Primary garment** — the largest area, mid-value, the character's identity color.
2. **Secondary/armor** — a distinctly different value (at least 25% apart) on shoulders, chest plate, boots.
3. **Skin/bone** — warm and light, always the lightest large zone on the figure, used to draw the eye to head and hands.
4. **Accent** — the smallest area, the most saturated: sash, gem, weapon glow, eye light. Never more than ~10% of the figure's surface.

Additionally: **the head must be lighter than the torso**, and **the feet must be darker than the legs**. That single rule grounds a figure and stops it reading as a floating mannequin.

### 5.3 Proportion

Heroic-stylized, not realistic. Roughly 6 heads tall, oversized hands and feet, tapered waist, chunky boots and pauldrons. Silhouettes should have **at least one asymmetry** (a cape on one side, an offset weapon, a single pauldron) so facing direction is unambiguous.

### 5.4 Animation posture

Every figure carries a continuous idle — breath, weapon sway, cape drift. A perfectly still figure reads as a broken build even when everything else is polished.

---

## 6. Platform & Material Rules

### 6.1 A platform is three surfaces, not one box

1. **Top face** — the brightest, most saturated. This is what the player lands on and must read as *safe standing ground* instantly.
2. **Front lip** — a distinct band in `platformEdge`, thicker and more saturated than the top. This is the primary shape reader against the sky.
3. **Underside / body** — `platformDeep`, notably darker. Gives thickness and stops platforms reading as paper cutouts.

### 6.2 Material identity per kind

- **Ice:** translucent-reading cyan top with a hard white crest line, irregular sub-surface facets, snow accumulation on upper edges, icicle fringe on undersides. Warm cream specular band that breaks along facet edges. Must never read as gray stone.
- **Void:** dark polished slabs with a thin teal energy seam along the lip and a magenta underglow. Low diffuse, high rim.
- **Forge:** dark iron plate with visible rivets and a molten seam along the front lip. Specular band is wide and hot.
- **Dice:** porcelain ivory with dark violet chamfered edges and inset pips. Highest diffuse, cleanest surfaces.

### 6.3 Surface breakup

Flat single-color boxes are the enemy. Every walkable surface needs **at least two of**: a color-blocked lip, a procedural facet/pattern texture, an accumulation element (snow/rust/frost), and an edge chamfer. Procedural canvas textures are the cheap win here — a 256px canvas with hand-drawn facet strokes costs nothing and destroys the graybox read.

### 6.4 Lighting model

Four-band toon ramp, quantized hard, per-world band colors. The rules:

- **Bands must be visible.** If you cannot count the bands on a sphere, the ramp is too soft.
- **Shadow band is hue-shifted, not just darkened.** Frost shadows go blue-violet, forge shadows go red-brown. Multiplying by gray is the single fastest way to look like a graybox.
- **Rim light is a silhouette tool, not a glow.** Tight power, palette-tinted, strongest on foreground actors and effectively off on background slabs.
- **Specular is a hard band**, thresholded, never a Blinn blob. Ice and metal get it; cloth and stone do not.

---

## 7. VFX Rules

- **Shapes, not sprites.** Hits are expanding inked rings, chevrons, and shard bursts — flat-shaded, hard-edged, additive only where light is genuinely being emitted.
- **Two-frame logic.** Effects snap to a big pose, hold ~2 frames, then collapse. Smooth continuous fades read as engine particles, not as authored animation.
- **Palette-locked.** Effects use the world accent plus one neutral. Damage red and Ascension gold are the only universal exceptions.
- **Ascension Charge is the brightest thing on screen**, always, in every world. It is the gameplay-critical object and the art must never let anything out-compete it.
- **Screen-space restraint.** No bloom soup. Ambient motes stay behind the play plane and below 50% opacity.

---

## 8. HUD Polish Rules

- **Printed, not debug-drawn.** Panels are dark translucent plates with gold hairline trim and a subtle inner bevel — the same ink/accent language as the 3D.
- **Chamfered corners** on every panel. Right-angle rectangles read as programmer UI.
- **Bars are three layers:** dark inset track, animated fill, and a bright leading edge cap. A lag/ghost layer behind the fill for damage taken.
- **Type hierarchy:** one display weight for numbers, one small caps weight for labels. Two sizes maximum per panel.
- **Dice HUD is the signature widget.** It should look like an engraved gold instrument, not a number readout — it is the game's core mechanic and the thing players screenshot.
- **Everything resolution-independent**, authored for 2560×1440, scaled by device pixel ratio.

---

## 9. Anti-Patterns — What Must Never Ship

1. Gray or neutral-desaturated platforms of any kind, in any world.
2. Smooth sky gradients without posterization bands.
3. Soft noise-smear clouds without hard edges and shadow shelves.
4. Pure black (`#000000`) outlines.
5. Single-color untextured character bodies (mannequins).
6. Blinn-Phong specular blobs, PBR roughness/metalness workflow, or environment cubemaps.
7. Shadow bands produced by multiplying the albedo by gray.
8. Uniform outline width across every object in the scene.
9. Background elements with the same saturation and outline weight as foreground actors.
10. Bloom used to hide a lack of authored contrast.
11. Right-angle debug-rectangle HUD panels.
12. Any external asset without an approved license and checked-in attribution.
    KayKit CC0 character assets are the approved actor-art exception.
13. Effects that fade smoothly from full to zero over a long tail.
14. Character or prop colors sampled outside the active world palette.
15. A custom `ShaderMaterial` that writes `gl_FragColor` without `alearisEncode()`.
16. Backdrop geometry wide enough to wall off the sky. Vertical arenas need columnar silhouettes with gaps, never full-width slabs.
17. Backdrop layers that recede toward black. Distance approaches the *sky* colour — that is what aerial perspective does.

---

## 10. Implementation Plan

Ordered by visual impact per unit of risk. Each item lists the file, the change, and the acceptance criteria that must be demonstrably true before the item is considered done.

### Pass 1 — Foundation (biggest wins) — **IMPLEMENTED**

**1.1 `src/render/Palettes.ts` — palette schema expansion + World 1 rebuild**
Add `cloudShadow`, `sun`, `platformDeep`, `skyBandCount`, and an explicit four-color `ramp` tuple to `WorldPalette`. Rebuild World 1 around the cyan/cream/violet frost identity above; extend Worlds 2–4 to the new fields without changing their established identities.
*Acceptance:* every world exposes a full ramp tuple; World 1's sky top is a saturated blue rather than a pale wash; no palette field is a neutral gray.

**1.2 `src/render/SkyDome.ts` — full rewrite**
Replace the single-octave value-noise smear with: posterized band gradient with seam dither, two drifting cloud strata built from FBM thresholded to hard alpha, per-cloud ink contour derived from the same field, sun-directional two-tone cloud shelf shading, a hard-edged sun disc with inked ring and stepped halo, and per-world treatment branches.
*Acceptance:* clouds have visible hard silhouette edges and a dark contour; cloud undersides are a distinct flat shadow tone; the vertical gradient shows countable bands; two cloud layers move at visibly different speeds.

**1.3 `src/render/CelMaterial.ts` — ramp/rim/spec tuning + surface texture support**
Drive the shared ramp from the active world palette. Sharpen ramp quantization so bands are countable. Add optional albedo-modulating procedural texture support, a `texScale` control, an explicit `outlineWidth`-agnostic hue-shifted shadow path, and procedural texture generators for ice facets, brushed metal, and speckled stone.
*Acceptance:* bands are countable on a sphere; shadow band is hue-shifted rather than gray-multiplied; a textured material shows visible surface breakup at gameplay distance.

**1.4 `src/world/ArenaBuilder.ts` — platform material overhaul**
Replace the single `platformMat`/`edgeMat` pair with a per-kind material factory producing the three-surface treatment (top face, saturated lip, dark body), procedural surface textures per kind, and kind-specific accumulation elements.
*Acceptance:* an ice platform reads as ice from color and silhouette alone; the front lip is visibly more saturated than the top; the body underside is visibly darker; no walkable surface is a flat single-color box.

**1.5 Colour pipeline correction** *(not in the original plan — found while reviewing frames)*
Add `alearisEncode()` to the cel, outline, sky, and post-composite shaders, and declare the beauty target's colour space. See §2.5.
*Acceptance:* rendered colours match the authored palette hexes; unlit VFX sit at the same exposure as the cel surfaces behind them.

**1.6 `src/world/ArenaBuilder.ts` — backdrop rebuild** *(not in the original plan — found while reviewing frames)*
The parallax backdrop was full-width slabs receding toward black, which occluded the sky in every world and produced the "flat empty sky" symptom. Rebuilt as sparse columnar spires with angular caps, biased toward the flanks, receding toward the sky colour.
*Acceptance:* sky is visible behind the play space at every camera height; no backdrop element spans more than roughly a tenth of the arena width.

**1.7 Lighting model retune** *(not in the original plan — found while reviewing frames)*
With colour corrected, top faces and front faces were landing in the same ramp band, so every box read flat. The default key was raised to an upper-right view-space direction and the ambient lift reduced.
*Acceptance:* a platform shows at least three distinct ramp bands across its top, front, and shadowed side.

### Pass 2 — Characters and Actors — **IMPLEMENTED**

**2.1 `src/actors/ProceduralFigure.ts` — color blocking pass**
`deriveZones()` replaces `mergeColors()` and resolves every figure into the §5.2 four-zone palette (`primary` garment, `secondary` plate + `secondaryDark` limb plate, `flesh`, `accent`, plus a derived `boot` and `hood`). `ensureLighter`/`ensureDarker` enforce head-lighter-than-torso and feet-darker-than-legs by luminance rather than trusting each hand-authored palette. The torso block now takes the garment colour with the plate layered on top, so the chest is never one continuous value; upper arms take plate, forearms flesh, thighs garment, shins the darker plate, feet the darkest zone. Rogue gains an asymmetric sash, mage and necromancer a half-mantle.
*Acceptance:* met — largest single zone on a knight is ~32% (garment); every class shows head, torso, limb, and foot as four separate values.

**2.2 `src/actors/ProceduralFigure.ts` — outline weight hierarchy**
`OUTLINE_ROLE` maps seven part roles (`core`/`head`/`limb`/`plate`/`prop`/`detail`/`hairline`) onto multipliers of a per-figure base width — 0.045 player, 0.043 elite enemy, 0.038 enemy — with a mild size coupling so a golem out-inks a minion without overriding role. Every `addOutlinedMesh` call site now passes a role, not a literal.
*Acceptance:* met — torso ink is ~8× a skull socket's; player body ink exceeds every enemy's.

**2.3 `src/boss/BossVisual.ts` — boss scale and phase language**
Boss ink table runs 0.075 (core) down to 0.022 (detail), above every other actor. The shell is pushed to 82% toward black with rim held at 0.3 so the boss is the darkest large mass on screen and its silhouette separates from a bright sky; the accent is restricted to chest plate, pauldrons, crown and brow. A three-spire asymmetric crown and asymmetric pauldrons break the arena's horizontal ledge rhythm. Six solid hex shield plates ring the core: present when protected, flying outward and shrinking when the DPS window opens. The core gem is now wrapped in a rig group so its vulnerable-state pulse scales the inverted-hull outline with it — previously the ink vanished exactly when the target mattered most.
*Acceptance:* met for silhouette, ink weight, and shield/DPS read. Phase-gate colour shifts beyond `vulnerable` still need the controller to expose phase state.

**2.4 `src/enemies/*` figure wiring**
All six enemy kinds flow through `deriveZones`. `skeletonMage` gained an antler crown so it no longer shares a silhouette with the hooded `necromancer`; `meleeKnightAdd` moved from ivory to tarnished bronze so it reads as an enemy rather than a recolour of the player knight.
*Acceptance:* met — golem (mass + club), minion (small + claws), rogue skeleton (hood + bow arc), skeleton mage (antlers + staff), necromancer (hood + cape + staff), knight add (helm + sword) are each distinct in outline.

### Pass 3 — Effects and Interface

**3.1 `src/vfx/VfxSystem.ts` — shape-based NPR effects — IMPLEMENTED**
`setVfxPalette()` locks dust, impact, and arc colours to the active world; `Game.applyWorldVisuals` refreshes it alongside the ramp and sky. Scale now uses a front-loaded snap curve instead of a linear grow, and the fade is a fixed `FADE_TAIL_SEC` (0.11s) tail rather than the last 30% of a variable lifetime. Attack arcs, dodge slashes, crit stars, and ground telegraphs get an ink backing shape — the 2D equivalent of the inverted hull.
Fixed along the way: the fade loop was writing `opacity = 1` onto every tracked material during the hold, so translucent telegraph fills and shield shells rendered fully opaque. Materials now carry an authored base opacity that the fade multiplies. `makeMaterial` also always sets `transparent`, since an opaque material cannot fade out and simply popped.
*Acceptance:* met — fade tail is 0.11s regardless of lifetime; smoke and secondary colours resolve from the world palette.

**3.5 `src/render/SkyDome.ts` — below-horizon depth (unplanned, required)**
The vertical gradient bottomed out into a single pale value that owned the lower third of every vertical arena. A `uDepth` tone (world ink pulled 42% toward fog) now ramps in below the horizon in four hard steps, giving the space under the platforms weight. World 1 cloud coverage dropped to 0.3 and ink weight rose to 5px near / 3px far so clouds read as discrete outlined puffs rather than a continuous overcast smear.

**3.6 `src/world/ArenaBuilder.ts` — backdrop spire facets (unplanned, required)**
Backdrop columns were front-facing boxes, so the camera saw one flat face and they read as pasted blue bars. They are now five-sided tapered shafts: the camera catches three faces and the toon ramp splits each spire into its own value bands. Caps narrowed and lengthened into real peaks, and the far layer regained a hairline ink.

**3.2 `src/boss/AscensionCharge.ts` — brightest-object guarantee — IMPLEMENTED**
The additive glow sphere is gone; the orb is now a hard-edged stack of flat rings in the XY plane, which always face the locked side camera. Critically, the orb is a **universal exception to palette lock**: deriving its colour from the boss accent made it pale cyan inside a pale cyan frost world, where nothing can out-read anything. It keeps a fixed warm identity (`ORB_CORE_COLOR` / `ORB_HALO_COLOR`) with a dark contour ring between the corona and the world, so it separates against a white sky as well as a dark one. Ring tubes thickened, and their ink dropped to 0.007 — at 0.022 the hull ate a third of a 0.075 tube and the orb read as a dark circle.
*Acceptance:* met — the orb is the hottest and most saturated element in the frost frames, which was the hardest palette for it.

**3.7 `src/ui/UiTheme.ts`, `src/ui/HudRenderer.ts` — bar readability — IMPLEMENTED**
`fillBar` takes a `BarOptions` with a lag-ghost ratio and a bright leading-edge cap. `HudRenderer` tracks a ghost per bar: gains snap forward, losses hold for `GHOST_HOLD_SEC` and then drain, so a hit is legible as an amount rather than as a bar that is simply shorter. Applied to player HP, player shield, and boss HP.

**3.3 `src/ui/HudRenderer.ts` — printed-panel polish**
Chamfered dark plates with gold hairline trim, three-layer bars with lag ghosts and leading-edge caps, two-tier type hierarchy.
*Acceptance:* no right-angle rectangles; every bar shows a distinct leading edge; panel trim uses palette accent.

**3.4 `src/dice/DiceMeter.ts` — signature widget**
The dice range readout becomes an engraved gold instrument with an arc gauge and pip marks.
*Acceptance:* dice HUD is the most visually distinctive element in the interface.

### Pass 5 — Framing (unplanned, required) — **IMPLEMENTED**

**5.1 `src/camera/GameCamera.ts`, `src/Game.ts` — boss framing solve**
The boss root sits at its feet while the crown reaches roughly six units of scale above it, so every camera call that aimed at `bossVisual.position` framed the ankles and clipped the head off the top. `BossVisual` now publishes `visualCenterY` and `visualHalfHeight`; `Game.getBossFocus()` aims at the centre. `GameCamera.solvePullBack()` replaces the fixed `sideDistance * 1.12` with a real solve from the field of view — a constant multiplier cannot work when a tier-8 boss is twice the height of a tier-1 boss. HUD safe areas are expressed as **fractions of frame height**, not world distances, because the boss health bar always covers the same share of the screen and a world-unit constant under-reserves exactly when the boss is tallest.

**5.2 `src/boss/BossVisual.ts` — tier scale**
Per-tier growth dropped from 0.1 to 0.062. At the old rate the Sovereign stood ~12.7 units against a 3.8-unit player, which exceeded any pullback that keeps the player legible. A boss that cannot share the frame with the player is not monumental, it is off-screen.

**5.3 `src/actors/ProceduralFigure.ts` — helmet detail**
The helmet dome was a single value and read as a lightbulb at gameplay distance. It now carries four: bright dome, darker brow ridge and cheek guards, a wide ink visor slot, and the accent crest.

### Pass 4 — Depth and Atmosphere

**4.1 `src/world/ArenaBuilder.ts` — parallax depth grading**
Enforce §2.2 desaturation tiers on the three backdrop layers; add a fourth silhouette-only far layer with no outlines.
*Acceptance:* backdrop layers are measurably desaturated toward `fog` by tier; far layer carries no ink.

**4.2 `src/vfx/ContactShadows.ts` — grounded actors — IMPLEMENTED**
Shadow discs are octagonal rather than round so the contact patch reads as drawn, and `setTint()` re-tints the pool from the world's ink on every palette change. Near-black shadows went muddy against a saturated palette; base opacity rose to 0.42 now that the colour sits inside the palette.

**4.3 `src/vfx/ContactShadows.ts` — original entry**
Palette-tinted, hard-edged contact shadows that scale with height above the platform.
*Acceptance:* no actor appears to float; shadows are palette-tinted rather than black.

**4.3 `src/render/PostPipeline.ts` — edge and grade tuning**
Retune the Sobel threshold against the new hull weights so it contributes creases only. Add a light per-world color grade lift.
*Acceptance:* Sobel never visibly doubles a hull outline; the grade shifts perceptibly between worlds.

### Pass 6 — Cloud shape language and the lower frame — **IMPLEMENTED**

**6.1 `src/render/SkyDome.ts` — placed cumulus instead of thresholded noise**
The clouds were an FBM field with a flat-bottom cut. Noise gives an amorphous stain however it is cut, so every attempt to fix the shape by moving the threshold only traded one stain for another. Clouds are now built as literal geometry in the shader: `cumulus()` unions seven circular lobes — four wide ones seated on a base, three smaller ones stacked above — and intersects the result with a half plane to keep the base flat. The field is positive inside and zero exactly on the silhouette, so raising the threshold erodes every lobe evenly instead of slicing puffs in half, and `fwidth` stays meaningful for a constant-weight ink contour.

The `threshold` parameter changed meaning: it is now an erosion depth into the lobes, not a density cut. The eye-line falloff rides on it, shrinking clouds through the arena band rather than carving them.

Two performance decisions are load-bearing, because the naive version tripled per-pixel cost and stalled the screenshot harness outright. The shadow-shelf sample shares every lobe parameter with the primary sample and is computed in the same loop, rather than as a second full evaluation of the field. And each lobe unpacks its offset and radius from **one** hash rather than two.

**6.2 `src/render/SkyDome.ts` — cloud sea at the horizon**
A vertical arena spends most of its framing looking out over empty space, and the sky gradient bottoms out into one pale value there — the lower half of the frame was a flat wash however good the arena itself was. The same lobe primitive, with its half-plane **unioned** below the base rather than intersected above it (`baseCut < 0`), produces one continuous mass with a lumpy inked crown that fills everything beneath. It is drawn before the below-horizon depth ramp, so the sea bands away with distance instead of sitting on the drop as one flat sheet. Gated to `d.y < 0.12`; the branch is coherent across the screen, so the upper sky never pays for it.

**6.3 `src/world/ArenaBuilder.ts` — near cloud banks**
Three parallax layers of overlapping flattened lobes below the lowest platform, purely decorative — nothing enters the platform list, so the sea is never standable.

Two mistakes worth recording, because both are general:
- **Do not ink a mass built from overlapping meshes.** An inverted hull per lobe draws a contour along every internal seam, which turns a cloud bank into a pile of boulders. The dome's sea carries the outlined horizon; these banks read on value alone.
- **Cloud is a bright mass with a shelf under it, not a lit-and-shadowed solid.** Give a sphere a full toon terminator and it stops being cloud and becomes rock. High ambient, shallow shadow bias, shadow pulled most of the way back toward the lit value.

Recession pulls toward the sky's mid tone rather than fog, so the banks land clearly below the white platforms instead of competing with them.

**6.4 `src/vfx/VfxSystem.ts` — directional impact shapes**
Rings say something happened here; a chevron says which way the force went. `chevronGeometry()` plus `addShardFan()` throw inked arrowheads outward along a given angle, with the centre shard longest so the fan has a leading spike rather than a symmetric comb. Wired into `spawnAttackArc` along the swing and `spawnCritStars` on four quadrants, and exposed as `spawnImpactShards()` for hits that need an explicit direction.

**6.5 `src/actors/ProceduralFigure.ts` — taper**
Uniform-width limbs and slab torsos are the single biggest reason a procedural figure reads as a mannequin, ahead of colour blocking. `taperGeometry()` squeezes a mass toward its lower end; limbs narrow toward the extremity and the torso and chest plate narrow toward the waist. Applied before the hull is built so the outline follows the new silhouette.

### Pass 7 — Cull, jitter, frame — **IMPLEMENTED**

**7.1 `src/render/SkyDome.ts` — cull whole clouds, never erode them**
Keeping clouds off the play space by raising the threshold through a band was wrong in kind, not in degree. The threshold is a *per-pixel* test, so a cloud straddling the band gets its lower half eaten and survives as a half dome — a pebble, not a smaller cloud. Placement is now culled *per cell*: a cloud whose own base sits below `eyeGuard` is skipped entirely, so a cloud is either fully present or fully absent and the erosion ramp is gone. The strata bases moved up to sit above the guard line, which the guard then enforces as a hard floor.

**Rule: any suppression of a shape must be decided from the shape's own placement, never from the shading pixel's position.** The second gives you fragments of the thing you were trying to remove.

Each cell also carries a horizontal jitter of up to a quarter cell, so the strata no longer beat out an even rhythm across the sky. A quarter cell is the ceiling: any further and a cloud can escape the three-cell neighbourhood and get clipped at a seam.

**7.2 `src/camera/GameCamera.ts` — framing centre solve**
The vertical focus was a fixed-bias lerp between player and boss. That cannot frame two subjects when the reserved HUD bands are asymmetric — the point that balances a 19% top band against a 7% bottom band is not the midpoint, and the error is worst exactly where the separation is widest, which is why the orb-carry shot cut the crown. `solveFramingCentre()` now returns the centre at which both subjects clear their own side's band at the smallest pull-back that can do it.

`constrainFocus()` also releases its ceiling while a second subject is being framed. A boss hovers above the platforms the arena bounds were built from, so clamping to those bounds dragged the focus back down and undid the solve. The floor still holds, so the camera never drops through the arena.

Side effect worth keeping: because the centre is now optimal, the required pull-back is *smaller*, and bosses read considerably more monumental than they did under the old wide shot.

---

## 11. Golden Rule

Every frame is an illustration. If a surface has no deliberate color decision, no deliberate shape decision, and no ink, it is not finished — regardless of whether the lighting model is technically running on it.
