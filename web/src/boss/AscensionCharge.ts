import * as THREE from 'three';
import { attachOutline, createCelMaterial } from '../render/CelMaterial';

export type AscensionChargeState =
  | 'idle'
  | 'spawned'
  | 'carried'
  | 'charging'
  | 'charged'
  | 'dropped'
  | 'delivered';

export type AscensionPortalOutcome = 'right_portal' | 'wrong_portal';

export interface AscensionCarrier {
  readonly id: string;
  readonly position: THREE.Vector3;
  readonly radius?: number;
  readonly velocity?: THREE.Vector3;
  readonly ascensionAttachPoint?: THREE.Object3D;
  applyAscensionDebuff?(debuff: AscensionDebuff): void;
}

export interface AscensionDebuff {
  readonly id: string;
  readonly durationSec: number;
  readonly moveSpeedMultiplier: number;
  readonly incomingDamageMultiplier: number;
}

export interface AscensionStationConfig {
  readonly id: string;
  readonly position: THREE.Vector3;
  readonly radius?: number;
  readonly chargeSeconds?: number;
}

export interface AscensionStationRuntime extends AscensionStationConfig {
  readonly radius: number;
  readonly chargeSeconds: number;
  readonly group: THREE.Group;
  readonly beam: THREE.Mesh;
}

export interface AscensionSocketConfig {
  readonly id: string;
  readonly position: THREE.Vector3;
  readonly radius?: number;
}

export interface AscensionSocketRuntime extends AscensionSocketConfig {
  readonly radius: number;
  readonly group: THREE.Group;
}

export interface AscensionDeliveryEvent {
  readonly socket: AscensionSocketRuntime;
  readonly charge: AscensionCharge;
  readonly dpsWindowSeconds: number;
  readonly ascendantCoreBonusApplied: boolean;
}

export interface AscensionDropEvent {
  readonly charge: AscensionCharge;
  readonly position: THREE.Vector3;
  readonly reason: string;
  readonly hazardRadius: number;
}

export interface AscensionChargeEvent {
  readonly charge: AscensionCharge;
  readonly station: AscensionStationRuntime;
  readonly carrier: AscensionCarrier;
}

export interface AscensionChargeOptions {
  readonly spawnPosition: THREE.Vector3;
  readonly stations: readonly AscensionStationConfig[];
  readonly socket: AscensionSocketConfig;
  readonly accentColor?: THREE.ColorRepresentation;
  readonly secondaryColor?: THREE.ColorRepresentation;
  readonly pickupRadius?: number;
  readonly gravity?: number;
  readonly groundY?: number;
  readonly dpsWindowSeconds?: number;
  readonly ascendantCoreBonusSeconds?: number;
  readonly ascendantCoreBonusAvailable?: () => boolean;
  readonly consumeAscendantCoreBonus?: () => boolean;
  readonly stationRateMultiplier?: (
    station: AscensionStationRuntime,
    carrier: AscensionCarrier,
    charge: AscensionCharge,
  ) => number;
  readonly onChargeStarted?: (event: AscensionChargeEvent) => void;
  readonly onChargeCompleted?: (event: AscensionChargeEvent) => void;
  readonly onDelivered?: (event: AscensionDeliveryEvent) => void;
  readonly onDropped?: (event: AscensionDropEvent) => void;
  readonly onHazardPulse?: (event: AscensionDropEvent) => void;
  readonly onAttractAdds?: (event: AscensionDropEvent) => void;
}

const DEFAULT_ASCENSION_COLOR = '#ffd36e';
const DEFAULT_SECONDARY_COLOR = '#fff3b0';
/** Fixed orb identity — see `buildOrbVisuals` for why this ignores world palette. */
const ORB_CORE_COLOR = '#fff8e0';
const ORB_HALO_COLOR = '#ffbe2e';
const ORB_INK = '#2b1a0c';
const WRONG_PORTAL_DEBUFF: AscensionDebuff = {
  id: 'vesperra_wrong_portal_astral_static',
  durationSec: 6,
  moveSpeedMultiplier: 0.82,
  incomingDamageMultiplier: 1.15,
};

export class AscensionCharge {
  readonly group = new THREE.Group();
  readonly orbGroup = new THREE.Group();
  readonly stations: readonly AscensionStationRuntime[];
  readonly socket: AscensionSocketRuntime;

  state: AscensionChargeState = 'idle';
  chargeProgress = 0;
  readonly position: THREE.Vector3;
  readonly velocity = new THREE.Vector3();

  private readonly pickupRadius: number;
  private readonly gravity: number;
  private readonly groundY: number;
  private readonly dpsWindowSeconds: number;
  private readonly ascendantCoreBonusSeconds: number;
  private readonly ascendantCoreBonusAvailable: () => boolean;
  private readonly consumeAscendantCoreBonus: () => boolean;
  private readonly stationRateMultiplier: (
    station: AscensionStationRuntime,
    carrier: AscensionCarrier,
    charge: AscensionCharge,
  ) => number;
  private readonly onChargeStarted?: (event: AscensionChargeEvent) => void;
  private readonly onChargeCompleted?: (event: AscensionChargeEvent) => void;
  private readonly onDelivered?: (event: AscensionDeliveryEvent) => void;
  private readonly onDropped?: (event: AscensionDropEvent) => void;
  private readonly onHazardPulse?: (event: AscensionDropEvent) => void;
  private readonly onAttractAdds?: (event: AscensionDropEvent) => void;
  private readonly hazardPulse: THREE.Mesh;
  private readonly socketCore: THREE.Mesh;
  private readonly orbGlow: THREE.Mesh;
  private carrier: AscensionCarrier | null = null;
  private activeStation: AscensionStationRuntime | null = null;
  private ascendantCoreBonusConsumed = false;
  private hazardPulseAgeSec = Number.POSITIVE_INFINITY;

  constructor(options: AscensionChargeOptions) {
    this.group.name = 'ascension_charge_system';
    this.orbGroup.name = 'ascension_charge_orb';

    const accent = options.accentColor ?? DEFAULT_ASCENSION_COLOR;
    const secondary = options.secondaryColor ?? DEFAULT_SECONDARY_COLOR;
    this.position = options.spawnPosition.clone();
    this.pickupRadius = options.pickupRadius ?? 1.35;
    this.gravity = options.gravity ?? 24;
    this.groundY = options.groundY ?? 0;
    this.dpsWindowSeconds = options.dpsWindowSeconds ?? 15;
    this.ascendantCoreBonusSeconds = options.ascendantCoreBonusSeconds ?? 4;
    this.ascendantCoreBonusAvailable = options.ascendantCoreBonusAvailable ?? (() => false);
    this.consumeAscendantCoreBonus = options.consumeAscendantCoreBonus ?? (() => true);
    this.stationRateMultiplier = options.stationRateMultiplier ?? (() => 1);
    this.onChargeStarted = options.onChargeStarted;
    this.onChargeCompleted = options.onChargeCompleted;
    this.onDelivered = options.onDelivered;
    this.onDropped = options.onDropped;
    this.onHazardPulse = options.onHazardPulse;
    this.onAttractAdds = options.onAttractAdds;

    this.socket = createSocketRuntime(options.socket, accent, secondary);
    this.stations = options.stations.map((station) => createStationRuntime(station, accent, secondary));
    this.hazardPulse = createHazardPulseMesh(accent);
    this.socketCore = this.socket.group.getObjectByName('ascension_socket_core') as THREE.Mesh;

    buildOrbVisuals(this.orbGroup, accent, secondary);
    this.orbGlow = this.orbGroup.getObjectByName('ascension_orb_glow') as THREE.Mesh;
    this.group.add(this.orbGroup, this.socket.group, this.hazardPulse);
    for (const station of this.stations) this.group.add(station.group);

    this.spawn(options.spawnPosition);
  }

  spawn(position = this.position): void {
    this.position.copy(position);
    this.velocity.set(0, 0, 0);
    this.carrier = null;
    this.activeStation = null;
    this.state = 'spawned';
    this.chargeProgress = 0;
    this.syncOrbVisual();
  }

  attemptPickup(carrier: AscensionCarrier): boolean {
    if (!this.canBePickedUp()) return false;
    const reach = this.pickupRadius + (carrier.radius ?? 0.6);
    if (carrier.position.distanceTo(this.position) > reach) return false;
    this.pickup(carrier);
    return true;
  }

  pickup(carrier: AscensionCarrier): void {
    this.carrier = carrier;
    this.activeStation = null;
    this.velocity.set(0, 0, 0);
    this.state = this.chargeProgress >= 1 ? 'charged' : 'carried';
    this.syncOrbVisual();
  }

  drop(reason = 'manual_drop'): void {
    if (!this.carrier && this.state !== 'charged') return;
    const inheritedVelocity = this.carrier?.velocity;
    if (inheritedVelocity) this.velocity.copy(inheritedVelocity);
    this.velocity.y = Math.min(this.velocity.y, 1.5);
    this.carrier = null;
    this.activeStation = null;
    this.state = 'dropped';
    this.emitDropDanger(reason);
  }

  deliverIfReady(): boolean {
    if (!this.carrier || this.chargeProgress < 1) return false;
    if (this.carrier.position.distanceTo(this.socket.position) > this.socket.radius + (this.carrier.radius ?? 0.6)) {
      return false;
    }

    const ascendantCoreBonusApplied = this.tryConsumeAscendantCoreBonus();
    const dpsWindowSeconds =
      this.dpsWindowSeconds + (ascendantCoreBonusApplied ? this.ascendantCoreBonusSeconds : 0);

    this.state = 'delivered';
    this.carrier = null;
    this.activeStation = null;
    this.velocity.set(0, 0, 0);
    this.position.copy(this.socket.position);
    this.syncOrbVisual();

    this.onDelivered?.({
      socket: this.socket,
      charge: this,
      dpsWindowSeconds,
      ascendantCoreBonusApplied,
    });
    return true;
  }

  update(deltaSec: number): void {
    if (deltaSec <= 0) return;

    if (this.carrier) {
      this.followCarrier();
      this.updateStationCharging(deltaSec);
      this.deliverIfReady();
    } else if (this.state === 'spawned' || this.state === 'dropped' || this.state === 'charged') {
      this.updateGravity(deltaSec);
    }

    this.updateVisuals(deltaSec);
  }

  applyPortalChargeOutcome(outcome: AscensionPortalOutcome, carrier: AscensionCarrier): void {
    if (outcome === 'right_portal') {
      this.pickup(carrier);
      this.chargeProgress = 1;
      this.state = 'charged';
      this.syncOrbVisual();
      return;
    }

    this.chargeProgress = 0;
    this.pickup(carrier);
    carrier.applyAscensionDebuff?.(WRONG_PORTAL_DEBUFF);
    this.drop('wrong_portal');
  }

  forceChargeComplete(carrier: AscensionCarrier): void {
    this.pickup(carrier);
    this.chargeProgress = 1;
    this.state = 'charged';
    this.activeStation = null;
    this.syncOrbVisual();
  }

  resetAscendantCoreBonus(): void {
    this.ascendantCoreBonusConsumed = false;
  }

  dispose(): void {
    disposeObjectTree(this.group);
  }

  private canBePickedUp(): boolean {
    return this.state === 'spawned' || this.state === 'dropped' || this.state === 'charged';
  }

  private followCarrier(): void {
    if (!this.carrier) return;
    if (this.carrier.ascensionAttachPoint) {
      this.carrier.ascensionAttachPoint.getWorldPosition(this.position);
    } else {
      this.position.copy(this.carrier.position).add(new THREE.Vector3(0, 1.25, 0));
    }
    if (this.carrier.velocity) this.velocity.copy(this.carrier.velocity);
    this.syncOrbVisual();
  }

  private updateStationCharging(deltaSec: number): void {
    if (!this.carrier || this.chargeProgress >= 1) return;

    const station = this.findCarrierStation(this.carrier);
    if (!station) {
      this.activeStation = null;
      this.state = 'carried';
      return;
    }

    if (this.activeStation !== station) {
      this.activeStation = station;
      this.onChargeStarted?.({ charge: this, station, carrier: this.carrier });
    }

    this.state = 'charging';
    const multiplier = Math.max(0, this.stationRateMultiplier(station, this.carrier, this));
    this.chargeProgress = Math.min(1, this.chargeProgress + (deltaSec * multiplier) / station.chargeSeconds);

    if (this.chargeProgress >= 1) {
      this.state = 'charged';
      this.onChargeCompleted?.({ charge: this, station, carrier: this.carrier });
    }
  }

  private findCarrierStation(carrier: AscensionCarrier): AscensionStationRuntime | null {
    for (const station of this.stations) {
      if (carrier.position.distanceTo(station.position) <= station.radius + (carrier.radius ?? 0.6)) return station;
    }
    return null;
  }

  private updateGravity(deltaSec: number): void {
    this.velocity.y -= this.gravity * deltaSec;
    this.position.addScaledVector(this.velocity, deltaSec);
    if (this.position.y < this.groundY) {
      this.position.y = this.groundY;
      this.velocity.y = Math.abs(this.velocity.y) * 0.18;
      this.velocity.x *= 0.78;
      this.velocity.z *= 0.78;
      if (this.velocity.lengthSq() < 0.02) this.velocity.set(0, 0, 0);
    }
    this.syncOrbVisual();
  }

  private updateVisuals(deltaSec: number): void {
    // Carried orb reads as a live power source: bigger, with a pulsing shell.
    const held = this.state === 'carried' || this.state === 'charging' || this.state === 'charged';
    const orbScale =
      (0.85 + this.chargeProgress * 0.25 + Math.sin(performance.now() * 0.006) * 0.04) * (held ? 1.18 : 1);
    this.orbGroup.scale.setScalar(orbScale);

    const glowMaterial = this.orbGlow.material;
    if (glowMaterial instanceof THREE.MeshBasicMaterial) {
      // Solid corona, so these run far hotter than the old additive haze did.
      const pulse = (Math.sin(performance.now() * 0.009) * 0.5 + 0.5) * 0.1;
      glowMaterial.opacity = held ? (this.state === 'charged' ? 1 : 0.88) + pulse : 0.62;
    }
    this.orbGlow.scale.setScalar(held ? 1.3 : 1);

    for (const station of this.stations) {
      const material = station.beam.material;
      const opacity = station === this.activeStation ? 0.25 + this.chargeProgress * 0.65 : 0.12;
      if (material instanceof THREE.MeshBasicMaterial) material.opacity = opacity;
      station.beam.scale.y = 0.35 + this.chargeProgress * 1.6;
    }

    const coreMaterial = this.socketCore.material;
    if (coreMaterial instanceof THREE.MeshBasicMaterial) {
      coreMaterial.opacity = this.chargeProgress >= 1 ? 0.9 : 0.35;
    }

    this.hazardPulseAgeSec += deltaSec;
    const pulseActive = this.hazardPulseAgeSec < 0.75;
    this.hazardPulse.visible = pulseActive;
    if (pulseActive) {
      const t = this.hazardPulseAgeSec / 0.75;
      this.hazardPulse.position.copy(this.position);
      this.hazardPulse.scale.setScalar(1 + t * 7);
      const material = this.hazardPulse.material;
      if (material instanceof THREE.MeshBasicMaterial) material.opacity = 0.7 * (1 - t);
    }
  }

  private syncOrbVisual(): void {
    this.orbGroup.position.copy(this.position);
    this.orbGroup.visible = this.state !== 'idle' && this.state !== 'delivered';
  }

  private emitDropDanger(reason: string): void {
    const event: AscensionDropEvent = {
      charge: this,
      position: this.position.clone(),
      reason,
      hazardRadius: 7.5 + this.chargeProgress * 4,
    };
    this.hazardPulseAgeSec = 0;
    this.onDropped?.(event);
    this.onHazardPulse?.(event);
    this.onAttractAdds?.(event);
  }

  private tryConsumeAscendantCoreBonus(): boolean {
    if (this.ascendantCoreBonusConsumed || !this.ascendantCoreBonusAvailable()) return false;
    if (!this.consumeAscendantCoreBonus()) return false;
    this.ascendantCoreBonusConsumed = true;
    return true;
  }
}

function buildOrbVisuals(
  parent: THREE.Group,
  accent: THREE.ColorRepresentation,
  secondary: THREE.ColorRepresentation,
): void {
  /**
   * The orb is a universal exception to palette lock. Deriving it from the boss
   * accent makes it pale cyan in a pale cyan frost world, where it cannot
   * out-read anything; it keeps a fixed warm identity instead, and the dark
   * contour ring guarantees separation even against a white sky.
   */
  const core = new THREE.Mesh(
    new THREE.SphereGeometry(0.55, 32, 18),
    createCelMaterial({
      color: ORB_CORE_COLOR,
      rimColor: ORB_HALO_COLOR,
      rimStrength: 1.15,
      ambient: 0.95,
      specularStrength: 0.65,
    }),
  );
  core.name = 'ascension_orb_core';

  /**
   * Hard-edged stepped corona in place of an additive glow sphere. Additive
   * blending is bloom soup — it dissolves the silhouette instead of stating it.
   * Flat rings in the XY plane always face the locked side camera.
   */
  const halo = new THREE.Mesh(
    new THREE.RingGeometry(0.64, 0.98, 32),
    new THREE.MeshBasicMaterial({
      color: ORB_HALO_COLOR,
      transparent: true,
      opacity: 0.95,
      depthWrite: false,
      side: THREE.DoubleSide,
    }),
  );
  halo.name = 'ascension_orb_glow';
  halo.position.z = -0.18;

  // Dark contour between the hot corona and the world. Without it the orb
  // dissolves into any light background no matter how bright the core is.
  const contour = new THREE.Mesh(
    new THREE.RingGeometry(0.98, 1.1, 32),
    new THREE.MeshBasicMaterial({
      color: ORB_INK,
      transparent: true,
      opacity: 0.92,
      depthWrite: false,
      side: THREE.DoubleSide,
    }),
  );
  contour.name = 'ascension_orb_contour';
  contour.position.z = -0.19;

  // Outermost band keeps a tie to the boss identity colour.
  const haloOuter = new THREE.Mesh(
    new THREE.RingGeometry(1.14, 1.28, 32),
    new THREE.MeshBasicMaterial({
      color: accent,
      transparent: true,
      opacity: 0.7,
      depthWrite: false,
      side: THREE.DoubleSide,
    }),
  );
  haloOuter.name = 'ascension_orb_halo_outer';
  haloOuter.position.z = -0.2;

  // Heavier tubes so the rings survive as shapes at gameplay distance.
  const ringMaterial = createCelMaterial({
    color: secondary,
    rimColor: '#ffffff',
    rimStrength: 0.8,
    ambient: 0.7,
  });
  const ringA = new THREE.Mesh(new THREE.TorusGeometry(0.9, 0.075, 8, 36), ringMaterial);
  const ringB = new THREE.Mesh(new THREE.TorusGeometry(0.9, 0.075, 8, 36), ringMaterial);
  ringA.name = 'ascension_orb_ring_a';
  ringB.name = 'ascension_orb_ring_b';
  ringA.rotation.x = Math.PI * 0.5;
  ringB.rotation.y = Math.PI * 0.5;

  parent.add(haloOuter, contour, halo, core, ringA, ringB);
  attachOutline(parent, core, '#201422', 0.05);
  // Ink scaled to the tube, not to the orb: a wider hull than this eats the
  // ring's own colour and the halo reads as a dark circle.
  attachOutline(parent, ringA, '#201422', 0.007);
  attachOutline(parent, ringB, '#201422', 0.007);
}

function createStationRuntime(
  config: AscensionStationConfig,
  accent: THREE.ColorRepresentation,
  secondary: THREE.ColorRepresentation,
): AscensionStationRuntime {
  const group = new THREE.Group();
  group.name = `ascension_station_${config.id}`;
  group.position.copy(config.position);

  const base = new THREE.Mesh(
    new THREE.CylinderGeometry(1.05, 1.2, 0.32, 8),
    createCelMaterial({ color: '#2a2030', rimColor: accent, rimStrength: 0.45, ambient: 0.45 }),
  );
  base.name = 'ascension_station_base';

  const ring = new THREE.Mesh(
    new THREE.TorusGeometry(1.18, 0.07, 8, 40),
    createCelMaterial({ color: secondary, rimColor: '#ffffff', rimStrength: 0.65, ambient: 0.5 }),
  );
  ring.name = 'ascension_station_ring';
  ring.rotation.x = Math.PI * 0.5;
  ring.position.y = 0.23;

  const beam = new THREE.Mesh(
    new THREE.CylinderGeometry(0.22, 0.38, 4.8, 16, 1, true),
    new THREE.MeshBasicMaterial({
      color: accent,
      transparent: true,
      opacity: 0.12,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
      side: THREE.DoubleSide,
    }),
  );
  beam.name = 'ascension_station_beam';
  beam.position.y = 2.55;

  group.add(base, ring, beam);
  attachOutline(group, base, '#16101c', 0.025);

  return {
    ...config,
    radius: config.radius ?? 2.1,
    chargeSeconds: config.chargeSeconds ?? 10,
    group,
    beam,
  };
}

function createSocketRuntime(
  config: AscensionSocketConfig,
  accent: THREE.ColorRepresentation,
  secondary: THREE.ColorRepresentation,
): AscensionSocketRuntime {
  const group = new THREE.Group();
  group.name = `ascension_socket_${config.id}`;
  group.position.copy(config.position);

  const cradle = new THREE.Mesh(
    new THREE.CylinderGeometry(1.35, 1.55, 0.5, 10),
    createCelMaterial({ color: '#34243a', rimColor: secondary, rimStrength: 0.55, ambient: 0.45 }),
  );
  cradle.name = 'ascension_socket_cradle';

  const ring = new THREE.Mesh(
    new THREE.TorusGeometry(1.45, 0.09, 8, 48),
    createCelMaterial({ color: accent, rimColor: '#ffffff', rimStrength: 0.8, ambient: 0.55 }),
  );
  ring.name = 'ascension_socket_ring';
  ring.rotation.x = Math.PI * 0.5;
  ring.position.y = 0.42;

  const core = new THREE.Mesh(
    new THREE.SphereGeometry(0.42, 20, 12),
    new THREE.MeshBasicMaterial({
      color: accent,
      transparent: true,
      opacity: 0.35,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
    }),
  );
  core.name = 'ascension_socket_core';
  core.position.y = 0.92;

  group.add(cradle, ring, core);
  attachOutline(group, cradle, '#16101c', 0.03);

  return {
    ...config,
    radius: config.radius ?? 2.25,
    group,
  };
}

function createHazardPulseMesh(accent: THREE.ColorRepresentation): THREE.Mesh {
  const pulse = new THREE.Mesh(
    new THREE.TorusGeometry(1, 0.035, 8, 72),
    new THREE.MeshBasicMaterial({
      color: accent,
      transparent: true,
      opacity: 0,
      blending: THREE.AdditiveBlending,
      depthWrite: false,
    }),
  );
  pulse.name = 'ascension_drop_hazard_pulse';
  pulse.rotation.x = Math.PI * 0.5;
  pulse.visible = false;
  return pulse;
}

function disposeObjectTree(root: THREE.Object3D): void {
  root.traverse((object) => {
    if (!(object instanceof THREE.Mesh)) return;
    object.geometry.dispose();
    const material = object.material;
    if (Array.isArray(material)) {
      for (const entry of material) entry.dispose();
    } else {
      material.dispose();
    }
  });
}
