/**
 * W3-D: device WebSocket client for the host gateway.
 * Pure parsing/decoding/backoff live at the top; `createGatewayClient` is
 * the one impure edge (socket + timers injectable for tests).
 * @see docs/architecture/host-device-protocol-v1.md
 */

import type { ChannelV1, EnvelopeV1, IntentV1 } from "../protocol/envelope";
import { applyEnvelope, type ChannelStoreState } from "./channelStore";
import { buildIntent, encodeIntentFrame, refreshChannelRequest } from "./intents";

/**
 * Parse a `?gateway=` query value. Only absolute ws:// or wss:// URLs
 * connect; anything else (absent, empty, http, malformed) → null = the
 * fixture mode the shell has always booted with.
 */
export const parseGatewayUrl = (raw: string | null): string | null => {
  if (raw === null) {
    return null;
  }
  const trimmed = raw.trim();
  if (!/^wss?:\/\//i.test(trimmed)) {
    return null;
  }
  try {
    new URL(trimmed);
  } catch {
    return null;
  }
  return trimmed;
};

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null;

/**
 * Decode one inbound frame. Tolerant: non-string data, bad JSON, wrong
 * version, or malformed envelope fields → null (frame ignored, no throw).
 * Unknown channel strings pass through — `applyEnvelope` already drops
 * unmanaged channels. A null/absent payload is rejected here so a broken
 * host frame can never blank a screen (device keeps its last snapshot).
 */
export const decodeEnvelopeFrame = (data: unknown): EnvelopeV1 | null => {
  if (typeof data !== "string") {
    return null;
  }
  let parsed: unknown;
  try {
    parsed = JSON.parse(data);
  } catch {
    return null;
  }
  if (!isRecord(parsed)) {
    return null;
  }
  const { v, ts, channel, gen, payload } = parsed;
  if (v !== 1) {
    return null;
  }
  if (typeof ts !== "number" || !Number.isFinite(ts)) {
    return null;
  }
  if (typeof channel !== "string") {
    return null;
  }
  if (typeof gen !== "number" || !Number.isFinite(gen)) {
    return null;
  }
  if (!isRecord(payload)) {
    return null;
  }
  // Wire channel is any string; the store's managed-channel guard filters it.
  return { v: 1, ts, channel: channel as ChannelV1, gen, payload };
};

export type BackoffConfig = {
  readonly initialDelayMs: number;
  readonly factor: number;
  readonly maxDelayMs: number;
};

export const defaultBackoff: BackoffConfig = Object.freeze({
  initialDelayMs: 500,
  factor: 2,
  maxDelayMs: 15_000,
});

/** Pure, deterministic (no jitter): delay before reconnect `attempt` (0-based), capped. */
export const backoffDelayMs = (
  attempt: number,
  config: BackoffConfig = defaultBackoff,
): number =>
  Math.min(
    config.maxDelayMs,
    config.initialDelayMs * config.factor ** Math.max(0, attempt),
  );

export type ChannelFeed = {
  readonly current: () => ChannelStoreState;
  readonly push: (envelope: EnvelopeV1) => void;
};

/**
 * Fold gateway envelopes into channel-store state; `onChange` fires only
 * when a frame actually advanced a channel (stale-generation and
 * unknown-channel frames are absorbed by `applyEnvelope` unchanged).
 */
export const createChannelFeed = (
  initial: ChannelStoreState,
  onChange: (state: ChannelStoreState) => void,
): ChannelFeed => {
  let state = initial;
  return {
    current: () => state,
    push: (envelope) => {
      const next = applyEnvelope(state, envelope);
      if (next !== state) {
        state = next;
        onChange(next);
      }
    },
  };
};

/** Minimal socket surface (adapted real WebSocket, or a test fake). */
export type GatewaySocket = {
  send: (data: string) => void;
  close: () => void;
  onopen: (() => void) | null;
  onmessage: ((event: { readonly data: unknown }) => void) | null;
  onclose: (() => void) | null;
  onerror: (() => void) | null;
};

export type GatewayTimers = {
  readonly schedule: (fn: () => void, delayMs: number) => unknown;
  readonly cancel: (handle: unknown) => void;
};

export type GatewayClientOptions = {
  readonly url: string;
  /** Injectable socket factory (tests); defaults to a real `WebSocket`. */
  readonly createSocket?: (url: string) => GatewaySocket;
  readonly backoff?: BackoffConfig;
  /** Channels to `refresh_channel` on every successful open (recovers state missed while down). */
  readonly refreshOnOpen?: readonly ChannelV1[];
  readonly now?: () => number;
  readonly timers?: GatewayTimers;
};

export type GatewayClient = {
  readonly subscribe: (listener: (envelope: EnvelopeV1) => void) => () => void;
  /** True when the intent frame was handed to an open socket; false = dropped. */
  readonly sendIntent: (intent: IntentV1) => boolean;
  readonly dispose: () => void;
};

const adaptWebSocket = (url: string): GatewaySocket => {
  const socket = new WebSocket(url);
  const adapted: GatewaySocket = {
    send: (data) => socket.send(data),
    close: () => socket.close(),
    onopen: null,
    onmessage: null,
    onclose: null,
    onerror: null,
  };
  socket.onopen = () => adapted.onopen?.();
  socket.onmessage = (event) => adapted.onmessage?.({ data: event.data });
  socket.onclose = () => adapted.onclose?.();
  socket.onerror = () => adapted.onerror?.();
  return adapted;
};

const defaultTimers: GatewayTimers = {
  schedule: (fn, delayMs) => setTimeout(fn, delayMs),
  cancel: (handle) => clearTimeout(handle as ReturnType<typeof setTimeout>),
};

/**
 * Impure edge: one WS connection, decoded envelopes fanned out to
 * subscribers, deterministic bounded reconnect (delay capped, retries
 * unbounded — a kiosk keeps trying). Wire garbage never throws;
 * `dispose` ends the client for good.
 */
export const createGatewayClient = (
  options: GatewayClientOptions,
): GatewayClient => {
  const createSocket = options.createSocket ?? adaptWebSocket;
  const backoff = options.backoff ?? defaultBackoff;
  const refreshOnOpen = options.refreshOnOpen ?? [];
  const now = options.now ?? Date.now;
  const timers = options.timers ?? defaultTimers;

  const listeners = new Set<(envelope: EnvelopeV1) => void>();
  let socket: GatewaySocket | null = null;
  let open = false;
  let disposed = false;
  let attempt = 0;
  let reconnectHandle: unknown = null;

  const scheduleReconnect = () => {
    // One pending timer max — a socket firing both onerror and onclose
    // must not double-schedule.
    if (disposed || reconnectHandle !== null) {
      return;
    }
    const delay = backoffDelayMs(attempt, backoff);
    attempt += 1;
    reconnectHandle = timers.schedule(() => {
      reconnectHandle = null;
      connect();
    }, delay);
  };

  const sendIntent = (intent: IntentV1): boolean => {
    if (disposed || !open || socket === null) {
      return false;
    }
    try {
      socket.send(encodeIntentFrame(intent));
      return true;
    } catch {
      return false;
    }
  };

  const connect = () => {
    if (disposed) {
      return;
    }
    open = false;
    let next: GatewaySocket;
    try {
      next = createSocket(options.url);
    } catch {
      scheduleReconnect();
      return;
    }
    socket = next;
    // Events from superseded sockets are ignored via the `socket !== next` guard.
    next.onopen = () => {
      if (disposed || socket !== next) {
        return;
      }
      open = true;
      attempt = 0;
      for (const channel of refreshOnOpen) {
        sendIntent(buildIntent(refreshChannelRequest(channel), now()));
      }
    };
    next.onmessage = (event) => {
      if (disposed || socket !== next) {
        return;
      }
      const envelope = decodeEnvelopeFrame(event.data);
      if (envelope === null) {
        return;
      }
      for (const listener of listeners) {
        listener(envelope);
      }
    };
    const onGone = () => {
      if (disposed || socket !== next) {
        return;
      }
      open = false;
      scheduleReconnect();
    };
    next.onclose = onGone;
    next.onerror = onGone;
  };

  connect();

  return {
    subscribe: (listener) => {
      if (disposed) {
        return () => undefined;
      }
      listeners.add(listener);
      return () => {
        listeners.delete(listener);
      };
    },
    sendIntent,
    dispose: () => {
      if (disposed) {
        return;
      }
      disposed = true;
      if (reconnectHandle !== null) {
        timers.cancel(reconnectHandle);
        reconnectHandle = null;
      }
      listeners.clear();
      try {
        socket?.close();
      } catch {
        // Tolerant edge: a closing socket may already be gone.
      }
      socket = null;
      open = false;
    },
  };
};
