# Symptom
Device was working, then goes back to "site can't be reached" with no
networking change — `ss -tlnp` shows nothing listening on `:8080`/`:9138`.

# Root cause
`scripts/run-device-fixture.sh` (the `mix` gateway + UI `http.server`) isn't
a persistent service on a dev machine — it's a foreground process. If it was
started as a background job from `validate-e3.sh`, that script's `cleanup`
trap kills whatever it started the moment the script exits or its terminal
closes, silently taking the fixture host down with it.

# Fix
Run it directly, in its own terminal you intend to leave open for the whole
session:
```
cd <repo-or-worktree-root> && ./scripts/run-device-fixture.sh
```
Don't rely on `validate-e3.sh` (or any other wrapper) to keep it alive.
`scripts/try-kick-device.sh` checks for this and tells you if nothing is
serving.

# Status
Resolved (operational discipline, not a code fix — there is no supervisor
keeping this alive on the current dev machine; see `paper-weight-host.service`
/ `scripts/host-service.sh` for the eventual production-host equivalent).
