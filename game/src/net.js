// Two-phone play over Supabase Realtime.
// A room is one channel named after its 4-digit code. Presence says who is in the room (and who is ready);
// broadcast carries the game messages. Each message is { t: type, d: data }.
import { createClient } from '@supabase/supabase-js';
import { SUPABASE } from './config.js';

let client = null;
const handlers = new Map();
const emit = (type, data) => handlers.get(type)?.forEach((fn) => fn(data));

export const net = {
    channel: null,
    code: null,
    me: null,        // 'janani' or 'janika'
    host: false,     // the phone that made the room runs the enemies
    ready: false,
    connected: false,

    // everyone in the room right now, me included: [{ id, me, host, ready }]
    people() {
        return this.channel ? Object.values(this.channel.presenceState()).map((list) => list[0]) : [];
    },
    partner() {
        return this.people().find((p) => p.id !== this.id) || null;
    },

    async open(code, me, host) {
        this.close();
        client ??= createClient(SUPABASE.url, SUPABASE.key, { realtime: { params: { eventsPerSecond: 30 } } });
        Object.assign(this, { code, me, host, ready: false, id: `${me}-${Math.random().toString(36).slice(2, 8)}` });
        const ch = client.channel(`gracy-bday-room-${code}`, { config: { broadcast: { self: false }, presence: { key: this.id } } });
        this.channel = ch;
        ch.on('presence', { event: 'sync' }, () => emit('presence', this.people()));
        ch.on('broadcast', { event: 'm' }, ({ payload }) => emit(payload.t, payload.d));
        await new Promise((resolve, reject) => {
            const timer = setTimeout(() => reject(new Error('no connection')), 10000);
            ch.subscribe((status) => {
                if (status === 'SUBSCRIBED') {
                    // also runs after the connection drops and comes back: say we're here again
                    clearTimeout(timer);
                    this.connected = true;
                    this.track();
                    emit('status', true);
                    resolve();
                } else {
                    this.connected = false;
                    emit('status', false);
                }
            });
        });
    },

    track() {
        this.channel?.track({ id: this.id, me: this.me, host: this.host, ready: this.ready });
    },

    setReady(ready) {
        this.ready = ready;
        this.track();
    },

    send(type, data = {}) {
        if (this.connected) this.channel.send({ type: 'broadcast', event: 'm', payload: { t: type, d: data } });
    },

    // listen for a message type; returns a function that stops listening
    on(type, fn) {
        if (!handlers.has(type)) handlers.set(type, new Set());
        handlers.get(type).add(fn);
        return () => handlers.get(type).delete(fn);
    },

    close() {
        if (this.channel) client.removeChannel(this.channel);
        this.channel = null;
        this.connected = false;
        this.code = null;
    },
};
