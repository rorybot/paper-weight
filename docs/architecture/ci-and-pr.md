# CI, PR process, and branch protection

**Status:** active (chore/pr-process-ci)  
**Goal:** every change lands via PR with automated checks; speed agents without trusting local-only green.

---

## Rule: no direct commits to `master`

`master` is protected:

- Pull request **required** before merge  
- Required status check: **`ci`** (aggregate job)  
- Force-push disabled  

Work on `lane/*`, `chore/*`, `fix/*`, etc., open a PR, wait for CI, merge.

---

## Workflows

| Workflow | When | What |
|----------|------|------|
| `ci.yml` | PR + push `master` | Path-filtered device-ui / host / input-bridge + screen-test heuristic + lane-guard; aggregate job `ci` |
| `labeler.yml` | PR | Path labels (`feed`, `weather`, `device-ui`, …) |
| `kanban-on-merge.yml` | PR merged | Best-effort close `Closes #N` + project Status=Done |
| `device-ui-pages.yml` | push `master` (device-ui paths) | Static Pages deploy of `src/device-ui/dist` |

### Aggregate check `ci`

Sub-jobs **skip** when paths are untouched. Branch protection only requires **`ci`**, which treats `success` and `skipped` as OK and fails on any `failure`/`cancelled`.

### Lane guard

Fails if a PR touches **2+ product lanes** (weather / feed / now-playing / etymology / photo) unless:

- Branch matches `chore/*` | `fix/*` | `docs/*` | `ci/*` | `dependabot/*`, or  
- Label `cross-lane` | `chore` | `platform` | `ci`

### Screen tests

If `*Screen.tsx` under `src/device-ui/src/screens/` changes, require `*Screen.test.tsx` or `model.test.ts` in the same folder.

---

## Secrets (optional)

| Secret | Purpose |
|--------|---------|
| `PROJECT_TOKEN` | PAT with `repo` + `project` so `kanban-on-merge` can set GitHub Project Status (user projects often deny default `GITHUB_TOKEN`) |

Without `PROJECT_TOKEN`, issue close may still work; project field edit is soft-fail.

---

## Local commands (same as CI)

```bash
# device-ui
cd src/device-ui && npm ci && npm run check

# host
cd host && mix test

# input-bridge (full device matrix still local)
cd src/input-bridge && bash scripts/check.sh
# CI uses: cargo fmt --check && cargo test && cargo clippy -- -D warnings
```

---

## Visual regression (later)

Full Playwright vs `spec/*.png` is **not** in CI yet (brittle while screens move). Prefer:

1. `npm run check` + human glance at mockups  
2. Optional later: Playwright viewport 800×480 smoke only (no pixel match)

---

## Agent checklist (session end)

1. PR opened, `ci` green  
2. Project Status matches reality (Done + issue closed)  
3. `kanban/board.md` + `features/*/spec.md` mirror updated  
4. No secrets in logs  
