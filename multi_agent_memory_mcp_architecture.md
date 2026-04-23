# Multi-Agent Memory + Repo Workflow Architecture

## Goal

Create a durable workflow layer that keeps multiple AI tools and agents as synchronized as possible across the same software project without relying on any one platform's built-in memory.

This is meant to support a real development workflow where different tools may be used for different strengths:

- ChatGPT for architecture, debugging, planning, and prompt design
- Codex for code generation and implementation bursts
- Warp for execution, terminal workflows, and local iteration
- Ollama or other local/cloud models for overflow, second opinions, or private/local work
- Mind for long-term project memory and checkpointing
- a custom MCP server for repo-local workflow enforcement and handoff state

The immediate priority is to preserve this design so it can be implemented after the Mac remote desktop / software-KVM project is finished.

---

## Why This Exists

Current AI tools are strong individually, but weak at:

- seamless switching between tools
- shared project memory across platforms
- preserving exact workflow state between sessions
- writing concise and durable task handoffs automatically
- keeping architecture guidance, active status, and next-task prompts synchronized

The core problem is that model context is usually:

- tool-specific
- ephemeral
- partially hidden
- expensive to rebuild

The solution is to move project memory and workflow state out of the model and into a shared, inspectable, durable layer.

---

## Core Design Principle

Treat models as mostly stateless workers.

Keep durable project continuity in:

1. repo-local markdown files
2. long-term memory system
3. workflow tools exposed through MCP

This creates a layered system where no single AI platform owns the project's memory.

---

## Proposed Stack

### 1. Repo-Local Source of Truth

Each software repo gets a small set of standard files:

- `AGENTS.md`
- `STATUS.md`
- `NEXT_PROMPT.md`
- `TASK_LOG.md`

These files live in the repo so they:

- travel with the code
- work with git history
- are visible to humans
- are readable by any agent or platform
- do not depend on MCP support to remain useful

### 2. Mind

Mind acts as the long-term memory layer.

Mind is useful for:

- project memory across sessions
- important discoveries
- architecture decisions
- debugging notes
- checkpoints and historical context
- memory that may outlive or span multiple repos or longer timelines

Mind should not be treated as the sole source of truth for exact current code state.

### 3. Custom MCP Server

A custom MCP server acts as the workflow and repo-state orchestration layer.

It standardizes how agents:

- bootstrap project context
- read the active project state
- finish tasks
- write structured summaries
- update handoff files
- sync durable discoveries into Mind

### 4. Agents / Models

All agents connect to:

- the repo
- Mind
- the custom MCP server

This makes the workflow portable across tools instead of hiding the process in per-platform custom instructions.

---

## High-Level Architecture

```text
Models / Agents
  ├─ ChatGPT
  ├─ Codex
  ├─ Warp agents / terminal workflows
  ├─ Ollama / local or cloud models
  └─ others
        │
        ▼
Custom MCP Server
  ├─ project bootstrap
  ├─ read project context
  ├─ finish task
  ├─ update status
  ├─ append task log
  ├─ write next prompt
  ├─ summarize git changes
  ├─ sync discoveries to Mind
  └─ read relevant memory from Mind
        │
        ├──────────────► Repo markdown files
        │                 ├─ AGENTS.md
        │                 ├─ STATUS.md
        │                 ├─ NEXT_PROMPT.md
        │                 └─ TASK_LOG.md
        │
        └──────────────► Mind
                          ├─ long-term memory
                          ├─ checkpoints
                          ├─ discoveries
                          └─ historical project context
```

---

## Why This Should Work Well

### It avoids platform lock-in

The system does not depend on one vendor's memory model, custom instructions, or session history.

### It makes context durable and inspectable

Important information is kept in markdown files and memory entries that humans can read, review, prune, and version.

### It lowers context rebuild costs

A new agent can start by reading:

- `AGENTS.md`
- `STATUS.md`
- `NEXT_PROMPT.md`
- the last few relevant entries from `TASK_LOG.md`
- relevant memories from Mind

That is much more efficient than rebuilding project history from scratch.

### It separates stable rules from active state

- `AGENTS.md` = stable architecture and workflow rules
- `STATUS.md` = current active state
- `NEXT_PROMPT.md` = next recommended task prompt
- `TASK_LOG.md` = concise historical changelog and discoveries
- Mind = long-term memory and cross-session recall

### It fits real-world multi-tool use

This design assumes the user will continue swapping among multiple tools and wants continuity without manually maintaining huge custom instructions everywhere.

---

## Role of Each Repo File

## `AGENTS.md`

Purpose:

- architecture rules
- project conventions
- workflow rules
- important constraints
- what should not be casually changed

Update frequency:

- infrequent
- only when architecture, conventions, or workflow change materially

This file should remain relatively stable.

## `STATUS.md`

Purpose:

- current project state
- what is working
- what is in progress
- blockers
- active branch if useful
- current objective
- current constraints

Update frequency:

- every meaningful task
- overwritten or refreshed as needed

This file is the active state snapshot.

## `NEXT_PROMPT.md`

Purpose:

- the best next handoff prompt for the next agent or session
- concrete continuation guidance
- instructions on what to preserve and what not to change

Update frequency:

- every meaningful task or whenever the next action changes

## `TASK_LOG.md`

Purpose:

- append-only concise task history
- what changed
- what was learned
- what was verified
- what should happen next

Update frequency:

- append once per meaningful task

This file acts like release notes for every prompt/task boundary.

---

## Recommended Task Log Entry Structure

Each entry should stay concise and dense.

Suggested structure:

```md
## YYYY-MM-DD HH:MM — Task title

### Goal
One-paragraph description of the task objective.

### Changed
- file/path/one
- file/path/two

### What was done
- concise bullet
- concise bullet

### Important discoveries
- concise bullet
- concise bullet

### Verification
- what was tested or verified
- what still remains unverified

### Known limitations
- concise bullet
- concise bullet

### Next
Single best next step.
```

---

## What the Custom MCP Server Should Do

The MCP server should not try to be a giant all-in-one AGI orchestrator.

It should be a focused repo-workflow server with optional Mind integration.

### Primary responsibilities

- ensure the standard repo files exist
- read the active project context
- write structured task-finalization updates
- summarize or inspect changed files
- sync durable discoveries to Mind
- retrieve relevant memory from Mind at task start

### Ideal philosophy

- deterministic where possible
- light orchestration
- minimal magic
- human-readable output
- easy to audit

---

## Recommended MCP Tools

### `ensure_project_files`

Creates missing files with templates:

- `AGENTS.md`
- `STATUS.md`
- `NEXT_PROMPT.md`
- `TASK_LOG.md`

May also initialize a project metadata block.

### `read_project_context`

Returns a compact context bundle including:

- contents of `AGENTS.md`
- contents of `STATUS.md`
- contents of `NEXT_PROMPT.md`
- last N relevant entries from `TASK_LOG.md`
- optionally relevant memories from Mind

This should be the default start-of-task tool.

### `start_task`

Optional wrapper around `read_project_context` that:

- records task start metadata
- returns the active context bundle
- optionally records the task goal

### `finish_task`

The most important tool.

Accepts structured fields such as:

- `goal`
- `summary`
- `files_changed`
- `what_was_done`
- `important_discoveries`
- `verification`
- `known_limitations`
- `next_step`
- `update_agents` optional boolean or patch info

Then it:

- refreshes `STATUS.md`
- appends a `TASK_LOG.md` entry
- rewrites `NEXT_PROMPT.md`
- optionally syncs durable discoveries into Mind

### `update_status`

Updates the current active project state in `STATUS.md`.

Useful when status changes without a full task-finalization cycle.

### `append_task_log`

Appends a structured entry to `TASK_LOG.md`.

Useful if task logging is done separately from status updates.

### `write_next_prompt`

Writes or refreshes `NEXT_PROMPT.md` with a concise next-step prompt.

### `summarize_git_changes`

Inspects the repo state and produces a compact summary based on:

- changed files
- git diff stat
- optionally recent commits

This can help the agent produce higher-quality task-finalization output.

### `sync_memory_to_mind`

Pushes durable discoveries, decisions, or checkpoints into Mind.

### `read_memory_from_mind`

Returns relevant memories for the current project and task.

---

## Recommended Minimal Agent Instruction

Once the MCP server exists, the universal agent instruction can stay small.

Example:

> At the start of each task, call the project context tool and use repo workflow files as the primary project context. At the end of each meaningful task, call the task finalization tool to update repo state and write a concise handoff summary.

This is much lighter than copying large custom instructions into every platform.

---

## Operating Model

## Start of Task

1. Agent connects to project repo
2. Agent calls `read_project_context` or `start_task`
3. Agent reads:
   - `AGENTS.md`
   - `STATUS.md`
   - `NEXT_PROMPT.md`
   - last relevant task entries
   - optional Mind memories
4. Agent performs work

## End of Task

1. Agent summarizes what changed
2. Agent calls `finish_task`
3. MCP server updates:
   - `STATUS.md`
   - `TASK_LOG.md`
   - `NEXT_PROMPT.md`
4. MCP server optionally syncs discoveries to Mind

---

## Recommended Boundaries

### What should update often

- `STATUS.md`
- `NEXT_PROMPT.md`
- `TASK_LOG.md`

### What should update only when needed

- `AGENTS.md`

`AGENTS.md` should not be rewritten after every task. It should only change when architecture, conventions, or workflow materially change.

### What Mind should store

Mind should store:

- durable discoveries
- architecture decisions worth remembering later
- historical context
- recurring bugs and fixes
- useful checkpoints

Mind should not replace the repo files for current active state.

---

## Why Not Depend Only on Mind

Mind is strong for long-term memory, but repo-local files still matter because they:

- travel with the code
- remain useful without external services
- are easy to review in git
- are easy for any model to read
- keep active project state close to implementation

The repo files and Mind complement each other.

---

## Why Not Depend Only on Custom Instructions

Custom instructions are fragile because they:

- vary by platform
- are annoying to copy everywhere
- may be ignored or partially followed
- are hard to evolve consistently
- do not create inspectable project artifacts

Moving the workflow into tools and repo files is more robust.

---

## Likely Implementation Approach

### Phase 1

Build the repo workflow system without deep Mind automation.

Implement:

- repo file templates
- `read_project_context`
- `finish_task`
- `update_status`
- `append_task_log`
- `write_next_prompt`
- optional `summarize_git_changes`

This alone provides most of the value.

### Phase 2

Add Mind integration.

Implement:

- `read_memory_from_mind`
- `sync_memory_to_mind`
- project-aware memory selection
- discovery extraction rules

### Phase 3

Add orchestration refinements if needed.

Possible additions:

- task IDs
- session IDs
- agent identity tracking
- branch awareness
- more advanced diff summarization
- confidence or verification tagging

---

## Risks and Failure Modes

### Memory drift

Agents may write incorrect or vague summaries.

Mitigation:

- keep summaries concise and structured
- prefer explicit fields over freeform narrative
- make repo files easy to review and edit

### Noise accumulation

Too much verbosity will reduce usefulness.

Mitigation:

- keep `TASK_LOG.md` concise
- separate stable rules from active state
- use Mind for long-lived context, not every detail

### Over-automation

If the MCP server becomes too clever, it may introduce confusion.

Mitigation:

- start deterministic
- let agents provide structured fields
- keep the server focused on formatting, storage, and synchronization

### Source-of-truth ambiguity

If repo files and Mind disagree, agents may get confused.

Mitigation:

- repo-local files are source of truth for active work
- Mind is long-term supporting memory

---

## Why This Is Worth Building

This design creates a practical middle layer between stateless models and durable project execution.

It should make multi-agent development:

- more portable
- more inspectable
- more resilient to tool switching
- less dependent on hidden chat history
- easier to resume after interruptions or usage limits

This is especially valuable for long-running technical projects where multiple agents are used over time.

---

## Immediate Priority Note

This design should be preserved now, but implementation should wait until the Mac remote desktop / software-KVM project is finished or at least at a safe stopping point.

Current priority order:

1. finish the Mac remote desktop input/control work
2. stabilize the Mac project
3. return to this MCP workflow system design
4. implement the custom repo-workflow MCP server
5. integrate Mind after the local repo workflow is working

---

## Suggested Future Deliverables

When work resumes on this system, likely deliverables are:

- MCP tool spec
- repo file templates
- task-finalization schema
- minimal server implementation
- optional Mind integration layer
- example universal instruction for agents
- example project bootstrap flow
- example end-of-task update flow

---

## Short Summary

The proposed system is:

- repo-local markdown files for active source of truth
- Mind for long-term project memory
- a custom MCP server for workflow enforcement and synchronization
- multiple AI agents using the same tools and same project rituals

The goal is not perfect shared intelligence.
The goal is reliable continuity, concise handoffs, and lower context rebuild cost across tools.

