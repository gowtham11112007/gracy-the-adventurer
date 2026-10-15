// relative paths so the built game also works inside the Android app.
// Every build gets its own version number (used by the online updater to spot newer versions).
const version = process.env.GAME_VERSION || `1.0.${Math.floor(Date.now() / 60000)}`;

export default {
    base: './',
    build: { chunkSizeWarningLimit: 2000 },
    define: {
        __GAME_VERSION__: JSON.stringify(version),
        // GAME_RETIRED=1 builds the "this version has ended" screen (see tools/release.mjs --retire-old)
        __RETIRED__: JSON.stringify(process.env.GAME_RETIRED === '1'),
    },
};
