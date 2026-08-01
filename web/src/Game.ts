import * as THREE from 'three';
import { AudioEngine } from './audio/AudioEngine';
import { MusicBeds } from './audio/MusicBeds';
import { Sfx, type SfxName } from './audio/Sfx';
import { AscensionCharge } from './boss/AscensionCharge';
import { BossController } from './boss/BossController';
import {
  getFinalBossIdentity,
  getWorldBossIdentity,
  type BossIdentity,
} from './boss/BossIdentities';
import { ProjectilePoolAdapter } from './boss/BulletPatterns';
import { buildBossVisual, updateBossVisual } from './boss/BossVisual';
import { GameCamera } from './camera/GameCamera';
import { DamageNumberSystem } from './combat/DamageNumbers';
import { ProjectilePool } from './combat/Projectiles';
import { bus, Events } from './core/EventBus';
import { RunState } from './core/RunState';
import type { ClassId, GamePhase, WorldId } from './core/types';
import {
  getActiveEvent,
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
import type { CombatMods } from './dice/ModifierEffects';
import { perfBudget } from './performance/Budget';
import { PlayerInput } from './player/Input';
import { PlayerController } from './player/PlayerController';
import { getRelicById, type RelicDef } from './relics/RelicDatabase';
import { RelicEffects } from './relics/RelicEffects';
import { offerRelics } from './relics/relicOffer';
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
import { VfxSystem } from './vfx/VfxSystem';
import { buildArena, type Arena } from './world/ArenaBuilder';
import { EncounterController } from './world/EncounterController';
import { FloorProgression } from './world/FloorProgression';

export type HarnessScenario =
  | 'menu'
  | 'character_select'
  | 'combat'
  | 'orb_carry'
  | 'dps_window'
  | 'dice_roll_ui'
  | 'modifier_choice'
  | 'final_boss'
  | 'victory'
  | 'death';

export interface AlearisDebugApi {
  getPhase: () => GamePhase;
  getRunSnapshot: () => Record<string, unknown>;
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

function playSfx(sfx: Sfx, name: SfxName): void {
  sfx.play(name);
}

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
  readonly vfx = new VfxSystem();
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

  constructor() {
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

    this.scene.add(this.sky.mesh, this.worldRoot, this.vfx.root, this.projectiles.root, this.damageNumbers.root);
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
        this.startRun(classId);
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

  private loadFloor(): void {
    this.teardownFloor();
    this.progression.beginFloor();
    this.relics.onFloorStart();

    const rng = this.run.rng('layout', this.run.world * 50 + this.run.floor);
    this.arena = buildArena(this.run.world, this.run.floor, rng);
    this.worldRoot.add(this.arena.root);
    this.applyWorldVisuals(this.run.world);
    this.music.startWorld(this.run.world as 1 | 2 | 3 | 4);

    this.player = new PlayerController(this.run, this.arena.spawns.player);
    this.applyPlayerRelics();
    // PlayerController caps the composed gravity multiplier against the same
    // jump-clearance budget ArenaBuilder uses for platform step validation.
    this.player.setCouncilCombatMods(this.currentCouncilMods);
    this.worldRoot.add(this.player.root);

    if (this.run.isBossFloor()) {
      this.setupBoss();
      this.run.phase = 'boss_intro';
      this.bossIntroTimer = 2.2;
      this.cameraRig.startBossReveal(
        this.player.position,
        this.bossVisual?.position ?? new THREE.Vector3(0, 4, 0),
        2.2,
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
      onAddSpawn: () => {
        if (this.encounter || !this.arena) return;
        this.encounter = new EncounterController(this.run, this.arena);
        this.worldRoot.add(this.encounter.root);
        this.encounter.spawnInitialWave();
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
    const socket = this.arena.sockets[0] ?? { x: 6, y: 3 };
    this.bossVisual.position.set(socket.x - 2, socket.y + 1.5, 0);
    this.worldRoot.add(this.bossVisual);

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
      stations: stations.length > 0 ? stations : [{ id: 's0', position: new THREE.Vector3(0, 2, 0) }],
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
    if (this.player) this.worldRoot.remove(this.player.root);
    this.player = null;
    if (this.bossVisual) this.worldRoot.remove(this.bossVisual);
    this.bossVisual = null;
    this.boss = null;
    if (this.ascension) this.worldRoot.remove(this.ascension.group);
    this.ascension = null;
    if (this.arena) this.worldRoot.remove(this.arena.root);
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

  private applyWorldVisuals(world: number): void {
    const p = getPalette(world);
    this.sky.applyPalette(p);
    this.post.setWorld(world);
    this.ambient.color.copy(p.ambient);
    this.keyLight.color.copy(p.keyLight);
    this.fillLight.color.copy(p.fillLight);
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
    const dt = Math.min(0.05, this.clock.getDelta());
    this.time += dt;
    perfBudget.observeFrame(dt);
    if (Math.abs(this.renderer.getPixelRatio() - perfBudget.pixelRatio) > 0.01) {
      this.resize();
    }
    this.update(dt);
    this.render();
  };

  private update(dt: number): void {
    this.sky.update(this.time);
    this.vfx.update(dt);
    this.damageNumbers.update(dt);
    this.projectiles.update(dt);
    const activeEvent = updateDiceMeter(dt);
    this.currentCouncilMods = getCouncilCombatMods(activeEvent);
    this.player?.setCouncilCombatMods(this.currentCouncilMods);
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

    if (this.run.phase === 'boss_intro') {
      this.bossIntroTimer -= dt;
      this.cameraRig.update(dt, this.bossVisual?.position ?? this.player.position, this.run.world, this.arena.bounds);
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
        spawnHazardPulse: (position, radius) => this.vfx.spawnPerfectDodgeFlashRing(position, { color: '#ff5a72', secondaryColor: '#ffe080', scale: radius }),
        rng: this.run.rng('dice_meter', activeEvent.event.roll * 1000 + Math.floor(activeEvent.elapsed * 20)),
      });
    }

    for (const atk of frame.combatEvents) {
      this.vfx.spawnAttackArc(atk.origin, atk.facing);
      if (atk.kind === 'defend') this.vfx.spawnShieldBubble(atk.origin);
      playSfx(this.sfx, 'combatHit');
      this.resolvePlayerAttack(atk);
    }

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
        this.applyPlayerDamage(contact.damage, 'enemy');
      }
      for (const melee of enc.melee) {
        const dx = this.player.position.x - melee.origin.x;
        const dy = this.player.position.y + 0.9 - melee.origin.y;
        if (Math.hypot(dx, dy) <= melee.range + 0.3) {
          this.applyPlayerDamage(melee.damage, 'enemy');
        }
      }
      for (const proj of enc.projectiles) {
        proj.spec.speed *= this.currentCouncilMods.enemyProjectileSpeedMult;
        this.projectiles.spawnPattern(
          proj.spec,
          proj.origin,
          proj.aim,
          this.run.rng('boss_projectiles', 1),
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

        if (this.run.world === 2 && this.arena.portals.length > 0 && this.ascension.state === 'carried') {
          for (let i = 0; i < this.arena.portals.length; i++) {
            const p = this.arena.portals[i]!;
            if (Math.hypot(this.player.position.x - p.position.x, this.player.position.y - p.position.y) < 1.4) {
              this.ascension.applyPortalChargeOutcome(i % 2 === 0 ? 'right_portal' : 'wrong_portal', carrier);
              this.vfx.spawnPortalSwirl(new THREE.Vector3(p.position.x, p.position.y, 0));
              break;
            }
          }
        }
      }

      if (this.encounter) {
        const enc = this.encounter.update(dt, this.player.position);
        for (const contact of enc.contacts) this.applyPlayerDamage(contact.damage, 'enemy');
        for (const death of enc.deaths) onKill(this.run, { elite: death.elite });
        for (const proj of enc.projectiles) {
          proj.spec.speed *= this.currentCouncilMods.enemyProjectileSpeedMult;
          this.projectiles.spawnPattern(
            proj.spec,
            proj.origin,
            proj.aim,
            this.run.rng('boss_projectiles', 1),
          );
        }
      }
    }

    this.resolveProjectileHits();
    this.cameraRig.update(dt, this.player.position, this.run.world, this.arena.bounds);

    if (!this.player.health.alive) this.onPlayerDeath();
  }

  private resolvePlayerAttack(atk: {
    hitbox: { x: number; y: number; w: number; h: number };
    damage: number;
    crit: boolean;
    knockback: number;
    origin: THREE.Vector3;
  }): void {
    const amount = atk.damage * this.relics.getDamageMultiplier() * this.currentCouncilMods.enemyDamageTakenMult;

    if (this.encounter) {
      for (const enemy of this.encounter.enemies) {
        if (!enemy.alive) continue;
        const ep = enemy.root.position;
        if (aabbOverlap(atk.hitbox.x, atk.hitbox.y, atk.hitbox.w, atk.hitbox.h, ep.x - 0.35, ep.y, 0.7, 1.6)) {
          const result = enemy.takeDamage({
            amount,
            source: 'player',
            type: 'melee',
            crit: atk.crit,
            knockback: atk.knockback,
            sourcePosition: atk.origin,
          });
          if (result.applied > 0) {
            onDamageDealt(this.run, result.applied);
            this.damageNumbers.spawn(result.applied, ep.clone().add(new THREE.Vector3(0, 1.6, 0)), {
              crit: atk.crit,
            });
            if (atk.crit) this.vfx.spawnCritStars(ep);
            if (this.run.world === 1) this.vfx.spawnFrostSpikes(ep);
            if (this.run.world === 3) this.vfx.spawnElectricArc(atk.origin, ep);
          }
        }
      }
    }

    if (this.boss && this.bossVisual && this.run.phase === 'boss_fight') {
      const bp = this.bossVisual.position;
      if (aabbOverlap(atk.hitbox.x, atk.hitbox.y, atk.hitbox.w, atk.hitbox.h, bp.x - 1.1, bp.y, 2.2, 4.2)) {
        const result = this.boss.takeDamage({
          amount,
          source: 'player',
          crit: atk.crit,
        });
        if (result.appliedAmount > 0) {
          onDamageDealt(this.run, result.appliedAmount);
          this.damageNumbers.spawn(result.appliedAmount, bp.clone().add(new THREE.Vector3(0, 3, 0)), {
            crit: atk.crit,
          });
          bus.emit(Events.SCREEN_SHAKE, { intensity: 0.15, duration: 0.12 });
        }
      }
    }
  }

  private resolveProjectileHits(): void {
    if (!this.player) return;
    for (const p of this.projectiles.snapshots()) {
      if (p.payload.owner === 'player') continue;
      if (this.player.position.distanceTo(p.position) < 0.55 + p.radius) {
        this.applyPlayerDamage(p.payload.damage, p.payload.owner === 'boss' ? 'boss' : 'enemy');
        this.projectiles.deactivate(p.id);
      }
    }
  }

  private applyPlayerDamage(amount: number, source: 'enemy' | 'boss' | 'hazard'): void {
    if (!this.player) return;
    const result = this.player.takeDamage({
      amount: amount * this.relics.getIncomingDamageMultiplier(),
      source,
      crit: false,
    });
    if (result.dodged) return;
    if (result.applied > 0) playSfx(this.sfx, 'combatHit');
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
    const cast = this.boss?.getCastBar();
    const active = getActiveEvent();
    return {
      hp: p?.health.hp ?? 100,
      maxHp: p?.health.maxHp ?? 100,
      shield: p?.buffs.has('knight_shield') || p?.buffs.has('council_barrier') ? 20 : 0,
      maxShield: 20,
      ultimateRemaining: p?.combat.ultimateCooldownRemaining ?? 0,
      ultimateDuration: 60,
      abilities: [
        {
          id: 'defend',
          label: 'DEF',
          remaining: p?.combat.defendCooldownRemaining ?? 0,
          duration: 60,
        },
        { id: 'heavy', label: 'HVY', remaining: 0, duration: 1 },
      ],
      dodgeCharges: Array.from({ length: p?.stats.maxDashCharges ?? 2 }, (_, i) => ({
        ready: (p?.dashChargeCount ?? 2) > i,
        remaining: (p?.dashChargeCount ?? 2) > i ? 0 : 5,
        duration: 10,
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
        status: this.run.phase,
        enemiesRemaining: this.run.enemiesRemaining,
        fastClearRemaining: Math.max(0, 30 - this.run.floorElapsed),
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
      startRun: (classId = 'knight', seed) => this.startRun(classId, seed),
      setScenario: async (scenario) => {
        await this.applyScenario(scenario);
      },
    };
  }

  async applyScenario(scenario: HarnessScenario): Promise<void> {
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
        break;
      case 'dps_window':
        await this.applyScenario('orb_carry');
        if (this.ascension && this.player) {
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
          this.ascension.deliverIfReady();
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
