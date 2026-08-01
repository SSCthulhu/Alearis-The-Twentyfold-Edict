import * as THREE from 'three';
import { getPalette, type RampBands } from './Palettes';

/** Deterministic PRNG so every procedural texture is byte-identical per run. */
function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const DEFAULT_RAMP: RampBands = ['#4a6f9c', '#7fa6c8', '#bcd8ee', '#ffffff'];

/** Procedural 4-band toon ramp — NearestFilter, no interpolation. */
export function createToonRampTexture(bands: RampBands = DEFAULT_RAMP): THREE.DataTexture {
  const tex = new THREE.DataTexture(new Uint8Array(4 * 4), 4, 1, THREE.RGBAFormat);
  tex.magFilter = THREE.NearestFilter;
  tex.minFilter = THREE.NearestFilter;
  tex.wrapS = THREE.ClampToEdgeWrapping;
  tex.wrapT = THREE.ClampToEdgeWrapping;
  writeRampBands(tex, bands);
  return tex;
}

/** Rewrites an existing ramp in place so every live material picks up the change. */
function writeRampBands(tex: THREE.DataTexture, bands: RampBands): void {
  const data = tex.image.data as Uint8Array;
  for (let i = 0; i < 4; i++) {
    const c = new THREE.Color(bands[i]);
    data[i * 4 + 0] = Math.round(c.r * 255);
    data[i * 4 + 1] = Math.round(c.g * 255);
    data[i * 4 + 2] = Math.round(c.b * 255);
    data[i * 4 + 3] = 255;
  }
  tex.needsUpdate = true;
}

/** Fake matcap: radial highlight baked into a small canvas — never a real cubemap. */
export function createMatcapTexture(base = '#8fa6bd', hilite = '#ffffff'): THREE.CanvasTexture {
  const canvas = document.createElement('canvas');
  canvas.width = 128;
  canvas.height = 128;
  const tex = new THREE.CanvasTexture(canvas);
  tex.magFilter = THREE.LinearFilter;
  tex.minFilter = THREE.LinearFilter;
  paintMatcap(canvas, base, hilite, '#41566b');
  return tex;
}

function paintMatcap(canvas: HTMLCanvasElement, base: string, hilite: string, shadow: string): void {
  const size = canvas.width;
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  const g = ctx.createRadialGradient(size * 0.35, size * 0.35, 2, size * 0.5, size * 0.5, size * 0.55);
  g.addColorStop(0, hilite);
  g.addColorStop(0.34, base);
  // Hard stop: the matcap contributes a banded environment read, not a soft PBR wash.
  g.addColorStop(0.35, base);
  g.addColorStop(0.74, shadow);
  g.addColorStop(1, shadow);
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, size, size);
}

// --- Procedural surface textures -------------------------------------------
// All are centred on mid-grey so the shader can both darken and lighten albedo.
// Elements are drawn four times at wrap offsets so they tile without seams.

function makeTilingCanvas(size: number): { canvas: HTMLCanvasElement; ctx: CanvasRenderingContext2D | null } {
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  return { canvas, ctx: canvas.getContext('2d') };
}

function wrapDraw(ctx: CanvasRenderingContext2D, size: number, draw: () => void): void {
  for (const [dx, dy] of [[0, 0], [-size, 0], [0, -size], [-size, -size]] as const) {
    ctx.save();
    ctx.translate(dx, dy);
    draw();
    ctx.restore();
  }
}

function finishTexture(canvas: HTMLCanvasElement): THREE.CanvasTexture {
  const tex = new THREE.CanvasTexture(canvas);
  tex.wrapS = THREE.RepeatWrapping;
  tex.wrapT = THREE.RepeatWrapping;
  tex.magFilter = THREE.LinearFilter;
  tex.minFilter = THREE.LinearMipmapLinearFilter;
  tex.generateMipmaps = true;
  return tex;
}

/** Angular ice facets with bright crest strokes — kills the flat-slab read. */
export function createIceFacetTexture(seed = 11): THREE.CanvasTexture {
  const size = 256;
  const { canvas, ctx } = makeTilingCanvas(size);
  if (!ctx) return finishTexture(canvas);
  const rnd = mulberry32(seed);
  ctx.fillStyle = '#808080';
  ctx.fillRect(0, 0, size, size);

  for (let i = 0; i < 26; i++) {
    const cx = rnd() * size;
    const cy = rnd() * size;
    const r = 18 + rnd() * 44;
    const rot = rnd() * Math.PI * 2;
    const sides = 3 + Math.floor(rnd() * 3);
    const tone = rnd() > 0.5 ? '#9aa6b4' : '#6d7d8e';
    wrapDraw(ctx, size, () => {
      ctx.beginPath();
      for (let s = 0; s <= sides; s++) {
        const a = rot + (s / sides) * Math.PI * 2;
        const rr = r * (0.7 + ((s * 37 + i * 13) % 7) / 12);
        const px = cx + Math.cos(a) * rr;
        const py = cy + Math.sin(a) * rr;
        if (s === 0) ctx.moveTo(px, py);
        else ctx.lineTo(px, py);
      }
      ctx.closePath();
      ctx.fillStyle = tone;
      ctx.fill();
    });
  }

  ctx.lineCap = 'round';
  for (let i = 0; i < 34; i++) {
    const x = rnd() * size;
    const y = rnd() * size;
    const len = 20 + rnd() * 60;
    const a = (rnd() - 0.5) * 2.4;
    const bright = rnd() > 0.35;
    wrapDraw(ctx, size, () => {
      ctx.strokeStyle = bright ? '#d6e4f2' : '#5a6b7d';
      ctx.lineWidth = bright ? 2.2 : 3.4;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + Math.cos(a) * len, y + Math.sin(a) * len);
      ctx.stroke();
    });
  }
  return finishTexture(canvas);
}

/** Horizontal brush streaks plus pitting — forge iron and void slabs. */
export function createBrushedMetalTexture(seed = 23): THREE.CanvasTexture {
  const size = 256;
  const { canvas, ctx } = makeTilingCanvas(size);
  if (!ctx) return finishTexture(canvas);
  const rnd = mulberry32(seed);
  ctx.fillStyle = '#808080';
  ctx.fillRect(0, 0, size, size);

  for (let i = 0; i < 120; i++) {
    const y = rnd() * size;
    const x = rnd() * size;
    const len = 30 + rnd() * 140;
    const light = rnd() > 0.5;
    ctx.strokeStyle = light ? '#9c9c9c' : '#666666';
    ctx.lineWidth = 0.6 + rnd() * 1.8;
    wrapDraw(ctx, size, () => {
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + len, y + (rnd() - 0.5) * 2);
      ctx.stroke();
    });
  }
  for (let i = 0; i < 46; i++) {
    const x = rnd() * size;
    const y = rnd() * size;
    const r = 1 + rnd() * 3.4;
    ctx.fillStyle = rnd() > 0.5 ? '#5c5c5c' : '#9a9a9a';
    wrapDraw(ctx, size, () => {
      ctx.beginPath();
      ctx.arc(x, y, r, 0, Math.PI * 2);
      ctx.fill();
    });
  }
  return finishTexture(canvas);
}

/** Speckled grain with a few hard cracks — stone, bone, and rough slabs. */
export function createStoneSpeckleTexture(seed = 37): THREE.CanvasTexture {
  const size = 256;
  const { canvas, ctx } = makeTilingCanvas(size);
  if (!ctx) return finishTexture(canvas);
  const rnd = mulberry32(seed);
  ctx.fillStyle = '#808080';
  ctx.fillRect(0, 0, size, size);

  for (let i = 0; i < 480; i++) {
    const x = rnd() * size;
    const y = rnd() * size;
    const r = 0.8 + rnd() * 2.6;
    ctx.fillStyle = rnd() > 0.5 ? '#6f6f6f' : '#949494';
    wrapDraw(ctx, size, () => {
      ctx.beginPath();
      ctx.arc(x, y, r, 0, Math.PI * 2);
      ctx.fill();
    });
  }
  ctx.strokeStyle = '#5e5e5e';
  ctx.lineWidth = 2.2;
  for (let i = 0; i < 7; i++) {
    let x = rnd() * size;
    let y = rnd() * size;
    const steps = 4 + Math.floor(rnd() * 4);
    const pts: Array<[number, number]> = [[x, y]];
    for (let s = 0; s < steps; s++) {
      x += (rnd() - 0.5) * 70;
      y += (rnd() - 0.5) * 70;
      pts.push([x, y]);
    }
    wrapDraw(ctx, size, () => {
      ctx.beginPath();
      ctx.moveTo(pts[0]![0], pts[0]![1]);
      for (let s = 1; s < pts.length; s++) ctx.lineTo(pts[s]![0], pts[s]![1]);
      ctx.stroke();
    });
  }
  return finishTexture(canvas);
}

/** Fine porcelain crackle — dice-realm ivory that must not read as plastic. */
export function createCrackleTexture(seed = 53): THREE.CanvasTexture {
  const size = 256;
  const { canvas, ctx } = makeTilingCanvas(size);
  if (!ctx) return finishTexture(canvas);
  const rnd = mulberry32(seed);
  ctx.fillStyle = '#828282';
  ctx.fillRect(0, 0, size, size);
  ctx.lineCap = 'round';
  for (let i = 0; i < 26; i++) {
    let x = rnd() * size;
    let y = rnd() * size;
    const steps = 3 + Math.floor(rnd() * 5);
    const pts: Array<[number, number]> = [[x, y]];
    for (let s = 0; s < steps; s++) {
      x += (rnd() - 0.5) * 54;
      y += (rnd() - 0.5) * 54;
      pts.push([x, y]);
    }
    ctx.strokeStyle = '#707070';
    ctx.lineWidth = 1 + rnd() * 1.1;
    wrapDraw(ctx, size, () => {
      ctx.beginPath();
      ctx.moveTo(pts[0]![0], pts[0]![1]);
      for (let s = 1; s < pts.length; s++) ctx.lineTo(pts[s]![0], pts[s]![1]);
      ctx.stroke();
    });
  }
  return finishTexture(canvas);
}

export type SurfaceTextureKind = 'ice' | 'metal' | 'stone' | 'crackle';

const textureCache = new Map<SurfaceTextureKind, THREE.Texture>();

/** Shared, lazily built surface texture — one canvas per kind for the whole run. */
export function getSurfaceTexture(kind: SurfaceTextureKind): THREE.Texture {
  const cached = textureCache.get(kind);
  if (cached) return cached;
  const tex =
    kind === 'ice'
      ? createIceFacetTexture()
      : kind === 'metal'
        ? createBrushedMetalTexture()
        : kind === 'stone'
          ? createStoneSpeckleTexture()
          : createCrackleTexture();
  textureCache.set(kind, tex);
  return tex;
}

// --- Cel shader -------------------------------------------------------------

const CEL_VERT = /* glsl */ `
varying vec3 vNormal;
varying vec3 vViewPos;
varying vec3 vWorldPos;
varying vec3 vWorldNormal;

void main() {
  vNormal = normalize(normalMatrix * normal);
  vWorldNormal = normalize(mat3(modelMatrix) * normal);
  vec4 mv = modelViewMatrix * vec4(position, 1.0);
  vViewPos = mv.xyz;
  vWorldPos = (modelMatrix * vec4(position, 1.0)).xyz;
  gl_Position = projectionMatrix * mv;
}
`;

/**
 * Custom ShaderMaterials get no automatic output encoding from three, so
 * without this every authored palette hex renders far darker and more
 * saturated than specified. Applied as the last step of every NPR shader so
 * what the art bible lists is what reaches the screen.
 */
export const SRGB_ENCODE_GLSL = /* glsl */ `
vec3 alearisEncode(vec3 c) {
  c = clamp(c, 0.0, 1.0);
  return mix(c * 12.92, 1.055 * pow(c, vec3(0.4166666667)) - 0.055, step(0.0031308, c));
}
`;

const CEL_FRAG = /* glsl */ `
${SRGB_ENCODE_GLSL}
uniform vec3 uColor;
uniform vec3 uRimColor;
uniform float uRimPower;
uniform float uRimStrength;
uniform sampler2D uRamp;
uniform sampler2D uMatcap;
uniform sampler2D uTex;
uniform float uHasTex;
uniform float uTexScale;
uniform float uTexStrength;
uniform vec3 uKeyDir;
uniform vec3 uFillColor;
uniform vec3 uShadowTint;
uniform float uShadowBias;
uniform float uSpecularBand;
uniform float uSpecularStrength;
uniform float uAmbient;
uniform float uMatcapMix;

varying vec3 vNormal;
varying vec3 vViewPos;
varying vec3 vWorldPos;
varying vec3 vWorldNormal;

/** Triplanar sample: platform boxes are scaled arbitrarily, so UVs are useless. */
vec3 triplanar(sampler2D tex, vec3 p, vec3 n, float scale) {
  vec3 w = abs(n);
  w = pow(w, vec3(4.0));
  w /= max(w.x + w.y + w.z, 0.0001);
  vec3 x = texture2D(tex, p.zy * scale).rgb;
  vec3 y = texture2D(tex, p.xz * scale).rgb;
  vec3 z = texture2D(tex, p.xy * scale).rgb;
  return x * w.x + y * w.y + z * w.z;
}

void main() {
  vec3 N = normalize(vNormal);
  vec3 V = normalize(-vViewPos);
  vec3 L = normalize(uKeyDir);

  // Quantized diffuse — the heart of the Wind Waker–modern look.
  // A small wrap keeps the terminator off the exact N·L=0 seam so the darkest
  // band reads as a shape, not as a hairline.
  float ndl = clamp((dot(N, L) + 0.12) / 1.12, 0.0, 1.0);
  float rampU = clamp(ndl * 0.82 + uAmbient * 0.26, 0.04, 0.99);
  vec3 ramp = texture2D(uRamp, vec2(rampU, 0.5)).rgb;

  vec3 albedo = uColor;
  if (uHasTex > 0.5) {
    vec3 surf = triplanar(uTex, vWorldPos, normalize(vWorldNormal), uTexScale);
    albedo *= mix(vec3(1.0), surf * 2.0, uTexStrength);
  }

  // Hue-shifted shadow. Multiplying albedo by grey is the fastest way to look
  // like a graybox, so dark bands are pulled toward the world's shadow hue.
  float dark = 1.0 - rampU;
  vec3 base = albedo * ramp;
  base = mix(base, base * uShadowTint * 1.55, dark * dark * uShadowBias);

  // Fake environment via matcap (view-space normal)
  vec2 matUv = N.xy * 0.5 + 0.5;
  vec3 matcap = texture2D(uMatcap, matUv).rgb;
  base = mix(base, base * matcap * 1.9, uMatcapMix);

  // Banded specular — hard edge, not a Blinn soft blob
  vec3 H = normalize(L + V);
  float spec = max(dot(N, H), 0.0);
  base += vec3(step(uSpecularBand, spec) * uSpecularStrength);

  base += uFillColor * 0.13;

  // Fresnel rim for silhouette pop against arenas
  float fres = pow(1.0 - max(dot(N, V), 0.0), uRimPower);
  base += uRimColor * fres * uRimStrength;

  gl_FragColor = vec4(alearisEncode(base), 1.0);
}
`;

export interface CelMaterialOptions {
  color: THREE.ColorRepresentation;
  rimColor?: THREE.ColorRepresentation;
  rimPower?: number;
  rimStrength?: number;
  ramp?: THREE.Texture;
  matcap?: THREE.Texture;
  /** How much fake-environment banding to blend in; 0 for flat graphic surfaces. */
  matcapMix?: number;
  /** Procedural surface breakup — flat single-colour boxes are the enemy. */
  texture?: SurfaceTextureKind | THREE.Texture;
  /** World-units-to-texture ratio; higher tiles tighter. */
  texScale?: number;
  texStrength?: number;
  keyDir?: THREE.Vector3;
  fillColor?: THREE.ColorRepresentation;
  /** Hue the darkest ramp bands are pulled toward — never grey. */
  shadowTint?: THREE.ColorRepresentation;
  shadowBias?: number;
  specularBand?: number;
  specularStrength?: number;
  ambient?: number;
}

let sharedRamp: THREE.DataTexture | null = null;
let sharedMatcap: THREE.CanvasTexture | null = null;
let activeShadowTint = new THREE.Color('#5f7fb0');

export function getSharedRamp(): THREE.Texture {
  if (!sharedRamp) sharedRamp = createToonRampTexture();
  return sharedRamp;
}

export function getSharedMatcap(): THREE.Texture {
  if (!sharedMatcap) sharedMatcap = createMatcapTexture();
  return sharedMatcap;
}

/**
 * Repoints the shared ramp and matcap at a world's palette. Both textures are
 * rewritten in place, so every material already built for the run re-grades
 * without needing to be rebuilt.
 */
export function applyWorldRamp(world: number): void {
  const p = getPalette(world);
  writeRampBands(sharedRamp ?? (sharedRamp = createToonRampTexture()), p.ramp);
  if (!sharedMatcap) sharedMatcap = createMatcapTexture();
  paintMatcap(sharedMatcap.image as HTMLCanvasElement, p.ramp[2], p.ramp[3], p.ramp[0]);
  sharedMatcap.needsUpdate = true;
  activeShadowTint = new THREE.Color(p.ramp[0]).lerp(new THREE.Color('#ffffff'), 0.25);
}

export function createCelMaterial(opts: CelMaterialOptions): THREE.ShaderMaterial {
  // Upper-right key in view space. A locked side camera shows mostly front
  // faces, so the key has to sit high enough that top faces land a full ramp
  // band above them — otherwise every box reads as one flat value.
  const keyDir = opts.keyDir?.clone().normalize() ?? new THREE.Vector3(0.45, 0.78, 0.44).normalize();
  const tex =
    typeof opts.texture === 'string' ? getSurfaceTexture(opts.texture) : (opts.texture ?? null);
  return new THREE.ShaderMaterial({
    uniforms: {
      uColor: { value: new THREE.Color(opts.color) },
      uRimColor: { value: new THREE.Color(opts.rimColor ?? '#ffe9a8') },
      uRimPower: { value: opts.rimPower ?? 3.2 },
      uRimStrength: { value: opts.rimStrength ?? 0.45 },
      uRamp: { value: opts.ramp ?? getSharedRamp() },
      uMatcap: { value: opts.matcap ?? getSharedMatcap() },
      uMatcapMix: { value: opts.matcapMix ?? 0.12 },
      uTex: { value: tex ?? getSharedRamp() },
      uHasTex: { value: tex ? 1 : 0 },
      uTexScale: { value: opts.texScale ?? 0.5 },
      uTexStrength: { value: opts.texStrength ?? 0.32 },
      uKeyDir: { value: keyDir },
      uFillColor: { value: new THREE.Color(opts.fillColor ?? '#6a9cc0') },
      uShadowTint: { value: new THREE.Color(opts.shadowTint ?? activeShadowTint) },
      uShadowBias: { value: opts.shadowBias ?? 0.55 },
      uSpecularBand: { value: opts.specularBand ?? 0.92 },
      uSpecularStrength: { value: opts.specularStrength ?? 0.35 },
      uAmbient: { value: opts.ambient ?? 0.5 },
    },
    vertexShader: CEL_VERT,
    fragmentShader: CEL_FRAG,
  });
}

/** Inverted-hull outline — BackSide, push along smoothed normals. */
export function createOutlineMesh(
  source: THREE.Mesh | THREE.SkinnedMesh,
  ink: THREE.ColorRepresentation = '#1a1420',
  baseWidth = 0.035,
): THREE.Mesh {
  const geo = source.geometry.clone();
  // Ensure smooth normals for consistent silhouette push
  geo.computeVertexNormals();
  const mat = new THREE.ShaderMaterial({
    uniforms: {
      uColor: { value: new THREE.Color(ink) },
      uWidth: { value: baseWidth },
    },
    vertexShader: /* glsl */ `
      uniform float uWidth;
      void main() {
        vec3 n = normalize(normalMatrix * normal);
        // Approximate constant screen-space width via view-space scale
        float dist = length((modelViewMatrix * vec4(position, 1.0)).xyz);
        float w = uWidth * (0.35 + dist * 0.04);
        vec4 pos = modelViewMatrix * vec4(position + normal * w, 1.0);
        // Push in view space along normal for cleaner hull
        pos.xyz += n * w * 0.15;
        gl_Position = projectionMatrix * pos;
      }
    `,
    fragmentShader: /* glsl */ `
      ${SRGB_ENCODE_GLSL}
      uniform vec3 uColor;
      void main() { gl_FragColor = vec4(alearisEncode(uColor), 1.0); }
    `,
    side: THREE.BackSide,
    depthWrite: true,
  });
  const outline = new THREE.Mesh(geo, mat);
  outline.name = (source.name || 'mesh') + '_outline';
  outline.renderOrder = source.renderOrder - 1;
  outline.userData.isOutline = true;
  return outline;
}

export function attachOutline(
  parent: THREE.Object3D,
  mesh: THREE.Mesh,
  ink: THREE.ColorRepresentation = '#1a1420',
  width = 0.035,
): THREE.Mesh {
  const outline = createOutlineMesh(mesh, ink, width);
  outline.position.copy(mesh.position);
  outline.rotation.copy(mesh.rotation);
  outline.scale.copy(mesh.scale);
  parent.add(outline);
  return outline;
}
