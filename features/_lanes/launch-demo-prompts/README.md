# Launch/demo parallel-agent handoffs

Point each agent at exactly one file. Every handoff is standalone and assigns one card, branch,
and worktree.

| Agent | Card | Handoff | Intended outcome |
|---|---|---|---|
| B | P6-H #83 | `agent-b-p6h.md` | Complete, merge, close |
| C | P6-N #84 | `agent-c-p6n.md` | Complete, merge, close |
| D | W4 #87 | `agent-d-w4.md` | Dependency-free WIP, draft PR |
| E | F3 #88 | `agent-e-f3.md` | Dependency-free WIP, draft PR |
| F | N4 #89 | `agent-f-n4.md` | Dependency-free WIP, draft PR |
| G | P8 #86 | `agent-g-p8.md` | Rust/aarch64 WIP, draft PR |

```text
P6-H ─┐
      ├─> P6-I #82 ─┬─> P7 #85 ─┬─> W4 ─┐
P6-N ─┘             │           ├─> F3 ─┼─> P9 #90
                    │           └─> N4 ─┤
                    └─> P8 ─────────────┘
```

Early WIP branches do not merge until their dependency clears. Substantive WIP moves its card to
In progress, stays open, and ends committed, pushed, tested, and documented in a draft PR.

