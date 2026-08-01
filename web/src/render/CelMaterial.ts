import * as THREE from 'three';

/** Procedural 4-band toon ramp — NearestFilter, no interpolation. */
export function createToonRampTexture(
  bands: [string, string, string, string] = ['#2a2030', '#5a4a60', '#a09088', '#f0e8d8'],
): THREE.DataTexture {
  const data = new Uint8Array(4 * 4);
  for (let i = 0; i < 4; i++) {
    const c = new THREE.Color(bands[i]);
    data[i * 4 + 0] = Math.floor(c.r * 255);
    data[i * 4 + 1] = Math.floor(c.g * 255);
    data[i * 4 + 2] = Math.floor(c.b * 255);
    data[i * 4 + 3] = 255;
  }
  const tex = new THREE.DataTexture(data, 4, 1, THREE.RGBAFormat);
  tex.magFilter = THREE.NearestFilter;
  tex.minFilter = THREE.NearestFilter;
  tex.wrapS = THREE.ClampToEdgeWrapping;
  tex.wrapT = THREE.ClampToEdgeWrapping;
  tex.needsUpdate = true;
  return tex;
}

/** Fake matcap: radial highlight baked into a small canvas — never a real cubemap. */
export function createMatcapTexture(base = '#808890', hilite = '#ffffff'): THREE.CanvasTexture {
  const size = 128;
  const canvas = document.createElement('canvas');
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext('2d')!;
  const g = ctx.createRadialGradient(size * 0.35, size * 0.35, 2, size * 0.5, size * 0.5, size * 0.55);
  g.addColorStop(0, hilite);
  g.addColorStop(0.35, base);
  g.addColorStop(0.75, '#303840');
  g.addColorStop(1, '#101418');
  ctx.fillStyle = g;
  ctx.fillRect(0, 0, size, size);
  const tex = new THREE.CanvasTexture(canvas);
  tex.magFilter = THREE.LinearFilter;
  tex.minFilter = THREE.LinearFilter;
  return tex;
}

const CEL_VERT = /* glsl */ `
varying vec3 vNormal;
varying vec3 vViewPos;
varying vec3 vWorldPos;

void main() {
  vNormal = normalize(normalMatrix * normal);
  vec4 mv = modelViewMatrix * vec4(position, 1.0);
  vViewPos = mv.xyz;
  vWorldPos = (modelMatrix * vec4(position, 1.0)).xyz;
  gl_Position = projectionMatrix * mv;
}
`;

const CEL_FRAG = /* glsl */ `
uniform vec3 uColor;
uniform vec3 uRimColor;
uniform float uRimPower;
uniform float uRimStrength;
uniform sampler2D uRamp;
uniform sampler2D uMatcap;
uniform vec3 uKeyDir;
uniform vec3 uFillColor;
uniform float uSpecularBand;
uniform float uSpecularStrength;
uniform float uAmbient;

varying vec3 vNormal;
varying vec3 vViewPos;
varying vec3 vWorldPos;

void main() {
  vec3 N = normalize(vNormal);
  vec3 V = normalize(-vViewPos);
  vec3 L = normalize(uKeyDir);

  // Quantized diffuse — the heart of the Wind Waker–modern look
  float ndl = max(dot(N, L), 0.0);
  float rampU = clamp(ndl * 0.75 + uAmbient * 0.25, 0.02, 0.98);
  vec3 ramp = texture2D(uRamp, vec2(rampU, 0.5)).rgb;

  // Fake environment via matcap (view-space normal)
  vec2 matUv = N.xy * 0.5 + 0.5;
  vec3 matcap = texture2D(uMatcap, matUv).rgb;

  // Banded specular — hard edge, not Blinn soft blob
  vec3 H = normalize(L + V);
  float spec = max(dot(N, H), 0.0);
  float bandSpec = step(uSpecularBand, spec) * uSpecularStrength;

  // Fresnel rim for silhouette pop against arenas
  float fres = pow(1.0 - max(dot(N, V), 0.0), uRimPower);
  vec3 rim = uRimColor * fres * uRimStrength;

  vec3 base = uColor * ramp;
  base = mix(base, base * matcap * 1.35, 0.22);
  base += uFillColor * 0.12;
  base += vec3(bandSpec);
  base += rim;

  gl_FragColor = vec4(base, 1.0);
}
`;

export interface CelMaterialOptions {
  color: THREE.ColorRepresentation;
  rimColor?: THREE.ColorRepresentation;
  rimPower?: number;
  rimStrength?: number;
  ramp?: THREE.Texture;
  matcap?: THREE.Texture;
  keyDir?: THREE.Vector3;
  fillColor?: THREE.ColorRepresentation;
  specularBand?: number;
  specularStrength?: number;
  ambient?: number;
}

let sharedRamp: THREE.Texture | null = null;
let sharedMatcap: THREE.Texture | null = null;

export function getSharedRamp(): THREE.Texture {
  if (!sharedRamp) sharedRamp = createToonRampTexture();
  return sharedRamp;
}

export function getSharedMatcap(): THREE.Texture {
  if (!sharedMatcap) sharedMatcap = createMatcapTexture();
  return sharedMatcap;
}

export function createCelMaterial(opts: CelMaterialOptions): THREE.ShaderMaterial {
  const keyDir = opts.keyDir?.clone().normalize() ?? new THREE.Vector3(0.45, 0.85, 0.35).normalize();
  return new THREE.ShaderMaterial({
    uniforms: {
      uColor: { value: new THREE.Color(opts.color) },
      uRimColor: { value: new THREE.Color(opts.rimColor ?? '#ffe9a8') },
      uRimPower: { value: opts.rimPower ?? 3.0 },
      uRimStrength: { value: opts.rimStrength ?? 0.55 },
      uRamp: { value: opts.ramp ?? getSharedRamp() },
      uMatcap: { value: opts.matcap ?? getSharedMatcap() },
      uKeyDir: { value: keyDir },
      uFillColor: { value: new THREE.Color(opts.fillColor ?? '#6a9cc0') },
      uSpecularBand: { value: opts.specularBand ?? 0.92 },
      uSpecularStrength: { value: opts.specularStrength ?? 0.35 },
      uAmbient: { value: opts.ambient ?? 0.35 },
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
      uniform vec3 uColor;
      void main() { gl_FragColor = vec4(uColor, 1.0); }
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
