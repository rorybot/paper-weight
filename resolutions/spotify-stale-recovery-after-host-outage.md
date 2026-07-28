# Symptom

The live Spotify channel stops advancing during a host internet outage. The
last snapshot remains available with `stale=true`; after connectivity returns,
the channel should publish a newer generation with `stale=false` and the Car
Thing should resume showing live progress.

# Verify

1. Start the normal live fixture with Spotify enabled and gateway stubs off.
2. Confirm a fresh `now_playing` snapshot while Spotify is playing; record its
   generation, title, progress, and `stale=false`.
3. Disconnect the host's internet uplink, **not** the Car Thing USB connection.
4. Open a fresh WebSocket connection to `127.0.0.1:9138` and wait for the
   snapshot to report `stale=true` while retaining the last track/progress.
5. Restore the internet uplink. Confirm a later fresh connection reports
   `stale=false` with a generation greater than the baseline, then confirm the
   physical display resumes live progress.

The gateway readiness check must use a WebSocket upgrade and expect HTTP 101;
a plain HTTP GET to `:9138` is not a valid readiness probe.

# Important behavior

- The stale transition does not itself advance the channel generation. An
  already-connected kiosk may therefore keep its last rendered state; sample
  with a new WebSocket connection when verifying the host cache.
- If the USB gadget loses `172.16.42.1`, restore it with the canonical
  `scripts/try-kick-device.sh` path before restarting the kiosk. Do not mistake
  a broken USB route for Spotify recovery failure.
- Credentials remain out of band. Never log or commit `.env` values.

# Status

Verified during N4 #89 physical acceptance on 2026-07-19: the outage produced
a frozen stale snapshot, then recovery advanced generation 1670 to 1688 with
`stale=false`; Rory confirmed the physical device recovered.
