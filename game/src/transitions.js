// Classic circle ("iris") transitions: the screen closes into a circle around a point, or opens out of one.
// Drawn as a very thick black ring around a hole, so it works the same on every renderer.
export function iris(scene, { x, y, open, ms = 600, onDone }) {
    const { width: w, height: h } = scene.scale;
    const far = Math.hypot(Math.max(x, w - x), Math.max(y, h - y)) + 20; // reaches every corner
    const g = scene.add.graphics().setScrollFactor(0).setDepth(1000);
    const state = { r: open ? 0 : far };
    const draw = () => {
        const thick = far - state.r + 40;
        g.clear().lineStyle(thick, 0x000000, 1).strokeCircle(x, y, state.r + thick / 2);
    };
    draw();
    scene.tweens.add({
        targets: state, r: open ? far : 0, duration: ms, ease: open ? 'Cubic.easeOut' : 'Cubic.easeIn',
        onUpdate: draw,
        onComplete: () => {
            if (open) g.destroy();
            onDone?.(g);
        },
    });
    return g;
}

// a short buzz on phones that support it (can be switched off in settings)
export function buzz(scene, ms) {
    if (scene.registry.get('save')?.vibration === false) return;
    try {
        navigator.vibrate?.(ms);
    } catch {
        // not available: no problem
    }
}
