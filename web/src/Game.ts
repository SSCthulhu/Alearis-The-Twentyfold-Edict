import * as THREE from 'three';
import { AudioEngine } from './audio/AudioEngine';
import { MusicBeds } from './audio/MusicBeds';
import { Sfx, type SfxName } from './audio/Sfx';
import { AssetPreloader, disposeObject3D } from './assets/KayKitLoader';
import { AscensionCharge } from './boss/AscensionCharge';
import { BossController } from './boss/BossController';
import {
  getFinalBossIdentity,
  getWorldBossIdentity,
  type BossIdentity,
} from './boss/BossIdentities';
import { BossMovement } from './boss/BossMovement';
import { ProjectilePoolAdapter } from './boss/BulletPatterns';
import { buildBossVisual, disposeBossVisual, updateBossVisual } from './boss/BossVisual';
import { GameCamera } from './camera/GameCamera';
import { DamageNumberSystem } from './combat/DamageNumbers';
import { ProjectilePool, type ProjectileSnapshot } from './combat/Projectiles';
import { bus, Events } from './core/EventBus';
import { RunState } from './core/RunState';
import type { ClassId, GamePhase, WorldId } from './core/types';
import {
  getActiveEvent,
  getFastClearSeconds,
  onBossKill,
  onDamageDealt,
  onFastClear,
  onKill,
  onPerfectDodge,
  tryInvoke,
  update as updateDiceMeter,
} from './dice/DiceMeter';
import { getCouncilCombatMods, tickCouncilEffects } from './dice/CouncilEffects';
import { MODIFIER_DATABASE } from './dice/ModifierDatabase';
import { offerModifiers } from './dice/modifierOffer';
import { rollFinalBoss, rollVictoryReward } from './dice/victoryRewards';
import { baseCombatMods, getModifierCombatMods, type CombatMods } from './dice/ModifierEffects';
import type { EnemyBase } from './enemies/EnemyBase';
import { perfBudget } from './performance/Budget';
import { getClassDef } from './player/ClassDefs';
import { PlayerInput } from './player/Input';
import { PlayerController } from './player/PlayerController';
import type { PlayerCombatEvent } from './player/PlayerCombat';
import { getRelicById, type RelicDef } from './relics/RelicDatabase';
import { RelicEffects } from './relics/RelicEffects';
import { offerRelics } from './relics/relicOffer';
import { applyWorldRamp } from './render/CelMaterial';
import { getPalette } from './render/Palettes';
import { PostPipeline } from './render/PostPipeline';
import { SkyDome } from './render/SkyDome';
import { HudRenderer, type HudState } from './ui/HudRenderer';
import { CharacterSelect } from './ui/screens/CharacterSelect';
import { DeathScreen } from './ui/screens/DeathScreen';
import { DiceEventBanner } from './ui/screens/DiceEventBanner';
import { MainMenu } from './ui/screens/MainMenu';
import { ModifierChoice } from './ui/screens/ModifierChoice';
import { PauseSettings } from './ui/screens/PauseSettings';
import { RelicChoice } from './ui/screens/RelicChoice';
import { VictoryRoll } from './ui/screens/VictoryRoll';
import { ContactShadows } from './vfx/ContactShadows';
import { setVfxPalette, VfxSystem } from './vfx/VfxSystem';
import { buildArena, updateArenaDrift, type Arena } from './world/ArenaBuilder';
import { EncounterController } from './world/EncounterController';
import { FloorProgression } from './world/FloorProgression';

export type HarnessScenario =
  | 'menu'
  | 'character_select'
  | 'combat'
  | 'mage_combat'
  | 'orb_carry'
  | 'dps_window'
  | 'dice_roll_ui'
  | 'modifier_choice'
  | 'final_boss'
  | 'victory'
  | 'death';

export interface PlayerDebugState {
  x: number;
  y: number;
  grounded: boolean;
  classId: string;
  hp: number;
  alive: boolean;
  jumpedLastFrame?: boolean;
}

export interface RunTelemetry {
  phase: string;
  kills: number;
  floor: number;
  world: number;
  classId: string;
  enemyAlive: number;
}

export interface AlearisDebugApi {
  getPhase: () => GamePhase;
  getRunSnapshot: () => Record<string, unknown>;
  getPlayerState: () => PlayerDebugState | null;
  getRunTelemetry: () => RunTelemetry;
  setScenario: (scenario: HarnessScenario) => Promise<void>;
  startRun: (classId?: ClassId, seed?: number) => void;
  ready: boolean;
  version: string;
}

declare global {
  interface Window {
    __ALEARIS__?: AlearisDebugApi;
  }
}

function aabbOverlap(
  ax: number, ay: number, aw: number, ah: number,
  bx: number, by: number, bw: number, bh: number,
): boolean {
  return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
}

function pointSegmentDistanceSq(point: THREE.Vector3, start: THREE.Vector3, end: THREE.Vector3): number {
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  const lengthSq = dx * dx + dy * dy;
  if (lengthSq <= 0.000001) {
    const px = point.x - start.x;
    const py = point.y - start.y;
    return px * px + py * py;
  }
  const t = THREE.MathUtils.clamp(((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSq, 0, 1);
  const px = point.x - (start.x + dx * t);
  const py = point.y - (start.y + dy * t);
  return px * px + py * py;
}

function playSfx(sfx: Sfx, name: SfxName): void {
  sfx.play(name);
}

/** A player swing whose hitbox stays live for the attack's full duration. */
interface ActiveAttackInstance {
  event: PlayerCombatEvent;
  remaining: number;
  hitEnemies: Set<EnemyBase>;
  hitBoss: boolean;
}

const HIT_STOP_NORMAL_SEC = 0.045;
const HIT_STOP_CRIT_SEC = 0.07;
const HIT_STOP_TIME_SCALE = 0.05;

export class Game {
  readonly renderer: THREE.WebGLRenderer;
  readonly scene = new THREE.Scene();
  readonly cameraRig: GameCamera;
  readonly post: PostPipeline;
  readonly sky = new SkyDome();
  readonly input = new PlayerInput();
  readonly audio = new AudioEngine();
  readonly sfx: Sfx;
  readonly music: MusicBeds;
  readonly hud: HudRenderer;
  private readonly bossFocusPoint = new THREE.Vector3();
  readonly vfx = new VfxSystem();
  readonly contactShadows = new ContactShadows();
  readonly projectiles: ProjectilePool;
  readonly damageNumbers = new DamageNumberSystem();

  run: RunState;
  relics: RelicEffects;
  progression: FloorProgression;
  arena: Arena | null = null;
  player: PlayerController | null = null;
  encounter: EncounterController | null = null;
  boss: BossController | null = null;
  bossVisual: THREE.Group | null = null;
  bossMovement: BossMovement | null = null;
  ascension: AscensionCharge | null = null;

  private readonly uiRoot: HTMLElement;
  private readonly clock = new THREE.Clock();
  private readonly worldRoot = new THREE.Group();
  private readonly keyLight = new THREE.DirectionalLight(0xfff2d8, 1.1);
  private readonly fillLight = new THREE.DirectionalLight(0x6a9cc0, 0.45);
  private readonly ambient = new THREE.AmbientLight(0xa0c0d8, 0.55);

  private mainMenu: MainMenu | null = null;
  private characterSelect: CharacterSelect | null = null;
  private modifierUi: ModifierChoice | null = null;
  private relicUi: RelicChoice | null = null;
  private victoryUi: VictoryRoll | null = null;
  private deathUi: DeathScreen | null = null;
  private pauseUi: PauseSettings | null = null;
  private diceBanner: DiceEventBanner | null = null;

  private time = 0;
  private playing = false;
  private chestPromptVisible = false;
  private pendingRelics: RelicDef[] = [];
  private pendingVictoryRoll = 0;
  private pendingVictoryBand: 'SURVIVAL' | 'CORE' | 'GREED_DAMAGE' = 'CORE';
  private bossIntroTimer = 0;
  private livePlayerPos = new THREE.Vector3();
  private currentCouncilMods: CombatMods = getCouncilCombatMods(null);
  private readonly activeAttacks: ActiveAttackInstance[] = [];
  private hitStopRemaining = 0;
  private orbGlowTimer = 0;
  private projectilePatternSerial = 0;
  private musicIntensityTimer = 0;
  private currentModifierMods: CombatMods = baseCombatMods();
  private readonly assetPreload: Promise<void>;
  private playerJumpedLastFrame = false;

  constructor() {
    this.assetPreload = AssetPreloader.preload().catch((error: unknown) => {
      console.error('KayKit preload failed; procedural actor fallbacks remain active.', error);
    });
    const canvas = document.querySelector<HTMLCanvasElement>('#game-canvas');
    const uiRoot = document.querySelector<HTMLElement>('#ui-root');
    if (!canvas || !uiRoot) throw new Error('Missing #game-canvas or #ui-root');
    this.uiRoot = uiRoot;

    this.renderer = new THREE.WebGLRenderer({
      canvas,
      antialias: true,
      powerPreference: 'high-performance',
    });
    this.renderer.outputColorSpace = THREE.SRGBColorSpace;
    this.renderer.setClearColor(0x05060a, 1);

    this.cameraRig = new GameCamera({ aspect: 16 / 9, fov: 40, sideDistance: 15 });
    this.post = new PostPipeline(this.renderer);
    this.sfx = new Sfx(this.audio);
    this.music = new MusicBeds(this.audio);
    this.projectiles = new ProjectilePool(perfBudget.projectileBudget);
    this.hud = new HudRenderer({
      canvas: document.querySelector<HTMLCanvasElement>('#hud-canvas') ?? undefined,
      getState: () => this.buildHudState(),
    });

    this.run = new RunState();
    this.relics = new RelicEffects(this.run);
    this.progression = new FloorProgression(this.run);

    this.scene.add(this.sky.mesh, this.worldRoot, this.vfx.root, this.contactShadows.root, this.projectiles.root, this.damageNumbers.root);
    this.scene.add(this.ambient, this.keyLight, this.fillLight);
    this.keyLight.position.set(8, 18, 10);
    this.fillLight.position.set(-10, 6, -6);

    this.input.attach(window);
    this.bindEvents();
    this.resize();
    window.addEventListener('resize', () => this.resize());

    this.showMainMenu();
    this.exposeDebugApi();
    this.hud.start();
    this.loop();
  }

  private bindEvents(): void {
    bus.on(Events.PERFECT_DODGE, () => {
      onPerfectDodge(this.run);
      playSfx(this.sfx, 'perfectDodgeChime');
      if (this.player) this.vfx.spawnPerfectDodgeFlashRing(this.player.position);
    });
    bus.on(Events.DICE_EVENT, (payload: { event: { name: string; polarity: string; description: string } }) => {
      if (!this.diceBanner) {
        this.diceBanner = new DiceEventBanner({ root: this.uiRoot });
      }
      const polarity = payload.event.polarity;
      const tone = polarity === 'catastrophe' || polarity === 'council' ? (polarity === 'catastrophe' ? 'danger' : 'council') : 'divine';
      this.diceBanner.show({
        title: payload.event.name,
        subtitle: payload.event.description,
        activeEffect: payload.event.name,
        tone: tone as 'council' | 'divine' | 'danger',
      });
      playSfx(this.sfx, polarity === 'miracle' || polarity === 'divine' ? 'divineMotif' : 'councilMotif');
    });
  }

  private showMainMenu(): void {
    this.clearUi();
    this.playing = false;
    this.run.phase = 'main_menu';
    this.mainMenu = new MainMenu({
      root: this.uiRoot,
      onStart: () => this.showCharacterSelect(),
      onContinue: () => this.showCharacterSelect(),
      onSettings: () => this.showPause(true),
    });
    this.applyWorldVisuals(1);
    this.syncHudVisibility();
  }

  private showCharacterSelect(): void {
    this.clearUi();
    this.run.phase = 'character_select';
    this.characterSelect = new CharacterSelect({
      root: this.uiRoot,
      onSelect: (classId) => {
        void this.audio.resume();
        void this.startRunAfterPreload(classId);
      },
      onBack: () => this.showMainMenu(),
    });
    this.syncHudVisibility();
  }

  startRun(classId: ClassId = 'knight', seed?: number): void {
    this.clearUi();
    this.teardownFloor();
    this.run = new RunState(seed);
    this.run.classId = classId;
    this.relics = new RelicEffects(this.run);
    this.progression = new FloorProgression(this.run);
    this.playing = true;
    this.music.startWorld(1);
    this.loadFloor();
  }

  private async startRunAfterPreload(classId: ClassId, seed?: number): Promise<void> {
    await this.assetPreload;
    this.startRun(classId, seed);
  }

  private loadFloor(): void {
    // Carry health across floors so heals (modifiers, heal-on-floor) stay meaningful.
    const carriedHp = this.player !== null && this.player.health.alive ? this.player.health.hp : null;
    this.teardownFloor();
    this.progression.beginFloor();
    this.relics.onFloorStart();
    this.currentModifierMods = getModifierCombatMods(this.run);

    const rng = this.run.rng('layout', this.run.world * 50 + this.run.floor);
    this.arena = buildArena(this.run.world, this.run.floor, rng);
    this.worldRoot.add(this.arena.root);
    this.applyWorldVisuals(this.run.world);
    this.music.startWorld(this.run.world as 1 | 2 | 3 | 4);

    this.player = new PlayerController(this.run, this.arena.spawns.player);
    this.playerJumpedLastFrame = false;
    this.applyPlayerRelics();
    // PlayerController caps the composed gravity multiplier against the same
    // jump-clearance budget ArenaBuilder uses for platform step validation.
    this.player.setCouncilCombatMods(this.currentCouncilMods);
    this.worldRoot.add(this.player.root);
    if (carriedHp !== null) {
      this.player.health.hp = Math.max(1, Math.min(this.player.health.maxHp, carriedHp));
    }
    const floorHeal = this.currentModifierMods.playerHealOnFloor;
    if (floorHeal > 0 && this.player.health.heal(floorHeal) > 0) {
      this.vfx.spawnHealCrosses(this.player.position);
      playSfx(this.sfx, 'heal');
    }

    if (this.run.isBossFloor()) {
      this.setupBoss();
      this.run.phase = 'boss_intro';
      this.bossIntroTimer = 2.2;
      this.cameraRig.startBossReveal(
        this.player.position,
        this.getBossFocus() ?? new THREE.Vector3(0, 4, 0),
        2.2,
        this.getBossHalfHeight(),
      );
      playSfx(this.sfx, 'bossCastTell');
    } else {
      this.encounter = new EncounterController(this.run, this.arena);
      this.worldRoot.add(this.encounter.root);
      this.encounter.spawnInitialWave();
      this.progression.beginCombat();
    }

    this.chestPromptVisible = false;
    this.syncHudVisibility();
  }

  private setupBoss(): void {
    if (!this.arena || !this.player) return;

    let identity: BossIdentity;
    if (this.run.world === 4) {
      if (!this.run.finalBossId) {
        const rolled = rollFinalBoss(this.run);
        this.run.finalBossId = rolled.bossId;
      }
      identity = getFinalBossIdentity(this.run.finalBossId);
    } else {
      identity = getWorldBossIdentity(this.run.world as 1 | 2 | 3);
    }

    // Boss floors must ship real ascension geometry — no synthetic fallbacks.
    const socket = this.arena.sockets[0];
    if (!socket) {
      throw new Error(`Arena w${this.arena.world} f${this.arena.floor} is missing an ascension socket on a boss floor`);
    }
    if (this.arena.chargeStations.length === 0) {
      throw new Error(`Arena w${this.arena.world} f${this.arena.floor} has no charge stations on a boss floor`);
    }

    const projectileAdapter = new ProjectilePoolAdapter(
      this.projectiles,
      () => this.currentCouncilMods.enemyProjectileSpeedMult,
    );
    const playerPos = this.livePlayerPos;
    this.boss = new BossController({
      identity,
      runState: this.run,
      projectileSystem: projectileAdapter,
      projectileTarget: { position: playerPos },
      getProjectileOrigin: () => this.bossVisual?.position.clone() ?? new THREE.Vector3(0, 4, 0),
      autoUpdateProjectiles: false,
      onTelegraph: (ev) => {
        if (!this.bossVisual) return;
        const origin = this.bossVisual.position.clone();
        origin.y += 1.2;
        if (identity.moveStyle === 'horizontal_forge_lanes') {
          const toPlayer = Math.sign(this.livePlayerPos.x - origin.x) || 1;
          this.vfx.spawnGroundTelegraph(origin, {
            shape: 'lane',
            direction: new THREE.Vector3(toPlayer, 0, 0),
            duration: ev.durationSec,
            color: identity.accentColor,
            length: 10,
          });
        } else {
          this.vfx.spawnGroundTelegraph(origin, {
            shape: 'ring',
            duration: ev.durationSec,
            color: identity.accentColor,
            radius: 2.4,
          });
        }
      },
      onAddSpawn: (event) => {
        if (!this.arena) return;
        if (!this.encounter) {
          this.encounter = new EncounterController(this.run, this.arena);
          this.worldRoot.add(this.encounter.root);
        }
        this.encounter.spawnWave(event.budget);
      },
      onDpsWindowStarted: () => {
        this.relics.onDpsWindowStart();
        this.music.setBossDpsActive(true);
        playSfx(this.sfx, 'socketDeliverySting');
        bus.emit(Events.DPS_WINDOW_START, {});
        bus.emit(Events.SCREEN_SHAKE, { intensity: 0.35, duration: 0.35 });
      },
      onDpsWindowEnded: () => {
        this.music.setBossDpsActive(false);
        bus.emit(Events.DPS_WINDOW_END, {});
        if (this.arena) {
          this.ascension?.spawn(
            new THREE.Vector3(this.arena.spawns.player.x + 2, this.arena.spawns.player.y + 2, 0),
          );
        }
      },
      onDefeated: () => this.onBossDefeated(),
      onCastStarted: () => playSfx(this.sfx, 'bossCastTell'),
    });

    this.bossVisual = buildBossVisual(identity);
    this.bossVisual.position.set(socket.x - 2, socket.y + 1.5, 0);
    this.worldRoot.add(this.bossVisual);

    this.bossMovement = new BossMovement({
      identity,
      arena: this.arena,
      rng: this.run.rng('encounter', 0xb055 + this.run.world * 7),
      home: { x: socket.x - 2, y: socket.y + 1.5 },
      onBlink: (from, to) => {
        this.vfx.spawnPortalSwirl(from, { color: identity.accentColor, secondaryColor: identity.secondaryColor });
        this.vfx.spawnPortalSwirl(to, { color: identity.accentColor, secondaryColor: identity.secondaryColor });
      },
    });

    const stations = this.arena.chargeStations.map((s, i) => ({
      id: `station_${i}`,
      position: new THREE.Vector3(s.x, s.y, 0),
      chargeSeconds: identity.socketChargeSeconds || 10,
    }));

    this.ascension = new AscensionCharge({
      spawnPosition: new THREE.Vector3(
        this.arena.spawns.player.x + 3,
        this.arena.spawns.player.y + 1.5,
        0,
      ),
      stations,
      socket: {
        id: 'ascension_socket',
        position: new THREE.Vector3(socket.x, socket.y, 0),
      },
      accentColor: identity.accentColor,
      secondaryColor: identity.secondaryColor,
      dpsWindowSeconds: identity.dpsWindowSeconds,
      groundY: this.arena.platforms[0]?.topY ?? 0,
      stationRateMultiplier: () => this.relics.getOrbChargeRateMult(),
      ascendantCoreBonusAvailable: () =>
        this.run.relics.some((r) => (r.params.dpsWindowBonusSeconds ?? 0) > 0),
      consumeAscendantCoreBonus: () => {
        this.relics.onDpsWindowStart();
        return this.relics.getDpsWindowBonus() > 0;
      },
      onDelivered: (ev) => {
        this.boss?.handleAscensionDelivery(ev);
        playSfx(this.sfx, 'socketDeliverySting');
      },
      onDropped: () => {
        this.boss?.notifyOrbDropped();
        playSfx(this.sfx, 'combatHit');
        bus.emit(Events.ASCENSION_DROP, {});
      },
      onChargeStarted: () => playSfx(this.sfx, 'chargeHum'),
      onChargeCompleted: () => playSfx(this.sfx, 'orbPickup'),
    });
    this.worldRoot.add(this.ascension.group);
  }

  private onBossDefeated(): void {
    onBossKill(this.run);
    playSfx(this.sfx, 'divineMotif');
    this.music.setBossDpsActive(false);
    bus.emit(Events.SCREEN_SHAKE, { intensity: 0.6, duration: 0.6 });

    if (this.run.world === 4) {
      this.run.recordClear(this.run.runElapsed);
      this.run.phase = 'victory';
      this.playing = false;
      this.cameraRig.startVictoryOrbit(this.bossVisual?.position ?? new THREE.Vector3(), 6);
      this.clearUi();
      this.deathUi = new DeathScreen({
        root: this.uiRoot,
        variant: 'victory',
        kicker: 'Run Complete',
        title: 'Edict Fulfilled',
        cause: 'Edict Fulfilled — the Twentyfold Sovereign yields.',
        stats: {
          world: this.run.world,
          floor: this.run.floor,
          runTimeSeconds: this.run.runElapsed,
          kills: this.run.kills,
          lastRoll: this.run.lastRoll,
        },
        onRetry: () => this.showCharacterSelect(),
        onMainMenu: () => this.showMainMenu(),
      });
      this.syncHudVisibility();
      return;
    }

    const reward = rollVictoryReward(this.run, {
      bonus: this.relics.getVictoryRollBonus(),
      lowRollFloor: this.relics.getLowRollFloor(),
    });
    this.pendingVictoryRoll = reward.roll;
    this.pendingVictoryBand = reward.band;
    this.pendingRelics = offerRelics(this.run, reward.band, 3);
    this.progression.markCombatCleared();
    this.showVictoryRoll();
  }

  private showVictoryRoll(): void {
    this.clearUi();
    this.run.phase = 'victory_roll';
    this.syncHudVisibility();
    playSfx(this.sfx, 'diceRollStinger');
    this.victoryUi = new VictoryRoll({
      root: this.uiRoot,
      result: {
        roll: this.pendingVictoryRoll,
        band: this.pendingVictoryBand,
      },
      onContinue: () => this.showRelicChoice(),
    });
  }

  private showRelicChoice(): void {
    this.clearUi();
    this.progression.completeVictoryRoll();
    this.syncHudVisibility();
    this.relicUi = new RelicChoice({
      root: this.uiRoot,
      roll: this.pendingVictoryRoll,
      relics: this.pendingRelics.map((r) => ({
        id: r.id,
        name: r.name,
        description: r.description,
        rarity: r.rarity,
        band: r.band,
      })),
      onChoose: (card) => {
        const def = getRelicById(card.id) ?? this.pendingRelics.find((r) => r.id === card.id);
        if (def) {
          this.run.addRelic({
            id: def.id,
            name: def.name,
            rarity: def.rarity,
            band: def.band,
            effectId: def.effectId,
            params: { ...def.params },
          });
        }
        playSfx(this.sfx, 'uiTick');
        this.progression.completeRelicChoice();
        this.loadFloor();
      },
    });
  }

  private showModifierChoice(): void {
    this.clearUi();
    this.run.phase = 'modifier_choice';
    this.syncHudVisibility();
    const mods = offerModifiers(this.run);
    this.modifierUi = new ModifierChoice({
      root: this.uiRoot,
      modifiers: mods.map((m) => ({
        id: m.id,
        name: m.name,
        description: m.description,
        delta: m.delta,
      })),
      onChoose: (card) => {
        const def = MODIFIER_DATABASE.find((m) => m.id === card.id);
        if (def) {
          this.run.addModifier({
            id: def.id,
            name: def.name,
            delta: def.delta,
            exclusiveTag: def.exclusiveTag,
          });
          if (def.delta === 0) {
            this.player?.health.heal(def.params.amount ?? 25);
            playSfx(this.sfx, 'heal');
            if (this.player) this.vfx.spawnHealCrosses(this.player.position);
          }
        }
        playSfx(this.sfx, 'uiTick');
        this.progression.completeModifierChoice();
        this.clearUi();
        this.loadFloor();
      },
    });
  }

  private showPause(fromMenu = false): void {
    this.pauseUi?.unmount();
    this.pauseUi = new PauseSettings({
      root: this.uiRoot,
      musicVolume: this.audio.currentMusicVolume,
      sfxVolume: this.audio.currentSfxVolume,
      onMusicVolume: (v) => this.audio.setMusicVolume(v),
      onSfxVolume: (v) => this.audio.setSfxVolume(v),
      onResume: () => {
        this.pauseUi?.unmount();
        this.pauseUi = null;
        if (!fromMenu) {
          this.run.paused = false;
          this.run.phase = this.run.isBossFloor() ? 'boss_fight' : 'combat';
        }
        this.syncHudVisibility();
      },
      onQuit: () => this.showMainMenu(),
    });
    if (!fromMenu) {
      this.run.paused = true;
      this.run.phase = 'pause';
    }
    this.syncHudVisibility();
  }

  private teardownFloor(): void {
    this.encounter?.clear();
    if (this.encounter) this.worldRoot.remove(this.encounter.root);
    this.encounter = null;
    if (this.player) {
      this.worldRoot.remove(this.player.root);
      this.player.figure.dispose();
    }
    this.player = null;
    if (this.bossVisual) {
      this.worldRoot.remove(this.bossVisual);
      disposeBossVisual(this.bossVisual);
    }
    this.bossVisual = null;
    this.boss = null;
    if (this.ascension) {
      this.worldRoot.remove(this.ascension.group);
      // AscensionCharge owns its orb/station/socket geometry; release it or a
      // full run leaks every boss floor's ascension meshes.
      this.ascension.dispose();
    }
    this.ascension = null;
    if (this.arena) {
      this.worldRoot.remove(this.arena.root);
      // Arenas are rebuilt every floor from fresh geometry and materials. Cel
      // ShaderMaterials keep the shared ramp/matcap/surface textures in their
      // uniforms (not as direct material props), so disposing the tree frees
      // per-floor geometry and material programs without touching those
      // run-shared textures.
      disposeObject3D(this.arena.root);
    }
    this.arena = null;
    for (const snap of this.projectiles.snapshots()) {
      this.projectiles.deactivate(snap.id);
    }
  }

  private clearUi(): void {
    this.mainMenu?.unmount();
    this.characterSelect?.unmount();
    this.modifierUi?.unmount();
    this.relicUi?.unmount();
    this.victoryUi?.unmount();
    this.deathUi?.unmount();
    this.pauseUi?.unmount();
    this.diceBanner?.unmount();
    this.mainMenu = null;
    this.characterSelect = null;
    this.modifierUi = null;
    this.relicUi = null;
    this.victoryUi = null;
    this.deathUi = null;
    this.pauseUi = null;
    this.diceBanner = null;
  }

  private syncHudVisibility(): void {
    this.hud.setVisible(!this.isHudHiddenPhase(this.run.phase));
  }

  private applyPlayerRelics(): void {
    this.player?.setRelicModifiers({
      dashChargesBonus: this.relics.getDashChargesBonus(),
      moveSpeedMult: this.relics.getMoveSpeedMult(),
      perfectWindowBonus: this.relics.getPerfectWindowBonus(),
      critChanceBonus: this.relics.getCritChanceBonus(),
    });
  }

  private isHudHiddenPhase(phase: GamePhase): boolean {
    return (
      phase === 'main_menu' ||
      phase === 'character_select' ||
      phase === 'modifier_choice' ||
      phase === 'relic_choice' ||
      phase === 'victory_roll' ||
      phase === 'victory' ||
      phase === 'death' ||
      phase === 'pause'
    );
  }

  /**
   * Boss framing anchor. The boss root sits at its feet, so every camera call
   * must aim at the published visual centre instead or the head leaves frame.
   */
  private getBossFocus(): THREE.Vector3 | null {
    if (!this.bossVisual) return null;
    const centerY = (this.bossVisual.userData.visualCenterY as number | undefined) ?? 0;
    return this.bossFocusPoint.set(
      this.bossVisual.position.x,
      this.bossVisual.position.y + centerY,
      0,
    );
  }

  private getBossHalfHeight(): number {
    return (this.bossVisual?.userData.visualHalfHeight as number | undefined) ?? 0;
  }

  private applyWorldVisuals(world: number): void {
    const p = getPalette(world);
    // Regrade the shared toon ramp before anything for this world is built, so
    // arena and actor materials quantize against the world's own band colors.
    applyWorldRamp(world);
    this.sky.applyPalette(p);
    this.post.setWorld(world);
    // Effects and contact shadows join the world palette instead of dragging
    // neutral grey and near-black across every arena.
    setVfxPalette({
      accent: `#${p.accent.getHexString()}`,
      secondary: `#${p.platformEdge.getHexString()}`,
      ink: `#${p.ink.getHexString()}`,
      smoke: `#${p.cloud.getHexString()}`,
    });
    this.contactShadows.setTint(p.ink);
    this.ambient.color.copy(p.ambient);
    this.keyLight.color.copy(p.keyLight);
    this.fillLight.color.copy(p.fillLight);
    // Keep the scene key light aligned with the sun the sky actually draws.
    const sun = this.sky.getSunDirection();
    this.keyLight.position.copy(sun).multiplyScalar(24);
    this.renderer.setClearColor(p.skyBot, 1);
  }

  private resize(): void {
    const w = window.innerWidth;
    const h = window.innerHeight;
    const pr = perfBudget.pixelRatio;
    this.renderer.setPixelRatio(pr);
    this.renderer.setSize(w, h, false);
    this.cameraRig.resize(w / h);
    this.post.setSize(w, h, pr);
    this.hud.resize();
  }

  private loop = (): void => {
    requestAnimationFrame(this.loop);
    const rawDt = Math.min(0.05, this.clock.getDelta());
    perfBudget.observeFrame(rawDt);
    // Hit-stop: near-freeze simulation briefly on melee connects for impact weight.
    let dt = rawDt;
    if (this.hitStopRemaining > 0) {
      this.hitStopRemaining = Math.max(0, this.hitStopRemaining - rawDt);
      dt = rawDt * HIT_STOP_TIME_SCALE;
    }
    this.time += dt;
    if (Math.abs(this.renderer.getPixelRatio() - perfBudget.pixelRatio) > 0.01) {
      this.resize();
    }
    this.update(dt);
    this.updateContactShadows();
    this.render();
  };

  /** Hard-edged blob shadows under every live figure — cheap grounding for the cel look. */
  private updateContactShadows(): void {
    this.contactShadows.beginFrame();
    if (this.playing && this.player && this.arena) {
      const platforms = this.arena.platforms;
      if (this.player.health.alive) {
        this.contactShadows.place(this.player.position.x, this.player.position.y, 0.66, platforms);
      }
      if (this.encounter) {
        for (const enemy of this.encounter.enemies) {
          if (!enemy.alive) continue;
          this.contactShadows.place(
            enemy.root.position.x,
            enemy.root.position.y,
            enemy.elite ? 0.92 : 0.58,
            platforms,
          );
        }
      }
      if (this.bossVisual && this.boss && this.boss.hp > 0) {
        this.contactShadows.place(this.bossVisual.position.x, this.bossVisual.position.y, 1.9, platforms);
      }
    }
    this.contactShadows.endFrame();
  }

  private update(dt: number): void {
    this.playerJumpedLastFrame = false;
    this.sky.update(this.time);
    if (this.arena) updateArenaDrift(this.arena.root, this.time);
    this.vfx.update(dt);
    this.damageNumbers.update(dt);
    this.projectiles.update(dt);
    const activeEvent = updateDiceMeter(dt);
    this.currentCouncilMods = getCouncilCombatMods(activeEvent);
    this.player?.setCouncilCombatMods(this.currentCouncilMods);
    this.encounter?.setCouncilCombatMods(this.currentCouncilMods);
    this.post.setVignette(
      activeEvent?.event.effectId === 'council_void_lanterns'
        ? Math.min(0.6, 1 - (activeEvent.event.params.visibilityMult ?? 0.72))
        : 0,
    );
    this.syncHudVisibility();

    const snap = this.input.poll();
    if (snap.pausePressed && this.playing) {
      if (this.run.phase === 'pause') {
        this.pauseUi?.unmount();
        this.pauseUi = null;
        this.run.paused = false;
        this.run.phase = this.run.isBossFloor() ? 'boss_fight' : 'combat';
      } else if (
        this.run.phase === 'combat' ||
        this.run.phase === 'boss_fight' ||
        this.run.phase === 'floor_intro'
      ) {
        this.showPause();
      }
    }

    if (!this.playing || this.run.paused || !this.player || !this.arena) {
      if (this.player && this.arena) {
        this.cameraRig.update(dt, this.player.position, this.run.world, this.arena.bounds);
      }
      return;
    }

    this.run.runElapsed += dt;
    this.run.floorElapsed += dt;
    this.livePlayerPos.copy(this.player.position);
    this.updateMusicIntensity(dt);

    if (this.run.phase === 'boss_intro') {
      this.bossIntroTimer -= dt;
      this.cameraRig.update(
        dt,
        this.player.position,
        this.run.world,
        this.arena.bounds,
        this.getBossFocus(),
        0.55,
        this.getBossHalfHeight(),
      );
      if (this.bossIntroTimer <= 0) this.progression.beginCombat();
      return;
    }

    if (
      this.run.phase !== 'combat' &&
      this.run.phase !== 'boss_fight' &&
      this.run.phase !== 'chest'
    ) {
      this.cameraRig.update(dt, this.player.position, this.run.world, this.arena.bounds);
      return;
    }

    if (snap.dicePressed && this.run.diceMeter >= 100) {
      const ev = tryInvoke(this.run);
      if (ev) playSfx(this.sfx, 'diceRollStinger');
    }

    const frame = this.player.update(dt, snap, this.arena);
    this.playerJumpedLastFrame = frame.jumped;

    if (frame.landed) {
      this.vfx.spawnLandSmoke(this.player.position);
      playSfx(this.sfx, 'land');
    }
    if (frame.jumped) {
      this.vfx.spawnJumpSmoke(this.player.position);
      playSfx(this.sfx, 'jump');
    }
    if (frame.dashStarted) {
      this.vfx.spawnDashSmoke(this.player.position, new THREE.Vector3(frame.facing, 0, 0));
      playSfx(this.sfx, 'rollDashWhoosh');
    }

    if (activeEvent !== null) {
      tickCouncilEffects(dt, activeEvent, {
        playerPosition: this.player.position,
        hazardFrequencyMult: this.currentModifierMods.hazardFrequencyMult,
        healPlayer: (amount) => this.player?.health.heal(amount) ?? 0,
        applyTemporaryShield: (duration, damageReduction) => {
          this.player?.buffs.apply({
            id: 'council_barrier',
            duration,
            damageReduction,
            source: 'council',
          });
          if (this.player) this.vfx.spawnShieldBubble(this.player.position, { color: '#ffe080', secondaryColor: '#fff4c8' });
        },
        applyNonlethalHazardDamage: (amount) => this.applyCouncilHazardDamage(amount),
        spawnHazardPulse: (position, radius, color) => this.vfx.spawnPerfectDodgeFlashRing(position, { color: color ?? '#ff5a72', secondaryColor: '#ffe080', scale: radius }),
        applyEnemySlow: (radius, duration) => this.applyCouncilEnemySlow(radius, duration),
        spawnMirrorShades: (count, hpMult) => this.spawnCouncilMirrorShades(count, hpMult),
        rng: this.run.rng('dice_meter', activeEvent.event.roll * 1000 + Math.floor(activeEvent.elapsed * 20)),
      });
    }

    for (const atk of frame.combatEvents) {
      this.handlePlayerCombatEvent(atk);
    }
    this.updateActiveAttacks(dt);

    if (this.encounter && this.run.phase === 'combat') {
      const enc = this.encounter.update(dt, this.player.position);
      for (const death of enc.deaths) {
        onKill(this.run, { elite: death.elite });
        const heal = this.relics.getHealOnKill();
        if (heal > 0) {
          this.player.health.heal(heal);
          this.vfx.spawnHealCrosses(this.player.position);
        }
      }
      for (const contact of enc.contacts) {
        this.applyPlayerDamage(contact.damage, 'enemy', {
          fromX: contact.enemy.root.position.x,
          strength: contact.knockback,
        });
      }
      for (const melee of enc.melee) {
        const dx = this.player.position.x - melee.origin.x;
        const dy = this.player.position.y + 0.9 - melee.origin.y;
        if (Math.hypot(dx, dy) <= melee.range + 0.3) {
          this.applyPlayerDamage(melee.damage, 'enemy', {
            fromX: melee.origin.x,
            strength: melee.knockback,
          });
        }
      }
      for (const proj of enc.projectiles) {
        proj.spec.speed *= this.currentCouncilMods.enemyProjectileSpeedMult;
        this.projectilePatternSerial += 1;
        this.projectiles.spawnPattern(
          proj.spec,
          proj.origin,
          proj.aim,
          this.run.rng('boss_projectiles', this.projectilePatternSerial),
        );
      }

      if (this.progression.step === 'combat' && this.encounter.aliveCount === 0 && !this.chestPromptVisible) {
        onFastClear(this.run, this.run.floorElapsed);
        this.progression.markCombatCleared();
        this.chestPromptVisible = true;
        playSfx(this.sfx, 'uiTick');
      }
    }

    if (this.run.phase === 'chest' && this.arena) {
      const c = this.arena.chest;
      const near = Math.hypot(this.player.position.x - c.x, this.player.position.y - c.y) < 1.8;
      if (near && (snap.moveY > 0.5 || snap.jumpPressed || snap.lightPressed)) {
        this.progression.claimChest();
        this.showModifierChoice();
        return;
      }
    }

    if (this.boss && this.run.phase === 'boss_fight') {
      this.boss.update(dt);
      if (this.bossMovement && this.bossVisual) {
        const bossPos = this.bossMovement.update(dt, this.boss.state);
        this.bossVisual.position.x = bossPos.x;
        this.bossVisual.position.z = bossPos.z;
        // updateBossVisual bobs around baseY, so movement drives the anchor height.
        this.bossVisual.userData.baseY = bossPos.y;
      }
      if (this.bossVisual) updateBossVisual(this.bossVisual, dt, this.boss.isVulnerable());

      if (this.ascension) {
        const carrier = {
          id: 'player',
          position: this.player.position,
          velocity: this.player.velocity,
          radius: 0.7,
          applyAscensionDebuff: (d: { durationSec: number; moveSpeedMultiplier: number }) => {
            this.player?.debuffs.apply({
              id: 'slow',
              duration: d.durationSec,
              moveSpeedMult: d.moveSpeedMultiplier,
            });
          },
        };
        if (snap.moveY > 0.4 || snap.lightPressed) {
          if (this.ascension.attemptPickup(carrier)) playSfx(this.sfx, 'orbPickup');
        }
        if (snap.heavyPressed && (this.ascension.state === 'carried' || this.ascension.state === 'charging' || this.ascension.state === 'charged')) {
          this.ascension.drop('player_drop');
        }
        this.ascension.update(dt);

        // Emissive cel glow trail while the orb is on the player: pulse rings
        // faster and larger once fully charged so the deliver window reads.
        const orbHeld =
          this.ascension.state === 'carried' ||
          this.ascension.state === 'charging' ||
          this.ascension.state === 'charged';
        if (orbHeld) {
          this.orbGlowTimer -= dt;
          if (this.orbGlowTimer <= 0) {
            const charged = this.ascension.state === 'charged';
            this.orbGlowTimer = charged ? 0.22 : 0.34;
            this.vfx.spawnOrbGlow(this.ascension.position.clone(), {
              color: this.boss.identity.accentColor,
              secondaryColor: this.boss.identity.secondaryColor,
              scale: charged ? 1.5 : 1.1,
            });
          }
        } else {
          this.orbGlowTimer = 0;
        }

        if (this.run.world === 2 && this.arena.portals.length > 0 && this.ascension.state === 'carried') {
          for (const p of this.arena.portals) {
            if (Math.hypot(this.player.position.x - p.position.x, this.player.position.y - p.position.y) < 1.4) {
              const outcome = p.id === this.arena.correctPortalId ? 'right_portal' : 'wrong_portal';
              this.ascension.applyPortalChargeOutcome(outcome, carrier);
              this.vfx.spawnPortalSwirl(new THREE.Vector3(p.position.x, p.position.y, 0));
              break;
            }
          }
        }
      }

      if (this.encounter) {
        const enc = this.encounter.update(dt, this.player.position);
        for (const contact of enc.contacts) {
          this.applyPlayerDamage(contact.damage, 'enemy', {
            fromX: contact.enemy.root.position.x,
            strength: contact.knockback,
          });
        }
        for (const death of enc.deaths) onKill(this.run, { elite: death.elite });
        for (const proj of enc.projectiles) {
          proj.spec.speed *= this.currentCouncilMods.enemyProjectileSpeedMult;
          this.projectilePatternSerial += 1;
          this.projectiles.spawnPattern(
            proj.spec,
            proj.origin,
            proj.aim,
            this.run.rng('boss_projectiles', this.projectilePatternSerial),
          );
        }
      }
    }

    this.resolveProjectileHits();
    const bossFocus = this.run.phase === 'boss_fight' ? this.getBossFocus() : null;
    // Lean the frame further onto the boss during the DPS window: that is when
    // its core, shield state, and tells are what the player must be reading.
    const dpsBias = this.boss?.state === 'DPS_WINDOW' ? 0.55 : 0.42;
    this.cameraRig.update(
      dt,
      this.player.position,
      this.run.world,
      this.arena.bounds,
      bossFocus,
      dpsBias,
      this.getBossHalfHeight(),
    );

    if (!this.player.health.alive) this.onPlayerDeath();
  }

  /** Ticks every live swing: hitboxes persist for event.duration, hitting each target once. */
  private updateActiveAttacks(dt: number): void {
    for (let i = this.activeAttacks.length - 1; i >= 0; i--) {
      const attack = this.activeAttacks[i]!;
      this.resolvePlayerAttack(attack);
      attack.remaining -= dt;
      if (attack.remaining <= 0) this.activeAttacks.splice(i, 1);
    }
  }

  private triggerHitStop(seconds: number): void {
    this.hitStopRemaining = Math.max(this.hitStopRemaining, seconds);
  }

  private handlePlayerCombatEvent(atk: PlayerCombatEvent): void {
    if (atk.kind === 'arcane_bolt') {
      this.spawnMageBolt(atk);
      this.vfx.spawnOrbGlow(atk.origin.clone().add(new THREE.Vector3(atk.facing * 0.45, 0.95, 0)), {
        color: '#9b7cff',
        secondaryColor: '#5cf4ff',
        lifetime: 0.24,
        scale: 0.55,
      });
      playSfx(this.sfx, 'arcaneBolt');
      return;
    }

    if (atk.kind === 'frost_nova') {
      this.vfx.spawnPerfectDodgeFlashRing(atk.origin, {
        color: '#8de7ff',
        secondaryColor: '#e9fbff',
        lifetime: 0.48,
        scale: 2.35,
      });
      this.vfx.spawnFrostSpikes(atk.origin, { color: '#9deaff', scale: 2.1 });
      playSfx(this.sfx, 'frostNova');
    } else if (atk.kind === 'ultimate_storm') {
      this.vfx.spawnGroundTelegraph(atk.origin, {
        color: '#8b5cff',
        duration: atk.duration,
        radius: 3.4,
      });
      this.vfx.spawnPortalSwirl(atk.origin.clone().add(new THREE.Vector3(0, 1.8, 0)), {
        color: '#a276ff',
        secondaryColor: '#54edff',
        lifetime: 0.95,
        scale: 2.2,
      });
      playSfx(this.sfx, 'arcaneStorm');
    } else if (atk.kind === 'defend') {
      const mageBarrier = atk.classId === 'mage';
      this.vfx.spawnShieldBubble(atk.origin, mageBarrier
        ? { color: '#8b67ff', secondaryColor: '#6df1ff', lifetime: 0.9, scale: 1.15 }
        : {});
      playSfx(this.sfx, mageBarrier ? 'arcaneBarrier' : 'combatHit');
    } else {
      this.vfx.spawnAttackArc(atk.origin, atk.facing);
      playSfx(this.sfx, 'combatHit');
    }

    if (atk.damage <= 0) return;
    this.activeAttacks.push({
      event: atk,
      remaining: Math.max(atk.duration, 1 / 60),
      hitEnemies: new Set<EnemyBase>(),
      hitBoss: false,
    });
  }

  private spawnMageBolt(atk: PlayerCombatEvent): void {
    const origin = atk.origin.clone().add(new THREE.Vector3(atk.facing * 0.48, 0.92, 0));
    this.projectiles.spawn({
      origin,
      direction: new THREE.Vector3(atk.facing, 0, 0),
      speed: 10.5,
      lifetime: 0.62,
      radius: 0.22,
      scale: 1.25,
      color: '#9b7cff',
      payload: {
        owner: 'player',
        damage: atk.damage,
        knockback: atk.knockback,
        crit: atk.crit,
        elemental: atk.elemental,
        sourcePosition: atk.origin.clone(),
      },
    });
  }

  private resolvePlayerAttack(attack: ActiveAttackInstance): void {
    const atk = attack.event;
    if (atk.damage <= 0) return;
    const amount = atk.damage * this.relics.getDamageMultiplier() * this.currentCouncilMods.enemyDamageTakenMult;

    if (this.encounter) {
      for (const enemy of this.encounter.enemies) {
        if (!enemy.alive || attack.hitEnemies.has(enemy)) continue;
        const ep = enemy.root.position;
        if (aabbOverlap(atk.hitbox.x, atk.hitbox.y, atk.hitbox.w, atk.hitbox.h, ep.x - 0.35, ep.y, 0.7, 1.6)) {
          const result = enemy.takeDamage({
            amount,
            source: 'player',
            type: atk.kind === 'frost_nova' ? 'status' : atk.kind === 'ultimate_storm' ? 'ranged' : 'melee',
            crit: atk.crit,
            knockback: atk.knockback,
            sourcePosition: atk.origin,
            status: atk.kind === 'frost_nova' ? 'chill' : undefined,
            statusDuration: atk.kind === 'frost_nova' ? 3.5 : undefined,
          });
          if (result.applied > 0) {
            attack.hitEnemies.add(enemy);
            this.triggerHitStop(atk.crit ? HIT_STOP_CRIT_SEC : HIT_STOP_NORMAL_SEC);
            onDamageDealt(this.run, result.applied);
            this.damageNumbers.spawn(result.applied, ep.clone().add(new THREE.Vector3(0, 1.6, 0)), {
              crit: atk.crit,
            });
            if (atk.crit) this.vfx.spawnCritStars(ep);
            if (atk.elemental === 'frost' || (atk.elemental === 'none' && this.run.world === 1)) {
              this.vfx.spawnFrostSpikes(ep);
            }
            if (atk.elemental === 'void' || (atk.elemental === 'none' && this.run.world === 3)) {
              this.vfx.spawnElectricArc(atk.origin, ep, { color: '#a276ff', secondaryColor: '#5cf4ff' });
            }
          }
        }
      }
    }

    if (!attack.hitBoss && this.boss && this.bossVisual && this.run.phase === 'boss_fight') {
      const bp = this.bossVisual.position;
      if (aabbOverlap(atk.hitbox.x, atk.hitbox.y, atk.hitbox.w, atk.hitbox.h, bp.x - 1.1, bp.y, 2.2, 4.2)) {
        const result = this.boss.takeDamage({
          amount,
          source: 'player',
          crit: atk.crit,
        });
        if (result.appliedAmount > 0) {
          attack.hitBoss = true;
          this.triggerHitStop(atk.crit ? HIT_STOP_CRIT_SEC : HIT_STOP_NORMAL_SEC);
          onDamageDealt(this.run, result.appliedAmount);
          this.damageNumbers.spawn(result.appliedAmount, bp.clone().add(new THREE.Vector3(0, 3, 0)), {
            crit: atk.crit,
          });
          bus.emit(Events.SCREEN_SHAKE, { intensity: 0.15, duration: 0.12 });
        }
      }
    }
  }

  /**
   * Drives MusicBeds.setIntensity from live combat pressure: enemy count in
   * regular encounters, encounter state (DPS window / phase gate) on boss floors.
   */
  private updateMusicIntensity(dt: number): void {
    this.musicIntensityTimer -= dt;
    if (this.musicIntensityTimer > 0) return;
    this.musicIntensityTimer = 0.25;

    let intensity = 0.2;
    if (this.run.phase === 'boss_fight' && this.boss) {
      if (this.boss.state === 'DPS_WINDOW') intensity = 1;
      else if (this.boss.state === 'PHASE_GATE') intensity = 0.85;
      else intensity = 0.55;
      intensity = Math.min(1, intensity + Math.min(0.15, (this.encounter?.aliveCount ?? 0) * 0.03));
    } else if (this.run.phase === 'combat') {
      intensity = Math.min(0.9, 0.3 + (this.encounter?.aliveCount ?? 0) * 0.12);
    } else if (this.run.phase === 'chest') {
      intensity = 0.15;
    }
    this.music.setIntensity(intensity);
  }

  private resolveProjectileHits(): void {
    if (!this.player) return;
    for (const p of this.projectiles.snapshots()) {
      if (p.payload.owner === 'player') {
        this.resolvePlayerProjectileHit(p);
        continue;
      }
      if (this.player.position.distanceTo(p.position) < 0.55 + p.radius) {
        this.applyPlayerDamage(p.payload.damage, p.payload.owner === 'boss' ? 'boss' : 'enemy');
        this.projectiles.deactivate(p.id);
      }
    }
  }

  private resolvePlayerProjectileHit(projectile: ProjectileSnapshot): void {
    const amount =
      projectile.payload.damage *
      this.relics.getDamageMultiplier() *
      this.currentCouncilMods.enemyDamageTakenMult;
    const crit = projectile.payload.crit ?? false;

    if (this.encounter) {
      for (const enemy of this.encounter.enemies) {
        if (!enemy.alive) continue;
        const target = enemy.root.position.clone().add(new THREE.Vector3(0, 0.8, 0));
        const hitRadius = projectile.radius + 0.58;
        if (pointSegmentDistanceSq(target, projectile.previousPosition, projectile.position) > hitRadius * hitRadius) continue;
        const result = enemy.takeDamage({
          amount,
          source: 'player',
          type: 'projectile',
          crit,
          knockback: projectile.payload.knockback,
          sourcePosition: projectile.payload.sourcePosition ?? projectile.previousPosition,
          status: projectile.payload.status,
          statusDuration: projectile.payload.status === undefined ? undefined : 3,
        });
        this.projectiles.deactivate(projectile.id);
        if (result.applied > 0) {
          playSfx(this.sfx, 'combatHit');
          onDamageDealt(this.run, result.applied);
          this.triggerHitStop(crit ? HIT_STOP_CRIT_SEC : 0.025);
          this.damageNumbers.spawn(result.applied, target.clone().add(new THREE.Vector3(0, 0.8, 0)), { crit });
          this.vfx.spawnImpactShards(target, projectile.position.x >= projectile.previousPosition.x ? 0 : Math.PI, {
            color: '#a276ff',
            secondaryColor: '#5cf4ff',
          });
          if (crit) this.vfx.spawnCritStars(target);
        }
        return;
      }
    }

    if (this.boss && this.bossVisual && this.run.phase === 'boss_fight') {
      const target = this.bossVisual.position.clone().add(new THREE.Vector3(0, 2.1, 0));
      const hitRadius = projectile.radius + 1.45;
      if (pointSegmentDistanceSq(target, projectile.previousPosition, projectile.position) <= hitRadius * hitRadius) {
        const result = this.boss.takeDamage({ amount, source: 'player', crit });
        this.projectiles.deactivate(projectile.id);
        if (result.appliedAmount > 0) {
          playSfx(this.sfx, 'combatHit');
          onDamageDealt(this.run, result.appliedAmount);
          this.triggerHitStop(crit ? HIT_STOP_CRIT_SEC : 0.025);
          this.damageNumbers.spawn(result.appliedAmount, target, { crit });
          this.vfx.spawnImpactShards(target, projectile.position.x >= projectile.previousPosition.x ? 0 : Math.PI, {
            color: '#a276ff',
            secondaryColor: '#5cf4ff',
          });
          if (crit) this.vfx.spawnCritStars(target);
        }
      }
    }
  }

  private applyPlayerDamage(
    amount: number,
    source: 'enemy' | 'boss' | 'hazard',
    knockback?: { fromX: number; strength: number },
  ): void {
    if (!this.player) return;
    const result = this.player.takeDamage({
      amount: amount * this.relics.getIncomingDamageMultiplier(),
      source,
      crit: false,
    });
    if (result.dodged) return;
    if (result.applied > 0) {
      playSfx(this.sfx, 'combatHit');
      if (knockback) this.player.applyKnockback(knockback.fromX, knockback.strength);
    }
  }

  /** Frost stasis (roll 5): chill enemies in the halo around the player. */
  private applyCouncilEnemySlow(radius: number, duration: number): void {
    if (!this.encounter || !this.player) return;
    for (const enemy of this.encounter.enemies) {
      if (!enemy.alive) continue;
      if (enemy.root.position.distanceTo(this.player.position) > radius) continue;
      enemy.statuses.apply({ id: 'chill', duration, sourceId: 'council_frost_stasis' });
    }
  }

  /** Mirror prosecutor (roll 16): fragile shades join the fight mid-encounter. */
  private spawnCouncilMirrorShades(count: number, hpMult: number): void {
    if (!this.arena || !this.player) return;
    if (this.run.phase !== 'combat' && this.run.phase !== 'boss_fight') return;
    if (!this.encounter) {
      this.encounter = new EncounterController(this.run, this.arena);
      this.worldRoot.add(this.encounter.root);
    }
    const shades = this.encounter.spawnFragileShades(count, hpMult, this.player.position);
    for (const shade of shades) {
      this.vfx.spawnPerfectDodgeFlashRing(shade.root.position.clone().add(new THREE.Vector3(0, 1, 0)), {
        color: '#b48cff',
        secondaryColor: '#ffffff',
        scale: 1.2,
      });
    }
  }

  private applyCouncilHazardDamage(amount: number): number {
    if (!this.player || !this.player.health.alive || this.player.health.hp <= 1) return 0;
    const capped = Math.min(8, Math.max(0, amount), this.player.health.hp - 1);
    if (capped <= 0) return 0;
    const result = this.player.health.takeDamage({
      amount: capped,
      source: 'hazard',
      crit: false,
      elemental: 'fate',
    });
    if (result.applied > 0) playSfx(this.sfx, 'combatHit');
    return result.applied;
  }

  private onPlayerDeath(): void {
    this.playing = false;
    this.run.phase = 'death';
    playSfx(this.sfx, 'death');
    this.clearUi();
    this.syncHudVisibility();
    this.deathUi = new DeathScreen({
      root: this.uiRoot,
      stats: {
        world: this.run.world,
        floor: this.run.floor,
        runTimeSeconds: this.run.runElapsed,
        kills: this.run.kills,
        lastRoll: this.run.lastRoll,
      },
      onRetry: () => this.startRun(this.run.classId, (this.run.runSeed + 1) >>> 0),
      onMainMenu: () => this.showMainMenu(),
    });
  }

  private buildHudState(): HudState {
    const p = this.player;
    const classDef = getClassDef(p?.run.classId ?? this.run.classId);
    const cast = this.boss?.getCastBar();
    const active = getActiveEvent();
    return {
      hp: p?.health.hp ?? 100,
      maxHp: p?.health.maxHp ?? 100,
      shield: p?.buffs.has('knight_shield') || p?.buffs.has('mage_arcane_barrier') || p?.buffs.has('council_barrier') ? 20 : 0,
      maxShield: 20,
      ultimateRemaining: p?.combat.ultimateCooldownRemaining ?? 0,
      ultimateDuration: p?.combat.stats.ultimateCooldown ?? 25,
      ultimateLabel: classDef.abilities.ultimate,
      abilities: [
        { id: 'light', label: classDef.abilities.light, remaining: 0, duration: 1 },
        { id: 'heavy', label: classDef.abilities.heavy, remaining: 0, duration: 1 },
        {
          id: 'defend',
          label: classDef.abilities.defend,
          remaining: p?.combat.defendCooldownRemaining ?? 0,
          duration: p?.combat.stats.defendCooldown ?? 14,
        },
      ],
      dodgeCharges: Array.from({ length: p?.stats.maxDashCharges ?? 2 }, (_, i) => ({
        ready: (p?.dashChargeCount ?? 2) > i,
        remaining: (p?.dashChargeCount ?? 2) > i ? 0 : (p?.stats.dashRechargeTime ?? 3.5) * 0.5,
        duration: p?.stats.dashRechargeTime ?? 3.5,
      })),
      boss: {
        visible: !!this.boss && (this.run.phase === 'boss_fight' || this.run.phase === 'boss_intro'),
        name: this.boss?.identity.displayName ?? '',
        hp: this.boss?.hp ?? 0,
        maxHp: this.boss?.identity.maxHp ?? 1,
        castName: cast?.name,
        castProgress: cast?.progress,
        castRemaining: cast ? cast.durationSec - cast.elapsedSec : undefined,
      },
      floor: {
        world: this.run.world,
        floor: this.run.floor,
        status: formatPhaseLabel(this.run.phase),
        enemiesRemaining: this.run.enemiesRemaining,
        fastClearRemaining: Math.max(0, getFastClearSeconds(this.run) - this.run.floorElapsed),
      },
      dice: {
        min: this.run.dice.min,
        max: this.run.dice.max,
        lastRoll: this.run.lastRoll,
        meterCharge: this.run.diceMeter,
        activeEffect: active?.event.name,
        eventBanner: active?.event.name,
      },
      minimap: [1, 2, 3, 4, 5].map((f) => ({
        label: f === 5 ? 'B' : String(f),
        status:
          f < this.run.floor
            ? 'cleared'
            : f === this.run.floor
              ? f === 5
                ? 'boss'
                : 'current'
              : f === 5
                ? 'boss'
                : 'locked',
      })),
    };
  }

  private render(): void {
    this.post.render(this.scene, this.cameraRig.camera);
  }

  private exposeDebugApi(): void {
    window.__ALEARIS__ = {
      ready: true,
      version: '1.0.0',
      getPhase: () => this.run.phase,
      getRunSnapshot: () => ({
        phase: this.run.phase,
        world: this.run.world,
        floor: this.run.floor,
        diceMin: this.run.dice.min,
        diceMax: this.run.dice.max,
        lastRoll: this.run.lastRoll,
        meter: this.run.diceMeter,
        classId: this.run.classId,
        seed: this.run.runSeed,
        relics: this.run.relics.map((r) => r.id),
        modifiers: this.run.worldModifiers.map((m) => m.id),
        enemies: this.run.enemiesRemaining,
        bossHp: this.boss?.hp ?? null,
        bossState: this.boss?.state ?? null,
      }),
      getPlayerState: () => {
        if (!this.player) return null;
        return {
          x: this.player.position.x,
          y: this.player.position.y,
          grounded: this.player.grounded,
          classId: this.run.classId,
          hp: this.player.health.hp,
          alive: this.player.health.alive,
          jumpedLastFrame: this.playerJumpedLastFrame,
        };
      },
      getRunTelemetry: () => ({
        phase: this.run.phase,
        kills: this.run.kills,
        floor: this.run.floor,
        world: this.run.world,
        classId: this.run.classId,
        enemyAlive: this.encounter?.aliveCount ?? 0,
      }),
      startRun: (classId = 'knight', seed) => this.startRun(classId, seed),
      setScenario: async (scenario) => {
        await this.applyScenario(scenario);
      },
    };
  }

  async applyScenario(scenario: HarnessScenario): Promise<void> {
    await this.assetPreload;
    switch (scenario) {
      case 'menu':
        this.showMainMenu();
        break;
      case 'character_select':
        this.showCharacterSelect();
        break;
      case 'combat':
        this.startRun('knight', 0xa1ea215);
        break;
      case 'mage_combat':
        this.startRun('mage', 0x0a6e001);
        if (this.player) {
          const barrier = this.player.combat.requestDefend(this.player.position, this.player.facing);
          if (barrier) this.handlePlayerCombatEvent(barrier);
          const storm = this.player.combat.requestUltimate(this.player.position, this.player.facing);
          if (storm) this.handlePlayerCombatEvent(storm);
        }
        break;
      case 'modifier_choice':
        this.startRun('knight', 0xa1ea215);
        this.encounter?.clear();
        this.run.enemiesRemaining = 0;
        this.progression.markCombatCleared();
        this.progression.claimChest();
        this.showModifierChoice();
        break;
      case 'dice_roll_ui':
        this.startRun('rogue', 0xd1ce001);
        this.run.diceMeter = 100;
        tryInvoke(this.run);
        break;
      case 'orb_carry':
        this.startRun('knight', 0x0b05501);
        this.run.world = 1;
        this.run.floor = 5;
        this.loadFloor();
        this.bossIntroTimer = 0;
        this.cameraRig.skipCinematic();
        this.progression.beginCombat();
        if (this.player && this.ascension) {
          this.ascension.pickup({
            id: 'player',
            position: this.player.position,
            velocity: this.player.velocity,
            radius: 0.7,
          });
        }
        if (this.player && this.bossVisual && this.arena) {
          for (let i = 0; i < 20; i++) {
            this.cameraRig.update(
              0.05,
              this.player.position,
              this.run.world,
              this.arena.bounds,
              this.getBossFocus(),
              0.45,
              this.getBossHalfHeight(),
            );
          }
        }
        break;
      case 'dps_window':
        await this.applyScenario('orb_carry');
        if (this.ascension && this.player && this.boss && this.bossVisual) {
          this.ascension.forceChargeComplete({
            id: 'player',
            position: this.player.position,
            velocity: this.player.velocity,
            radius: 0.7,
          });
          this.player.teleportTo({
            x: this.ascension.socket.position.x,
            y: this.ascension.socket.position.y,
          });
          this.livePlayerPos.copy(this.player.position);
          this.ascension.deliverIfReady();
          // Prove DPS window: chip the boss and frame both actors
          this.boss.takeDamage({ amount: this.boss.identity.maxHp * 0.22, source: 'player', crit: false });
          this.cameraRig.skipCinematic();
          for (let i = 0; i < 24; i++) {
            this.cameraRig.update(
              0.05,
              this.player.position,
              this.run.world,
              this.arena?.bounds,
              this.getBossFocus(),
              0.55,
              this.getBossHalfHeight(),
            );
          }
        }
        break;
      case 'final_boss':
        this.startRun('knight', 0xf1fa100);
        this.run.world = 4 as WorldId;
        this.run.floor = 1;
        this.run.finalBossId = 'e';
        this.loadFloor();
        this.bossIntroTimer = 0;
        this.cameraRig.skipCinematic();
        this.progression.beginCombat();
        if (this.player && this.bossVisual && this.arena) {
          this.player.teleportTo({
            x: (this.player.position.x + this.bossVisual.position.x) * 0.5,
            y: Math.max(this.player.position.y, this.bossVisual.position.y - 1.5),
          });
          for (let i = 0; i < 24; i++) {
            this.cameraRig.update(
              0.05,
              this.player.position,
              this.run.world,
              this.arena.bounds,
              this.getBossFocus(),
              0.5,
              this.getBossHalfHeight(),
            );
          }
        }
        break;
      case 'victory':
        this.startRun('knight', 0xc1ea000);
        this.run.recordClear(600);
        this.run.phase = 'victory';
        this.playing = false;
        this.clearUi();
        this.syncHudVisibility();
        this.deathUi = new DeathScreen({
          root: this.uiRoot,
          variant: 'victory',
          kicker: 'Run Complete',
          title: 'Edict Fulfilled',
          cause: 'Edict Fulfilled',
          stats: {
            world: 4,
            floor: 1,
            runTimeSeconds: 600,
            kills: 99,
            lastRoll: 14,
          },
          onRetry: () => this.showCharacterSelect(),
          onMainMenu: () => this.showMainMenu(),
        });
        break;
      case 'death':
        this.startRun('rogue', 0xdead01);
        this.onPlayerDeath();
        break;
    }
    await new Promise((r) => setTimeout(r, 150));
  }
}

function formatPhaseLabel(phase: GamePhase): string {
  switch (phase) {
    case 'combat':
      return 'COMBAT';
    case 'boss_fight':
      return 'BOSS FIGHT';
    case 'boss_intro':
      return 'BOSS REVEAL';
    case 'chest':
      return 'SPOILS';
    case 'modifier_choice':
      return 'COUNCIL BARGAIN';
    case 'victory_roll':
      return 'VICTORY ROLL';
    case 'relic_choice':
      return 'RELIC OFFERING';
    case 'floor_intro':
      return 'ASCENT';
    case 'world_transition':
      return 'WORLD GATE';
    case 'pause':
      return 'PAUSED';
    case 'death':
      return 'FALLEN';
    case 'victory':
      return 'EDICT FULFILLED';
    default:
      return phase.replace(/_/g, ' ').toUpperCase();
  }
}
