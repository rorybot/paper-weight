import { describe, expect, it } from "vitest";

import type { EnvelopeV1 } from "../protocol/envelope";
import { fixtureChannelStoreState } from "./channelStore";
import {
  backoffDelayMs,
  createChannelFeed,
  createGatewayClient,
  decodeEnvelopeFrame,
  parseGatewayUrl,
  type GatewaySocket,
} from "./gateway";
import { buildIntent, setVolumeRequest } from "./intents";

const envelopeFrame = (
  overrides: Partial<EnvelopeV1> &
    Pick<EnvelopeV1, "channel" | "gen" | "payload">,
): string => JSON.stringify({ v: 1, ts: 1721150000000, ...overrides });

describe("parseGatewayUrl", () => {
  it("accepts absolute ws:// and wss:// URLs and trims whitespace", () => {
    expect(parseGatewayUrl("ws://172.16.42.1:9138/ws")).toBe(
      "ws://172.16.42.1:9138/ws",
    );
    expect(parseGatewayUrl(" wss://host.local/gateway ")).toBe(
      "wss://host.local/gateway",
    );
  });

  it("rejects absent, empty, non-ws, and malformed values (fixture mode)", () => {
    expect(parseGatewayUrl(null)).toBeNull();
    expect(parseGatewayUrl("")).toBeNull();
    expect(parseGatewayUrl("http://host/ws")).toBeNull();
    expect(parseGatewayUrl("172.16.42.1:9138")).toBeNull();
    expect(parseGatewayUrl("ws://")).toBeNull();
  });
});

describe("decodeEnvelopeFrame", () => {
  it("decodes a valid envelope frame", () => {
    expect(
      decodeEnvelopeFrame(
        envelopeFrame({ channel: "weather", gen: 3, payload: { ok: true } }),
      ),
    ).toEqual({
      v: 1,
      ts: 1721150000000,
      channel: "weather",
      gen: 3,
      payload: { ok: true },
    });
  });

  it("passes unknown channel strings through (the store drops them)", () => {
    const decoded = decodeEnvelopeFrame(
      envelopeFrame({
        channel: "not-a-channel" as EnvelopeV1["channel"],
        gen: 1,
        payload: {},
      }),
    );
    expect(decoded?.channel).toBe("not-a-channel");
  });

  it("returns null for non-string data, bad JSON, and non-object frames", () => {
    expect(decodeEnvelopeFrame(new ArrayBuffer(4))).toBeNull();
    expect(decodeEnvelopeFrame(undefined)).toBeNull();
    expect(decodeEnvelopeFrame("{nope")).toBeNull();
    expect(decodeEnvelopeFrame("42")).toBeNull();
    expect(decodeEnvelopeFrame("[1,2]")).toBeNull();
  });

  it("returns null for wrong-version or malformed envelope fields", () => {
    const valid = {
      v: 1,
      ts: 1721150000000,
      channel: "weather",
      gen: 1,
      payload: {},
    };
    expect(decodeEnvelopeFrame(JSON.stringify({ ...valid, v: 2 }))).toBeNull();
    expect(
      decodeEnvelopeFrame(JSON.stringify({ ...valid, ts: "noon" })),
    ).toBeNull();
    expect(
      decodeEnvelopeFrame(JSON.stringify({ ...valid, channel: 7 })),
    ).toBeNull();
    expect(
      decodeEnvelopeFrame(JSON.stringify({ ...valid, gen: "3" })),
    ).toBeNull();
    expect(
      decodeEnvelopeFrame(JSON.stringify({ ...valid, payload: null })),
    ).toBeNull();
    expect(
      decodeEnvelopeFrame(
        JSON.stringify({ v: 1, ts: 1, channel: "weather", gen: 1 }),
      ),
    ).toBeNull();
  });
});

describe("backoffDelayMs", () => {
  it("doubles deterministically from 500ms and caps at 15s", () => {
    expect([0, 1, 2, 3, 4, 5, 6, 20].map((a) => backoffDelayMs(a))).toEqual([
      500, 1000, 2000, 4000, 8000, 15000, 15000, 15000,
    ]);
  });

  it("clamps negative attempts to the initial delay", () => {
    expect(backoffDelayMs(-3)).toBe(500);
  });
});

describe("createChannelFeed", () => {
  const envelope = (
    overrides: Partial<EnvelopeV1> &
      Pick<EnvelopeV1, "channel" | "gen" | "payload">,
  ): EnvelopeV1 => ({ v: 1, ts: 1721150000000, ...overrides });

  it("advances state and notifies on a fresh generation", () => {
    const seen: unknown[] = [];
    const feed = createChannelFeed(fixtureChannelStoreState, (state) =>
      seen.push(state),
    );
    const payload = { live: "weather" };

    feed.push(envelope({ channel: "weather", gen: 1, payload }));

    expect(feed.current().snapshots.weather).toEqual(payload);
    expect(feed.current().gens.weather).toBe(1);
    expect(seen).toHaveLength(1);
  });

  it("absorbs stale-generation and unknown-channel frames without notifying", () => {
    const seen: unknown[] = [];
    const feed = createChannelFeed(fixtureChannelStoreState, (state) =>
      seen.push(state),
    );

    feed.push(envelope({ channel: "weather", gen: 0, payload: { stale: 1 } }));
    feed.push(envelope({ channel: "system", gen: 9, payload: { sys: 1 } }));
    feed.push(
      envelope({
        channel: "not-a-channel" as EnvelopeV1["channel"],
        gen: 9,
        payload: {},
      }),
    );

    expect(feed.current()).toBe(fixtureChannelStoreState);
    expect(seen).toHaveLength(0);
  });
});

type FakeSocket = GatewaySocket & {
  readonly url: string;
  readonly sent: string[];
  closed: boolean;
};

type FakeTimer = {
  readonly fn: () => void;
  readonly delayMs: number;
  cancelled: boolean;
};

const createHarness = () => {
  const sockets: FakeSocket[] = [];
  const scheduled: FakeTimer[] = [];
  return {
    sockets,
    scheduled,
    createSocket: (url: string): GatewaySocket => {
      const sent: string[] = [];
      const socket: FakeSocket = {
        url,
        sent,
        closed: false,
        send: (data) => {
          sent.push(data);
        },
        close: () => {
          socket.closed = true;
        },
        onopen: null,
        onmessage: null,
        onclose: null,
        onerror: null,
      };
      sockets.push(socket);
      return socket;
    },
    timers: {
      schedule: (fn: () => void, delayMs: number) => {
        const timer: FakeTimer = { fn, delayMs, cancelled: false };
        scheduled.push(timer);
        return timer;
      },
      cancel: (handle: unknown) => {
        (handle as FakeTimer).cancelled = true;
      },
    },
  };
};

describe("createGatewayClient", () => {
  it("connects to the given URL and sends refresh_channel intents on open", () => {
    const harness = createHarness();
    createGatewayClient({
      url: "ws://host:9138/ws",
      createSocket: harness.createSocket,
      timers: harness.timers,
      now: () => 42,
      refreshOnOpen: ["weather", "photo"],
    });

    expect(harness.sockets).toHaveLength(1);
    expect(harness.sockets[0].url).toBe("ws://host:9138/ws");

    harness.sockets[0].onopen?.();
    expect(harness.sockets[0].sent.map((frame) => JSON.parse(frame))).toEqual([
      {
        v: 1,
        ts: 42,
        type: "intent",
        name: "refresh_channel",
        args: { channel: "weather" },
      },
      {
        v: 1,
        ts: 42,
        type: "intent",
        name: "refresh_channel",
        args: { channel: "photo" },
      },
    ]);
  });

  it("feeds decoded envelopes into the channel store via subscribers", () => {
    const harness = createHarness();
    const client = createGatewayClient({
      url: "ws://host/ws",
      createSocket: harness.createSocket,
      timers: harness.timers,
    });
    const feed = createChannelFeed(fixtureChannelStoreState, () => undefined);
    client.subscribe(feed.push);

    harness.sockets[0].onopen?.();
    harness.sockets[0].onmessage?.({
      data: envelopeFrame({
        channel: "playlist",
        gen: 7,
        payload: { as_of: "now", stale: false, playlists: [] },
      }),
    });

    expect(feed.current().gens.playlist).toBe(7);
    expect(feed.current().snapshots.playlist).toEqual({
      as_of: "now",
      stale: false,
      playlists: [],
    });
  });

  it("ignores malformed and wrong-version frames without throwing", () => {
    const harness = createHarness();
    const client = createGatewayClient({
      url: "ws://host/ws",
      createSocket: harness.createSocket,
      timers: harness.timers,
    });
    const received: EnvelopeV1[] = [];
    client.subscribe((envelope) => received.push(envelope));

    harness.sockets[0].onopen?.();
    harness.sockets[0].onmessage?.({ data: "{nope" });
    harness.sockets[0].onmessage?.({ data: new ArrayBuffer(2) });
    harness.sockets[0].onmessage?.({
      data: JSON.stringify({ v: 2, ts: 1, channel: "weather", gen: 1, payload: {} }),
    });

    expect(received).toEqual([]);
  });

  it("sends intents only while open, and reports drops", () => {
    const harness = createHarness();
    const client = createGatewayClient({
      url: "ws://host/ws",
      createSocket: harness.createSocket,
      timers: harness.timers,
    });
    const intent = buildIntent(setVolumeRequest(-1), 7);

    // Still connecting: dropped.
    expect(client.sendIntent(intent)).toBe(false);
    expect(harness.sockets[0].sent).toEqual([]);

    harness.sockets[0].onopen?.();
    expect(client.sendIntent(intent)).toBe(true);
    expect(JSON.parse(harness.sockets[0].sent[0])).toEqual({
      v: 1,
      ts: 7,
      type: "intent",
      name: "set_volume",
      args: { delta: -1 },
    });

    harness.sockets[0].onclose?.();
    expect(client.sendIntent(intent)).toBe(false);
  });

  it("reports a drop when the socket send itself throws", () => {
    const harness = createHarness();
    const client = createGatewayClient({
      url: "ws://host/ws",
      createSocket: (url) => {
        const socket = harness.createSocket(url);
        return {
          ...socket,
          send: () => {
            throw new Error("socket closing");
          },
        };
      },
      timers: harness.timers,
    });

    harness.sockets[0].onopen?.();
    expect(client.sendIntent(buildIntent(setVolumeRequest(1), 1))).toBe(false);
  });

  it("reconnects with deterministic capped backoff and resets after reopen", () => {
    const harness = createHarness();
    createGatewayClient({
      url: "ws://host/ws",
      createSocket: harness.createSocket,
      timers: harness.timers,
    });

    harness.sockets[0].onopen?.();
    harness.sockets[0].onclose?.();

    // Fail every subsequent connection: delays double then cap at 15s.
    for (let i = 0; i < 6; i += 1) {
      const timer = harness.scheduled[harness.scheduled.length - 1];
      timer.fn();
      harness.sockets[harness.sockets.length - 1].onclose?.();
    }
    expect(harness.scheduled.map((timer) => timer.delayMs)).toEqual([
      500, 1000, 2000, 4000, 8000, 15000, 15000,
    ]);

    // A successful open resets the backoff sequence.
    harness.scheduled[harness.scheduled.length - 1].fn();
    const reopened = harness.sockets[harness.sockets.length - 1];
    reopened.onopen?.();
    reopened.onclose?.();
    expect(harness.scheduled[harness.scheduled.length - 1].delayMs).toBe(500);
  });

  it("schedules a single reconnect when a socket fires both error and close", () => {
    const harness = createHarness();
    createGatewayClient({
      url: "ws://host/ws",
      createSocket: harness.createSocket,
      timers: harness.timers,
    });

    harness.sockets[0].onerror?.();
    harness.sockets[0].onclose?.();
    expect(harness.scheduled).toHaveLength(1);
  });

  it("retries when the socket constructor itself throws", () => {
    const harness = createHarness();
    let calls = 0;
    createGatewayClient({
      url: "ws://host/ws",
      createSocket: (url) => {
        calls += 1;
        if (calls === 1) {
          throw new Error("no network");
        }
        return harness.createSocket(url);
      },
      timers: harness.timers,
    });

    expect(harness.sockets).toHaveLength(0);
    expect(harness.scheduled).toHaveLength(1);
    harness.scheduled[0].fn();
    expect(harness.sockets).toHaveLength(1);
  });

  it("dispose cancels reconnects, closes the socket, and goes silent", () => {
    const harness = createHarness();
    const client = createGatewayClient({
      url: "ws://host/ws",
      createSocket: harness.createSocket,
      timers: harness.timers,
    });
    const received: EnvelopeV1[] = [];
    client.subscribe((envelope) => received.push(envelope));

    harness.sockets[0].onopen?.();
    harness.sockets[0].onclose?.();
    expect(harness.scheduled).toHaveLength(1);

    client.dispose();
    expect(harness.scheduled[0].cancelled).toBe(true);
    expect(harness.sockets[0].closed).toBe(true);
    expect(client.sendIntent(buildIntent(setVolumeRequest(1), 1))).toBe(false);

    // A stray timer fire or late socket event after dispose does nothing.
    harness.scheduled[0].fn();
    harness.sockets[0].onmessage?.({
      data: envelopeFrame({ channel: "weather", gen: 1, payload: {} }),
    });
    harness.sockets[0].onclose?.();
    expect(harness.sockets).toHaveLength(1);
    expect(harness.scheduled).toHaveLength(1);
    expect(received).toEqual([]);
  });
});
