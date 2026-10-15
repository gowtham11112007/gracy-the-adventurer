// Progress is kept on the phone (localStorage): cleared levels, unlocked outfits, candles found.
const KEY = 'gracy-save-v1';

const fresh = () => ({ cleared: [], outfits: ['kurti'], outfit: 'kurti', candles: [], crystals: {}, music: true, sound: true, vibration: true, bigButtons: false,
    janikaOutfits: ['janika'], janikaOutfit: 'janika', coopCleared: [] });

export const freshSave = fresh;

export function loadSave() {
    try {
        return { ...fresh(), ...JSON.parse(localStorage.getItem(KEY) || '{}') };
    } catch {
        return fresh();
    }
}

export function writeSave(save) {
    try {
        localStorage.setItem(KEY, JSON.stringify(save));
    } catch {
        // storage can be unavailable (private mode); the game still plays
    }
}
