import { Game } from './Game';

const game = new Game();

// Keep a handle for HMR / harness inspection
(window as unknown as { __game?: Game }).__game = game;
