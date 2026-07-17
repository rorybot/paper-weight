# Parallel lane task packets

Hand these files to agents as **Task 1 / 2 / 3**. Each file is self-contained.

| Say this | File | Card | Owns |
|----------|------|------|------|
| **Task 1** | [`TASK-1-weather.md`](./TASK-1-weather.md) | W1 #9 | `host/lib/paper_weight/weather/**` |
| **Task 2** | [`TASK-2-feed.md`](./TASK-2-feed.md) | F1 #12 | `host/lib/paper_weight/feed/**` |
| **Task 3** | [`TASK-3-spotify.md`](./TASK-3-spotify.md) | N1 #6 | `host/lib/paper_weight/spotify/**` |

### Example human assign

```text
Agent A: You are Task 1. Read features/_lanes/TASK-1-weather.md and only that lane.
Agent B: You are Task 2. Read features/_lanes/TASK-2-feed.md and only that lane.
Agent C: You are Task 3. Read features/_lanes/TASK-3-spotify.md and only that lane.
```

### Worktrees (optional)

```bash
git worktree add .worktrees/weather -b lane/weather-w1 master
git worktree add .worktrees/feed    -b lane/feed-f1    master
git worktree add .worktrees/spotify -b lane/spotify-n1 master
```

### After all three Done

Orchestrator wave 3: deps from each spec’s Deps request → `mix.exs`, register three children in `Application`, WS fan-out, wire screens.
