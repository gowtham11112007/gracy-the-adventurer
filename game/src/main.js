import * as Phaser from 'phaser';
import '@fontsource/press-start-2p';
import Boot from './scenes/Boot.js';
import Title from './scenes/Title.js';
import Level from './scenes/Level.js';
import Hud from './scenes/Hud.js';
import Story from './scenes/Story.js';
import WorldMap from './scenes/WorldMap.js';
import Lobby from './scenes/Lobby.js';
import { unlockAudioOnTouch } from './audio.js';
import { checkForUpdate, showRetired } from './updater.js';
import { music } from './music.js';
import { WIDTH, HEIGHT, PHYSICS, NAMES } from './config.js';

const config = {
    type: Phaser.AUTO,
    title: NAMES.game,
    parent: 'game',
    backgroundColor: '#1d1230',
    // 1280x720, stretched sideways (never cropped) to fill wide phone screens
    scale: { mode: Phaser.Scale.EXPAND, width: WIDTH, height: HEIGHT, autoCenter: Phaser.Scale.CENTER_BOTH },
    // physics steps with the screen's own refresh rate, so motion stays smooth on 90/120 Hz phones
    physics: { default: 'arcade', arcade: { gravity: { y: PHYSICS.gravity }, fixedStep: false, debug: false } },
    input: { activePointers: 3 }, // move and jump at the same time
    scene: [Boot, Title, WorldMap, Story, Lobby, Level, Hud],
};

// A retired copy of the game only shows a black screen (it never checks for updates again)
if (__RETIRED__) showRetired();
// wait for the pixel font so text isn't first drawn in a fallback font
else document.fonts.load('20px "Press Start 2P"').finally(() => {
    const game = new Phaser.Game(config);
    unlockAudioOnTouch();
    checkForUpdate();
    // quiet the music when the app goes to the background
    game.events.on('hidden', () => music.pause());
    game.events.on('visible', () => music.resume());
    if (import.meta.env.DEV) window.game = game; // handy for testing in the browser console
});
