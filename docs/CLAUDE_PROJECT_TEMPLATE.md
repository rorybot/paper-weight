# Token-Optimized Multi-Agent Functional Development Framework Template

**Version:** 0.4 (Export for Claude Import)  
**Date:** 2026-07-15  
**Purpose:** Self-contained context file you can paste or upload directly into Claude (or any strong model) to bootstrap project planning, architecture, or implementation using the exact methodology developed in this conversation.

---

## Wider Project Goal (The "Why")

This is a **reusable template for setting up token-efficient, highly maintainable, AI-augmented software development workflows** — especially for greenfield projects.

The core innovation is treating AI collaboration like a real dev team while aggressively optimizing for token economics and long-term maintainability:

- **Senior Architect** (high-signal specs, pseudo-code, functional decomposition, contracts) does the expensive thinking.
- Specialized agents (Designer, PM/Kanban, Junior Impl) handle narrow scopes.
- Everything is **functional, composable, and modular** so handoffs are cheap, drift is minimal, and humans/robots can maintain it equally well.
- **Feature-branch mental model** for scoping (each agent conceptually owns one slice).
- Heavy use of **prompt compression** (structured formats + LLMLingua-style techniques) to keep costs low.
- Persistent context via chunking + memory tools instead of ever-growing chats.

Goal: Make complex projects dramatically cheaper and more reliable than traditional long-context chats or single-agent approaches, while producing cleaner, more SOLID code.

---

## Core Principles (Immutable)

1. **Token Optimization First**
   - Senior only emits high-signal artifacts (specs, pseudo, contracts).
   - Use compression layers aggressively.
   - New session per major card/feature to reset context.
   - Context chunking + external memory (e.g., edit_memory or markdown files) for persistence.

2. **Functional Paradigm + SOLID**
   - Prefer pure functions, composition (pipes, `|>`, `compose`), immutability.
   - Map SOLID to functional terms: SRP via small focused functions, DIP via function parameters/contracts, etc.
   - Languages: **Elixir** strongly preferred for backend (perfect functional fit). Frontend flexible (Remix + TypeScript + Tailwind if doing JS/TS; React fallback).

3. **Multi-Agent Team Structure (Feature-Branch Thinking)**
   - Architect (Senior) → Designer Agent → PM Agent (Kanban) → Junior Impl Agent(s) → Senior Selective Review.
   - Each "agent" can be you, Claude, Grok, a cheaper model, or a human — the contracts stay the same.

4. **Handoffs via Immutable Contracts**
   - Specs, data flows, function signatures, acceptance criteria, compressed context.
   - Never re-explain the whole system.

5. **Maintainability & Automation**
   - Extensive modularization (AI advantage: we can hold it).
   - Living `PROJECT_INSTRUCTIONS.md`.
   - Automation hooks (reminders, start-feature scripts, context chunking).
   - SOLID + functional = easy to fix/extend later.

---

## Recommended Agent Pipeline (Pseudo-Code Style)

```elixir
defmodule MultiAgentWorkflow do
  def run(input) do
    input
    |> architect_spec()                    # High-level AC, data flow, contracts, pseudo
    |> compress_prompt()                   # Structured rules + LLMLingua-style
    |> handoff_to_designer()               # Wireframes, Tailwind/Remix sketches
    |> handoff_to_pm()                     # Create Kanban cards (epics → stories → tasks)
    |> handoff_to_junior()                 # Impl from compressed specs + designs
    |> senior_selective_review()           # Only critical paths, security, purity
    |> update_kanban_and_chunk()
  end
end
```

**Compression Layer** (critical for token savings):
- Default: Structured output (tables > prose, bullets, task cards with Goal + Scope + Constraints + Acceptance).
- Dynamic: LLMLingua / LongLLMLingua / Selective Context for long specs, tool outputs, or accumulated context.
- Expected additional savings: 40–70% on compressible parts.

---

## Tech Stack Preferences

- **Backend**: Elixir (Phoenix if full web/API). Functional, immutable, concurrent — ideal match.
- **Frontend** (if applicable): Remix (preferred for data loading & nested routes) or React + Vite. TypeScript when doing JS. Tailwind for rapid scoping.
- **Styling**: Tailwind CSS (utility composition feels functional).
- **Other**: Postgres + Ecto (functional queries), strong typing where possible.
- Deviations must be justified per feature.

---

## Prompt Compression Integration (Key Addition)

Insert a **Compression Layer** after Architect output and before every major handoff.

**Proven Techniques (2023–2026)**:
- **Structured Rules** (free, zero-risk): Tables for do/don't, bullets, "Goal + Scope + Constraints + Acceptance" task cards.
- **LLMLingua / LongLLMLingua**: Perplexity-based + query-aware token pruning (2–20×, often 4–6× practical). Can even improve long-context performance.
- **Selective Context**: Self-information scoring (~50%+ reduction, very low quality drop).
- **Tool Output Compression**: Summarize/extract after every tool call (highest ROI in agent loops).
- **Multi-Agent Isolation**: Each agent only sees its narrow, compressed slice.

**Realistic Savings**:
- Traditional single long chat: 40k–120k+ tokens/feature.
- This framework (multi-agent + contracts + chunking): 8k–15k.
- **+ Compression Layer**: Often 5k–10k or lower, with 70–85%+ overall reduction vs baseline.

---

## Recommended Project File Structure

```
/project-root/
├── PROJECT_INSTRUCTIONS.md          # Living template (append this export)
├── docs/
│   └── architecture/
│       └── workflow-vX.md
├── features/                        # One folder per conceptual feature branch
│   └── auth-or-whatever/
│       ├── spec.md                  # Architect output (compressed)
│       ├── design.md                # Designer output
│       ├── cards.md                 # PM Kanban breakdown
│       └── impl/                    # Junior output
├── src/                             # Core code (functional modules)
│   ├── core/                        # Pure utils & composition
│   ├── domains/                     # Bounded contexts (Elixir)
│   └── web/                         # Remix/React if frontend
├── kanban/                          # Or use GitHub Projects / Linear
│   └── board.md
└── scripts/
    └── start-feature.sh             # Automation stub
```

---

## Token Savings Evidence (Summary Table)

| Approach                              | Est. Tokens per Feature | Key Enablers                              | Savings vs Traditional |
|---------------------------------------|-------------------------|-------------------------------------------|------------------------|
| Traditional single-agent long chat   | 40k–120k+              | Full history, repeated explanations      | Baseline              |
| Multi-agent + functional contracts   | 8k–15k                 | Specs, chunking, isolation               | 70–80%                |
| **+ Prompt Compression Layer**       | **5k–10k**             | Structured + LLMLingua-style             | **75–85%+**           |

Compression makes the biggest difference on long specs, tool outputs, and history.

---

## How to Use This Template with Claude (or Any Model)

1. Paste or upload this entire file as the first message / project context.
2. Say: "You are now operating inside the Token-Optimized Multi-Agent Functional Development Framework described above. Treat the principles and pipeline as immutable."
3. Start a new feature by describing the request — Claude will automatically produce high-level spec → compressed handoff artifacts.
4. Use the Kanban / feature-folder pattern to keep scope tight.
5. At the end of any major step, ask for a "Next Session Context Chunk" (3–5 lines) so you can resume cheaply.

**Example Starter Prompt for Claude**:
"Using the framework in the attached template, create the initial spec and compressed handoff for [your feature request]. Follow the Architect → Compression → Designer/PM flow."

---

## Living PROJECT_INSTRUCTIONS.md Additions (Recommended)

Append the following sections to any real `PROJECT_INSTRUCTIONS.md`:

- Mandatory response template (AC + data flow + signatures + pseudo + compression notes).
- Escalation rules (when senior review is required).
- Compression checklist (always use structured output first).
- Reminder: "End every major response with a 3–5 line context chunk for the next session."

---

## Visual References (Conceptual)

- Multi-Agent Workflow with Compression Layer (shows Architect → orange Compression box → downstream agents, 60-80% reduction callout).
- Token Usage Bar Chart (Traditional vs Multi-Agent vs +Compression).
- Conceptual Kanban Board (sticky-note style with example cards like "Elixir Domain Model", "Remix Dashboard").

These can be regenerated or described as needed.

---

**This file is now your portable, importable blueprint.**

You can copy the entire content above (or the saved file at `/home/workdir/artifacts/CLAUDE_PROJECT_TEMPLATE.md`) directly into Claude to start planning real projects with this exact methodology.

Want me to:
- Refine any section?
- Add a sample feature spec using the template?
- Generate the actual `PROJECT_INSTRUCTIONS.md` starter file in the artifacts folder?
- Or scope the first real greenfield project using this?

Just say the word — everything stays scoped, functional, and token-lean.