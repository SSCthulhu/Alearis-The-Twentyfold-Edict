import * as THREE from 'three';
import { SRGB_ENCODE_GLSL } from './CelMaterial';
import { getPalette, type WorldPalette } from './Palettes';

const SKY_VERT = /* glsl */ `
varying vec3 vDir;
void main() {
  vDir = normalize(position);
  vec4 clip = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  // Force to far plane
  gl_Position = clip.xyww;
}
`;

const SKY_FRAG = /* glsl */ `
${SRGB_ENCODE_GLSL}
uniform vec3 uTop;
uniform vec3 uMid;
uniform vec3 uBot;
uniform vec3 uFog;
uniform vec3 uDepth;
uniform vec3 uInk;
uniform vec3 uSunDir;
uniform vec3 uSunColor;
uniform vec3 uCloudColor;
uniform vec3 uCloudShadow;
uniform float uBandCount;
uniform float uTime;
uniform float uCoverage;
uniform float uCloudFreq;
uniform float uCloudStretch;
uniform float uSunDisc;
uniform float uSunSize;
uniform float uHaloSize;
uniform float uStars;
varying vec3 vDir;

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

/**
 * Panoramic mapping in radians on both axes. Stable across the whole dome
 * including the horizon, which a d.xz/d.y projection is not, and angularly
 * uniform, which a normalised-azimuth mapping is not — mixing the two is what
 * stretches cloud cells until a single puff spans the entire screen.
 */
vec2 panUv(vec3 d) {
  return vec2(atan(d.x, d.z), asin(clamp(d.y, -1.0, 1.0)));
}

/**
 * One cumulus: a row of circular lobes with a second, smaller row stacked on
 * top, intersected with a half plane to keep the base flat. The result is
 * positive inside the cloud and zero exactly on its silhouette, so raising the
 * threshold erodes every lobe evenly instead of slicing puffs apart, and
 * fwidth stays meaningful for a constant-weight ink contour.
 */
float cumulus(vec2 q, vec2 qs, float seed, float puff, float baseCut, inout float shelf) {
  float d = -1.0;
  // Seven lobes, the lower four wider and seated on the base. Each lobe costs
  // one hash, unpacked into offset and radius — two hashes per lobe doubles the
  // per-pixel cost of the whole sky for no visible gain in irregularity.
  for (int i = 0; i < 7; i++) {
    float fi = float(i);
    float h = hash21(vec2(seed + 2.1, fi));
    float jx = fract(h * 17.13) - 0.5;
    float jr = fract(h * 53.71);
    float lr;
    vec2 c;
    if (i < 4) {
      lr = (0.115 + jr * 0.075) * puff;
      c = vec2((fi - 1.5) * 0.15 + jx * 0.06, lr * 0.7);
    } else {
      lr = (0.08 + jr * 0.055) * puff;
      c = vec2((fi - 5.0) * 0.135 + jx * 0.05, (0.155 + jr * 0.075) * puff);
    }
    d = max(d, 1.0 - length(q - c) / lr);
    // The sun-ward sample shares every lobe parameter with the primary one, so
    // the shadow shelf rides along in the same loop rather than costing a
    // second full evaluation of the field.
    shelf = max(shelf, 1.0 - length(qs - c) / lr);
  }
  // baseCut > 0 clips the mass to a flat base — a discrete cumulus sitting on
  // its own shelf. baseCut < 0 unions with the half plane instead, so the mass
  // continues downward forever: the same lobe language, read as a cloud sea.
  float plane = q.y * 5.0 + 0.03;
  float planeS = qs.y * 5.0 + 0.03;
  if (baseCut < 0.0) {
    shelf = max(shelf, -planeS);
    return max(d, -plane);
  }
  shelf = min(shelf, planeS);
  return min(d, plane);
}

/**
 * Cloud coverage assembled from placed cumulus rather than a thresholded noise
 * field. Noise gives an amorphous stain however it is cut; a cloud is a stack
 * of bulges sitting on a flat base, and building it as literally that is what
 * makes the silhouette read as drawn.
 *
 * Returns x = density here, y = density one shelf-step toward the sun.
 */
vec2 cloudField(vec2 uv, vec2 shelfStep, float baseY, float thickness, float freq, float drift, float density, float baseCut, float eyeGuard) {
  float x = uv.x * freq * uCloudStretch + drift;
  float y = (uv.y - baseY) * freq;
  float cell = floor(x);
  float fx = fract(x) - 0.5;
  float best = -1.0;
  float shelf = -1.0;
  // Neighbours matter: a cluster overhangs its own cell, and sampling only the
  // owning cell clips every cloud at the cell seam.
  for (int k = -1; k <= 1; k++) {
    float c = cell + float(k);
    // Empty cells are skipped outright. The branch is coherent across a whole
    // screen region, so it is a real saving rather than a masked-off lane.
    if (hash21(vec2(c, 1.7)) > 0.42 + density * 0.66) continue;
    float lift = (hash21(vec2(c, 9.7)) - 0.5) * 0.34;
    // Clouds are kept clear of the play space by culling whole cells on where
    // their own base sits — never by eroding against where the shading pixel
    // sits. A per-pixel threshold ramp shrinks a cloud straddling the band into
    // a half dome, which reads as a pebble rather than as a smaller cloud.
    // Deciding per cell means a cloud is either entirely there or entirely not.
    if (baseY + lift / freq < eyeGuard) continue;
    float puff = (0.72 + hash21(vec2(c, 5.1)) * 0.6) * thickness * 2.4;
    // Placement jitter off the cell lattice, so the strata do not beat out an
    // even rhythm across the sky. Held under a quarter cell: any further and a
    // cloud can escape the three-cell neighbourhood and get clipped at a seam.
    float jitterX = (hash21(vec2(c, 21.3)) - 0.5) * 0.5;
    vec2 q = vec2(fx - float(k) - jitterX, y - lift);
    float s = -1.0;
    best = max(best, cumulus(q, q + shelfStep, c, puff, baseCut, s));
    shelf = max(shelf, s);
  }
  return vec2(best, shelf);
}

/** Returns rgb = shaded, inked cloud color; a = coverage with a 1px soft edge. */
vec4 cloudLayer(
  vec3 d,
  vec2 sunUv,
  float baseY,
  float thickness,
  float freq,
  float drift,
  float threshold,
  float shelf,
  float inkPixels,
  float density,
  float baseCut,
  float eyeGuard,
  vec3 lit,
  vec3 shade
) {
  vec2 uv = panUv(d);
  // Shelf offset expressed in cell space, since the field works there.
  vec2 shelfStep = vec2(sunUv.x * shelf * freq * uCloudStretch, sunUv.y * shelf * freq);
  vec2 field = cloudField(uv, shelfStep, baseY, thickness, freq, drift, density, baseCut, eyeGuard);
  float f = field.x;
  float th = threshold;
  // Signed distance to the silhouette measured in pixels, so the ink contour
  // holds a constant on-screen weight the way a mesh outline does.
  float dist = (f - th) / max(fwidth(f), 1e-6);
  if (dist <= 0.0) return vec4(0.0);

  // Two-tone shelf: cloud above you means you are the underside, not the crown.
  vec3 body = mix(lit, shade, step(th, field.y));

  vec3 col = mix(uInk, body, step(inkPixels, dist));
  return vec4(col, min(dist, 1.0));
}

void main() {
  vec3 d = normalize(vDir);
  vec3 S = normalize(uSunDir);

  // A locked side camera only ever sees a narrow slice of the dome, so the
  // whole gradient is compressed into that slice. Spreading bot/mid/top over
  // the full hemisphere is what leaves the visible sky a single flat wash.
  float h = clamp((d.y + 0.28) / 1.05, 0.0, 1.0);

  // Posterized vertical gradient — dithered at the seams so the banding reads
  // as deliberate silkscreen rather than as 8-bit color loss.
  // Dither only an eighth of a band. A full-band jitter dissolves the
  // posterization entirely instead of just softening the seams.
  float dither = (hash21(gl_FragCoord.xy) - 0.5) / (uBandCount * 4.0);
  float hb = floor(clamp(h + dither, 0.0, 1.0) * uBandCount) / uBandCount;
  vec3 col = mix(uBot, uMid, smoothstep(0.0, 0.42, hb));
  col = mix(col, uTop, smoothstep(0.4, 0.95, hb));

  // Hard-stepped horizon haze, kept tight so it never washes out the blue
  float haze = 1.0 - smoothstep(0.0, 0.14, abs(d.y));
  col = mix(col, uFog, floor(haze * 3.0) / 3.0 * 0.3);

  // Sun direction flattened into cloud UV space, for the shadow-shelf lookup.
  vec2 sunUv = normalize(vec2(S.x * 0.35, max(S.y, 0.25)));

  // Cloud sea: one continuous mass with a lumpy inked crown straddling the
  // horizon. A vertical arena spends most of its framing looking out over empty
  // space, and without this the lower half of the frame is a flat wash however
  // good the arena itself is. Gated to the lower dome — the branch is fully
  // coherent across the screen, so the upper sky never pays for it.
  if (d.y < 0.12) {
    vec4 sea = cloudLayer(
      d, sunUv, -0.09, 0.55, uCloudFreq * 2.2, uTime * 0.003,
      0.06, 0.012, 1.6, 1.0, -1.0, -9.0,
      mix(uCloudColor, uFog, 0.45), mix(uCloudShadow, uFog, 0.2)
    );
    col = mix(col, sea.rgb, sea.a);
  }

  // Below the horizon the gradient bottoms out into one pale value, and in a
  // vertical arena that pale value owns the lower third of the frame. Ramping
  // back down into a depth tone gives the space under the platforms weight.
  // Applied over the sea rather than under it, so the sea bands away with
  // distance instead of sitting on the drop as one flat sheet.
  float below = clamp(-d.y / 0.34, 0.0, 1.0);
  col = mix(col, uDepth, floor(below * 4.0) / 4.0 * 0.9);

  // Chunky star cells — graphic points, never a soft twinkle field
  if (uStars > 0.0) {
    vec2 cell = floor(panUv(d) * 120.0);
    col = mix(col, uCloudColor, step(0.9965, hash21(cell)) * uStars * smoothstep(-0.1, 0.3, d.y));
  }

  // Sun: stepped halo, hard disc, inked ring. Void worlds invert the disc.
  float ang = acos(clamp(dot(d, S), -1.0, 1.0));
  float haloT = clamp(1.0 - (ang - uSunSize) / uHaloSize, 0.0, 1.0);
  col = mix(col, uSunColor, floor(haloT * 3.0) / 3.0 * 0.3);
  float ring = step(uSunSize, ang) - step(uSunSize + 0.016, ang);
  float disc = 1.0 - step(uSunSize, ang);
  col = mix(col, mix(uInk, uSunColor, uSunDisc), disc);
  col = mix(col, uSunColor, ring);

  // Cloud strata sit low in the dome: the camera's visible slice is narrow, so
  // banking them high in world terms puts them permanently off-screen.
  // Far stratum: smaller, slower, thinner ink, desaturated toward fog.
  vec4 far = cloudLayer(
    d, sunUv, 0.15, 0.3, uCloudFreq * 1.9, uTime * 0.006,
    mix(0.34, 0.08, uCoverage), 0.022, 3.0, uCoverage, 1.0, 0.13,
    mix(uCloudColor, uFog, 0.26), mix(uCloudShadow, uFog, 0.3)
  );
  col = mix(col, far.rgb, far.a);

  // Near stratum: bigger puffs, drift three times faster, full palette values
  // and the heavier ink weight. Sky parallax sells vertical travel.
  vec4 near = cloudLayer(
    d, sunUv, 0.18, 0.46, uCloudFreq, uTime * 0.018,
    mix(0.3, 0.04, uCoverage), 0.032, 5.0, uCoverage, 1.0, 0.13,
    uCloudColor, uCloudShadow
  );
  col = mix(col, near.rgb, near.a);

  gl_FragColor = vec4(alearisEncode(col), 1.0);
}
`;

interface SkyTreatment {
  sunDir: THREE.Vector3;
  coverage: number;
  /** Cloud cells per radian — roughly how many puffs span the visible sky. */
  cloudFreq: number;
  /** Horizontal frequency multiplier; below 1 stretches clouds into sheets. */
  cloudStretch: number;
  sunDisc: number;
  sunSize: number;
  haloSize: number;
  stars: number;
}

/** Per-world sky treatment — coverage, cloud shape, and what hangs in the sky. */
const TREATMENTS: Record<number, SkyTreatment> = {
  // Frost: bright banded blue, thick cumulus, warm sun low-right. Coverage is
  // deliberately low — discrete countable puffs, not a continuous overcast
  // sheet, which is what turns the sky into a white smear.
  1: {
    sunDir: new THREE.Vector3(0.55, 0.34, 0.76),
    coverage: 0.3,
    cloudFreq: 2.6,
    cloudStretch: 1.0,
    sunDisc: 1,
    sunSize: 0.055,
    haloSize: 0.28,
    stars: 0,
  },
  // Void: no sun — a cold void-eye instead. Sparse torn storm sheets.
  2: {
    sunDir: new THREE.Vector3(-0.35, 0.5, 0.79),
    coverage: 0.34,
    cloudFreq: 4.2,
    cloudStretch: 0.35,
    sunDisc: 0,
    sunSize: 0.09,
    haloSize: 0.34,
    stars: 1,
  },
  // Forge: heavy ember-lit smoke strata banked near the horizon, sun occluded.
  3: {
    sunDir: new THREE.Vector3(0.2, 0.22, 0.95),
    coverage: 0.82,
    cloudFreq: 3.0,
    cloudStretch: 0.5,
    sunDisc: 1,
    sunSize: 0.07,
    haloSize: 0.44,
    stars: 0,
  },
  // Dice: widest banding, big slow flat-bottomed puffs over a gold horizon.
  4: {
    sunDir: new THREE.Vector3(-0.5, 0.28, 0.82),
    coverage: 0.55,
    cloudFreq: 2.4,
    cloudStretch: 0.85,
    sunDisc: 1,
    sunSize: 0.075,
    haloSize: 0.38,
    stars: 0.4,
  },
};

export class SkyDome {
  readonly mesh: THREE.Mesh;
  private readonly material: THREE.ShaderMaterial;

  constructor() {
    this.material = new THREE.ShaderMaterial({
      uniforms: {
        uTop: { value: new THREE.Color() },
        uMid: { value: new THREE.Color() },
        uBot: { value: new THREE.Color() },
        uFog: { value: new THREE.Color() },
        uDepth: { value: new THREE.Color() },
        uInk: { value: new THREE.Color() },
        uSunDir: { value: new THREE.Vector3(0.55, 0.34, 0.76).normalize() },
        uSunColor: { value: new THREE.Color('#fff3c8') },
        uCloudColor: { value: new THREE.Color('#ffffff') },
        uCloudShadow: { value: new THREE.Color('#a9c9e6') },
        uBandCount: { value: 9 },
        uTime: { value: 0 },
        uCoverage: { value: 0.62 },
        uCloudFreq: { value: 3.4 },
        uCloudStretch: { value: 1.0 },
        uSunDisc: { value: 1 },
        uSunSize: { value: 0.055 },
        uHaloSize: { value: 0.28 },
        uStars: { value: 0 },
      },
      vertexShader: SKY_VERT,
      fragmentShader: SKY_FRAG,
      side: THREE.BackSide,
      depthWrite: false,
    });
    this.mesh = new THREE.Mesh(new THREE.SphereGeometry(200, 32, 16), this.material);
    this.mesh.frustumCulled = false;
    this.mesh.name = 'SkyDome';
    this.applyPalette(getPalette(1));
  }

  applyPalette(p: WorldPalette): void {
    const u = this.material.uniforms;
    u.uTop!.value.copy(p.skyTop);
    u.uMid!.value.copy(p.skyMid);
    u.uBot!.value.copy(p.skyBot);
    u.uFog!.value.copy(p.fog);
    // Deep haze under the arena: the world's ink pulled partway back toward fog
    // so it reads as distance, not as a black band.
    u.uDepth!.value.copy(p.ink).lerp(p.fog, 0.42);
    u.uInk!.value.copy(p.ink);
    u.uCloudColor!.value.copy(p.cloud);
    u.uCloudShadow!.value.copy(p.cloudShadow);
    u.uSunColor!.value.copy(p.sun);
    u.uBandCount!.value = p.skyBandCount;

    const t = TREATMENTS[p.id] ?? TREATMENTS[1]!;
    (u.uSunDir!.value as THREE.Vector3).copy(t.sunDir).normalize();
    u.uCoverage!.value = t.coverage;
    u.uCloudFreq!.value = t.cloudFreq;
    u.uCloudStretch!.value = t.cloudStretch;
    u.uSunDisc!.value = t.sunDisc;
    u.uSunSize!.value = t.sunSize;
    u.uHaloSize!.value = t.haloSize;
    u.uStars!.value = t.stars;
  }

  /** World-space direction toward the sky's key light, for matching scene lighting. */
  getSunDirection(): THREE.Vector3 {
    return (this.material.uniforms.uSunDir!.value as THREE.Vector3).clone();
  }

  update(time: number): void {
    this.material.uniforms.uTime!.value = time;
  }
}
