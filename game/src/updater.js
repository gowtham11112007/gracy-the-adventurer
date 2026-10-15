// Online updates: new levels and fixes download quietly while she plays,
// and the app switches to them the next time it's opened. Progress is never touched.
// Only runs inside the Android app; offline it simply keeps the version it has.
import { CapacitorUpdater } from '@capgo/capacitor-updater';
import { VERSION, UPDATE_URL } from './config.js';

// "1.0.29340012" is newer than "1.0.29339000"
const newer = (a, b) => {
    const pa = a.split('.').map(Number);
    const pb = b.split('.').map(Number);
    for (let i = 0; i < 3; i++) if ((pa[i] || 0) !== (pb[i] || 0)) return (pa[i] || 0) > (pb[i] || 0);
    return false;
};

// what the updater is doing, shown on the Credits screen so problems can be seen on the phone itself
export let updateStatus = 'not checked yet';
const status = (text) => { updateStatus = text; };

export async function checkForUpdate() {
    if (!window.Capacitor?.isNativePlatform?.()) return status('browser: no updates');
    // this version started fine (a broken update would be rolled back); not awaited, so it can never hold up the check
    CapacitorUpdater.notifyAppReady().catch((e) => status(`ready failed: ${e?.message || e}`));
    try {
        status('checking...');
        const res = await fetch(`${UPDATE_URL}?t=${Date.now()}`, { cache: 'no-store' });
        if (!res.ok) return status(`check failed: ${res.status}`);
        const latest = await res.json();
        if (!newer(latest.version, VERSION)) return status('up to date');
        status(`downloading ${latest.version}...`);
        const bundle = await CapacitorUpdater.download({ url: latest.url, version: latest.version });
        await CapacitorUpdater.next({ id: bundle.id });
        status(`${latest.version} ready: close and reopen`); // switches over when the app goes to the background
    } catch (e) {
        status(`failed: ${String(e?.message || e).slice(0, 60)}`);
    }
}

// A retired copy shows only a black screen. It still tells the updater it started fine,
// otherwise the phone would roll back to the previous (playable) version.
export function showRetired() {
    document.getElementById('rotate')?.remove();
    document.getElementById('game').innerHTML = '<div style="position:fixed;inset:0;background:#000"></div>';
    document.body.style.background = '#000';
    if (window.Capacitor?.isNativePlatform?.()) CapacitorUpdater.notifyAppReady().catch(() => {});
}
