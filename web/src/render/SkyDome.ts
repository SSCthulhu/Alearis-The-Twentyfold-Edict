import * as THREE from 'three';
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
uniform vec3 uTop;
uniform vec3 uMid;
uniform vec3 uBot;
uniform vec3 uSunDir;
uniform vec3 uSunColor;
uniform vec3 uCloudColor;
uniform float uTime;
uniform float uWorld;
varying vec3 vDir;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void main() {
  vec3 d = normalize(vDir);
  float h = d.y * 0.5 + 0.5;
  vec3 col = mix(uBot, uMid, smoothstep(0.0, 0.45, h));
  col = mix(col, uTop, smoothstep(0.45, 1.0, h));

  // Graphic sun/moon disc
  float sun = smoothstep(0.995, 0.999, dot(d, normalize(uSunDir)));
  col += uSunColor * sun * 1.4;
  float flare = pow(max(dot(d, normalize(uSunDir)), 0.0), 32.0);
  col += uSunColor * flare * 0.25;

  // Stylized cel clouds / storm sheets — hard thresholds, not soft PBR clouds
  vec2 cuv = d.xz / max(d.y + 0.35, 0.05) + vec2(uTime * 0.01, 0.0);
  float c = noise(cuv * 2.2);
  float cloudMask = step(0.62, c) * smoothstep(0.05, 0.4, d.y);
  if (uWorld > 1.5 && uWorld < 2.5) {
    // Void storm sheets
    cloudMask = step(0.55, noise(cuv * 3.5 + uTime * 0.05)) * smoothstep(-0.1, 0.5, d.y);
  }
  if (uWorld > 2.5 && uWorld < 3.5) {
    cloudMask = step(0.58, noise(cuv * 4.0 - uTime * 0.03));
  }
  col = mix(col, uCloudColor, cloudMask * 0.55);

  gl_FragColor = vec4(col, 1.0);
}
`;

export class SkyDome {
  readonly mesh: THREE.Mesh;
  private readonly material: THREE.ShaderMaterial;

  constructor() {
    this.material = new THREE.ShaderMaterial({
      uniforms: {
        uTop: { value: new THREE.Color() },
        uMid: { value: new THREE.Color() },
        uBot: { value: new THREE.Color() },
        uSunDir: { value: new THREE.Vector3(0.4, 0.7, 0.3).normalize() },
        uSunColor: { value: new THREE.Color('#ffe8a0') },
        uCloudColor: { value: new THREE.Color('#ffffff') },
        uTime: { value: 0 },
        uWorld: { value: 1 },
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
    this.material.uniforms.uTop!.value.copy(p.skyTop);
    this.material.uniforms.uMid!.value.copy(p.skyMid);
    this.material.uniforms.uBot!.value.copy(p.skyBot);
    this.material.uniforms.uCloudColor!.value.copy(p.cloud);
    this.material.uniforms.uSunColor!.value.copy(p.accent);
    this.material.uniforms.uWorld!.value = p.id;
  }

  update(time: number): void {
    this.material.uniforms.uTime!.value = time;
  }
}
