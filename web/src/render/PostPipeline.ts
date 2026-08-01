import * as THREE from 'three';
import { SRGB_ENCODE_GLSL } from './CelMaterial';
import { getPalette } from './Palettes';

/**
 * Lightweight NPR post stack:
 * 1) Normal/depth prepass into a render target
 * 2) Sobel edge detect composited over beauty
 * Tuned so inverted-hull handles silhouettes; Sobel adds interior creases only.
 */
export class PostPipeline {
  private readonly renderer: THREE.WebGLRenderer;
  private readonly beautyTarget: THREE.WebGLRenderTarget;
  private readonly normalDepthTarget: THREE.WebGLRenderTarget;
  private readonly edgeScene = new THREE.Scene();
  private readonly edgeCamera = new THREE.OrthographicCamera(-1, 1, 1, -1, 0, 1);
  private readonly edgeMaterial: THREE.ShaderMaterial;
  private readonly normalDepthMaterial: THREE.ShaderMaterial;
  private width = 1;
  private height = 1;
  private vignetteStrength = 0;
  enabled = true;
  edgeStrength = 0.85;
  edgeThreshold = 0.12;

  constructor(renderer: THREE.WebGLRenderer) {
    this.renderer = renderer;
    const w = 4;
    const h = 4;
    this.beautyTarget = new THREE.WebGLRenderTarget(w, h, {
      minFilter: THREE.LinearFilter,
      magFilter: THREE.LinearFilter,
      format: THREE.RGBAFormat,
    });
    // Built-in materials only apply output encoding when the target says so.
    // Without this they would stay linear while the NPR shaders encode
    // themselves, and unlit VFX would render darker than the surfaces they sit on.
    this.beautyTarget.texture.colorSpace = THREE.SRGBColorSpace;
    this.normalDepthTarget = new THREE.WebGLRenderTarget(w, h, {
      minFilter: THREE.NearestFilter,
      magFilter: THREE.NearestFilter,
      format: THREE.RGBAFormat,
      type: THREE.HalfFloatType,
    });

    this.normalDepthMaterial = new THREE.ShaderMaterial({
      vertexShader: /* glsl */ `
        varying vec3 vNormal;
        varying float vDepth;
        #include <common>
        #include <batching_pars_vertex>
        #include <morphtarget_pars_vertex>
        #include <skinning_pars_vertex>
        void main() {
          #include <batching_vertex>
          #include <beginnormal_vertex>
          #include <morphinstance_vertex>
          #include <morphnormal_vertex>
          #include <skinbase_vertex>
          #include <skinnormal_vertex>
          #include <defaultnormal_vertex>
          #include <begin_vertex>
          #include <morphtarget_vertex>
          #include <skinning_vertex>
          vNormal = normalize(transformedNormal);
          vec4 mv = modelViewMatrix * vec4(transformed, 1.0);
          vDepth = -mv.z;
          gl_Position = projectionMatrix * mv;
        }
      `,
      fragmentShader: /* glsl */ `
        varying vec3 vNormal;
        varying float vDepth;
        void main() {
          gl_FragColor = vec4(normalize(vNormal) * 0.5 + 0.5, vDepth / 80.0);
        }
      `,
    });

    this.edgeMaterial = new THREE.ShaderMaterial({
      uniforms: {
        tDiffuse: { value: null as THREE.Texture | null },
        tNormalDepth: { value: null as THREE.Texture | null },
        uResolution: { value: new THREE.Vector2(1, 1) },
        uEdgeColor: { value: new THREE.Color('#1a1420') },
        uStrength: { value: this.edgeStrength },
        uThreshold: { value: this.edgeThreshold },
        uVignette: { value: 0 },
      },
      vertexShader: /* glsl */ `
        varying vec2 vUv;
        void main() {
          vUv = uv;
          gl_Position = vec4(position.xy, 0.0, 1.0);
        }
      `,
      fragmentShader: /* glsl */ `
        ${SRGB_ENCODE_GLSL}
        uniform sampler2D tDiffuse;
        uniform sampler2D tNormalDepth;
        uniform vec2 uResolution;
        uniform vec3 uEdgeColor;
        uniform float uStrength;
        uniform float uThreshold;
        uniform float uVignette;
        varying vec2 vUv;

        float sobel(sampler2D tex, vec2 uv, vec2 px) {
          float tl = texture2D(tex, uv + px * vec2(-1.0,  1.0)).a;
          float t  = texture2D(tex, uv + px * vec2( 0.0,  1.0)).a;
          float tr = texture2D(tex, uv + px * vec2( 1.0,  1.0)).a;
          float l  = texture2D(tex, uv + px * vec2(-1.0,  0.0)).a;
          float r  = texture2D(tex, uv + px * vec2( 1.0,  0.0)).a;
          float bl = texture2D(tex, uv + px * vec2(-1.0, -1.0)).a;
          float b  = texture2D(tex, uv + px * vec2( 0.0, -1.0)).a;
          float br = texture2D(tex, uv + px * vec2( 1.0, -1.0)).a;
          float gx = -tl - 2.0*l - bl + tr + 2.0*r + br;
          float gy = -tl - 2.0*t - tr + bl + 2.0*b + br;

          vec3 ntl = texture2D(tex, uv + px * vec2(-1.0,  1.0)).rgb;
          vec3 nt  = texture2D(tex, uv + px * vec2( 0.0,  1.0)).rgb;
          vec3 ntr = texture2D(tex, uv + px * vec2( 1.0,  1.0)).rgb;
          vec3 nl  = texture2D(tex, uv + px * vec2(-1.0,  0.0)).rgb;
          vec3 nr  = texture2D(tex, uv + px * vec2( 1.0,  0.0)).rgb;
          vec3 nbl = texture2D(tex, uv + px * vec2(-1.0, -1.0)).rgb;
          vec3 nb  = texture2D(tex, uv + px * vec2( 0.0, -1.0)).rgb;
          vec3 nbr = texture2D(tex, uv + px * vec2( 1.0, -1.0)).rgb;
          vec3 ngx = -ntl - 2.0*nl - nbl + ntr + 2.0*nr + nbr;
          vec3 ngy = -ntl - 2.0*nt - ntr + nbl + 2.0*nb + nbr;
          float nEdge = length(ngx) + length(ngy);
          return max(length(vec2(gx, gy)), nEdge * 0.55);
        }

        void main() {
          vec2 px = 1.0 / uResolution;
          vec4 beauty = texture2D(tDiffuse, vUv);
          float edge = sobel(tNormalDepth, vUv, px);
          float mask = smoothstep(uThreshold, uThreshold + 0.08, edge) * uStrength;
          // Keep edges thin/graphic — avoid soft photoreal AO look. The beauty
          // buffer is already display-encoded, so the ink must be too.
          vec3 col = mix(beauty.rgb, alearisEncode(uEdgeColor), clamp(mask, 0.0, 0.85));
          // Council pressure vignette (void lanterns): mild edge darkening only
          float vig = 1.0 - uVignette * smoothstep(0.32, 0.78, distance(vUv, vec2(0.5)));
          gl_FragColor = vec4(col * vig, 1.0);
        }
      `,
    });

    const quad = new THREE.Mesh(new THREE.PlaneGeometry(2, 2), this.edgeMaterial);
    this.edgeScene.add(quad);
  }

  setSize(width: number, height: number, pixelRatio: number): void {
    this.width = Math.max(1, Math.floor(width * pixelRatio));
    this.height = Math.max(1, Math.floor(height * pixelRatio));
    this.beautyTarget.setSize(this.width, this.height);
    this.normalDepthTarget.setSize(this.width, this.height);
    this.edgeMaterial.uniforms.uResolution!.value.set(this.width, this.height);
  }

  setWorld(world: number): void {
    const p = getPalette(world);
    this.edgeMaterial.uniforms.uEdgeColor!.value.copy(p.ink);
  }

  /** Screen-edge darkening 0..1; used by council void-lantern pressure. */
  setVignette(strength: number): void {
    this.vignetteStrength = THREE.MathUtils.clamp(strength, 0, 1);
  }

  render(scene: THREE.Scene, camera: THREE.Camera): void {
    if (!this.enabled) {
      this.renderer.setRenderTarget(null);
      this.renderer.render(scene, camera);
      return;
    }

    // Beauty
    this.renderer.setRenderTarget(this.beautyTarget);
    this.renderer.clear();
    this.renderer.render(scene, camera);

    // Normal/depth override
    const prevOverride = scene.overrideMaterial;
    scene.overrideMaterial = this.normalDepthMaterial;
    this.renderer.setRenderTarget(this.normalDepthTarget);
    this.renderer.clear();
    this.renderer.render(scene, camera);
    scene.overrideMaterial = prevOverride;

    // Composite
    this.edgeMaterial.uniforms.tDiffuse!.value = this.beautyTarget.texture;
    this.edgeMaterial.uniforms.tNormalDepth!.value = this.normalDepthTarget.texture;
    this.edgeMaterial.uniforms.uStrength!.value = this.edgeStrength;
    this.edgeMaterial.uniforms.uThreshold!.value = this.edgeThreshold;
    this.edgeMaterial.uniforms.uVignette!.value = this.vignetteStrength;
    this.renderer.setRenderTarget(null);
    this.renderer.render(this.edgeScene, this.edgeCamera);
  }

  dispose(): void {
    this.beautyTarget.dispose();
    this.normalDepthTarget.dispose();
    this.edgeMaterial.dispose();
    this.normalDepthMaterial.dispose();
  }
}
