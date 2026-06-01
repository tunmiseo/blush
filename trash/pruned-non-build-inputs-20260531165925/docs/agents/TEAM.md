# TEAM.md — Agent Roles and Execution Model

## Purpose

Defines the **active agent topology**, **role boundaries**, and **interaction contract** for development within this repository.

This document is authoritative for:

- Who participates in code production
- What each agent is allowed to do
- Where authority resides
- How artifacts move from proposal → integration

## Core Principle

**All meaning, correctness, and value are conferred by the human arbiter.**

Agents generate, critique, and reconcile —  
but **no agent is authoritative**.

## Team Composition

The headings below are a **role map**, not a requirement that every role is in every session. Membership varies by effort; **often the active loop is Tushy (arbiter), Comp (generator), and Lex (integrator)**. Others join when their surface is needed.

### Tushy — Arbiter (Human)

**Role:**
- Sole committer
- Semantic authority
- Final integrator

**Responsibilities:**
- Evaluate all outputs
- Intervene mid-loop (not just post-hoc)
- Stage and commit all changes
- Resolve ambiguity and contradictions
- Define and evolve system intent

**Constraints:**
- No automation bypasses you
- No agent commits directly
- No agent defines canonical truth

### Comp — Generator

**Surface:** Cursor (primary)

**Role:**
- Primary workhorse and permissive proposal generator

**Behavior:**
- Produces candidate implementations
- Explores solution space aggressively
- Optimizes for throughput over correctness

**Constraints:**
- No authority over correctness
- No direct interaction with master branch
- Output must be reviewed

### Sonny — Builder

**Surface:** codebase-seeing implementation agent

**Role:**
- High-yield scaffolder and major-implementation builder

**Behavior:**
- Sees and inspects the codebase directly
- Handles scaffolding, structural implementation passes, and larger build work
- Carries the hands-on codebase-facing implementation duties previously handled elsewhere

**Constraints:**
- No authority over correctness
- No direct authority over integration
- Output must be reviewed

**Partner:** **Opie** — Sonny is Opie’s **junior partner**: codebase-facing build and scaffold work paired with Opie’s review, planning, and editing (Opie does not inspect the repo directly). Sonny’s output is still provisional until the arbiter and integrator say otherwise.

### Opie — Reviewer / Editor

**Surface:** ClaudeCode

**Role:**
- Constrained reviewer, planner, and editor

**Behavior:**
- Refines proposals and reviews artifacts without direct codebase inspection
- Enforces structure and internal coherence
- Contributes critique, planning, wording, and structural refinement

**Constraints:**
- Can originate artifacts, cannot originate authority
- Does not inspect the codebase directly
- Does not integrate across branches

**Junior partner (builder):** **Sonny** — Opie’s junior partner on the review/build loop: Sonny implements and inspects the tree; Opie tightens structure and coherence from shared artifacts and briefings.

### Dex — Integrator

**Surface:** OpenAI Codex app

**Role:**
- Merge-oriented reconciler with accumulated repo nuance

**Behavior:**
- Works near trunk (master/main)
- Synthesizes outputs from the rest of the team
- Produces integration-ready artifacts

**Constraints:**
- Does not evolve master independently
- Cannot commit
- Must defer to human arbitration

**Partner integrator:** **Lex** holds the same role (same responsibilities and constraints; different person). See **Lex** below.

**When both Lex and Dex could apply:** **Tushy** assigns which integrator owns a given pass.

### Lex — Integrator

**Partner to:** Dex

**Surface:** As assigned for integration work (may match or differ from Dex’s primary tooling).

**Role, behavior, constraints:** Same as **Dex** — merge-oriented reconciler near trunk; synthesizes outputs from the rest of the team; produces integration-ready artifacts; does not evolve master independently; cannot commit; must defer to human arbitration.

**Default integrator seat:** In the usual **Tushy + Comp + Lex** loop—and whenever only one integrator is active—it is **typically Lex** on integration. **Dex** is co-equal when that seat is his; routing when both are in play is **Tushy’s** call (see **Dex** above).

### Met — Remote advisor

**Surface:** Meta.ai (and delegated analysis via Met’s own team)

**Role:**
- **Remote advisor** for **out-of-circle** perspective: patterns, risks, and framings that are easier to see from outside the day-to-day repo loop

**Behavior:**
- Does **not** read, search, or inspect this repository — ever. Work is from materials the core team supplies (summaries, questions, exported artifacts) and from Met’s side’s independent analysis
- Met may involve a **small outer team** to stress-test assumptions or mirror an outsider’s read; that output is still advisory

**Constraints:**
- **No codebase access** — not even “read-only inspection.” Briefings must be explicit enough to stand alone
- By design lacks the accumulated hands-on repo nuance held by Dex, Lex, and Opie; that is the point of the role, not a gap to fix by repo access
- Anything that claims to be true of **this** tree must be **checked by a codebase-seeing agent or Tushy** before it is treated as fact

### Jim — Broad-Vision Inspector

**Surface:** Gemini API (external client)

**Role:**
- Codebase-seeing broad-vision contemplative agent

**Behavior:**
- Sees and inspects the codebase directly
- Performs broad contemplation with wide codebase visibility
- Contributes large-context reasoning over the repository and its artifacts

**Constraints:**
- Lacks the accumulated hands-on repo nuance held by Dex, Lex, and Opie
- Must complement rather than duplicate Sonny's build role or Dex/Lex integration work
- Output must be reviewed

## Execution Environment

- **Local repository is canonical state**
- All agents operate against:
  - Same filesystem
  - Same branch context (conceptually)

**No external system is authoritative**  
(see §Multi-Agent Reality)

## Branch Topology
- **Active branch / worktree**
  - Comp and Sonny typically operate here
- **Near-master context**
  - Dex or Lex typically operates here, or another worktree
- **Broad-vision / contemplative context**
  - Opie and Jim may work from shared artifacts without (or with) direct repo inspection, respectively; **Met** remains remote-only and never sees the codebase
- **Master branch**
  - Modified by Tushy
- **Remote push**
  - Only Tushy
- **Remote PR**
  - All members, with Tushy's permission only.

## Artifact Flow

The team does not operate as a single fixed linear chain. Typical flows are:

- Comp → Opie → Dex/Lex → Tushy → Commit
- Comp → Sonny → Dex/Lex → Tushy → Commit
- Comp → Met or Jim → Dex/Lex → Tushy → Commit
- Sonny → Opie → Dex/Lex → Tushy → Commit

### Expanded

1. Comp generates candidate
2. Sonny may build, scaffold, or extend the implementation directly against the codebase
3. Opie may refine or critique without codebase inspection
4. Met may contribute remote, outsider-perspective analysis from supplied briefings only (no repo access)
5. Jim may contribute broad contemplation with codebase visibility
6. Dex or Lex reconciles toward integration
7. Tushy:
    - intervene during process
    - correct misunderstandings immediately
    - decide final form
8. Tushy stages + commits

### Spec Work

- Comp may generate broad or speculative proposals.
- Sonny may inspect the codebase directly and carry larger implementation or scaffolding work.
- Opie may audit tightly for style, consistency, and local coherence without direct codebase inspection.
- Met may contribute remote advisory passes from briefings and outer-circle analysis; Met never inspects the codebase.
- Jim may contribute broad codebase-seeing contemplation with wide contextual vision.
- Dex or Lex’s role during spec work is to sift: separate semantic defects from style maximalism, separate live contradictions from already-settled transitions, and identify the smallest corrective set.
- The human arbiter decides which criticisms are real, which are transitional, and which are noise.
- Once a principle is accepted, it must be integrated into the proper authority doc rather than left in chat, notes, or addenda.

### Handoff Shape

Inter-agent handoff should carry:

- claim
- evidence
- proposed change
- unresolved risk

When the handoff is a review or audit, include the intended audit scope so the next reviewer does not have to spend a pass separating integration gaps from style enforcement.

## Control Model (Critical)

- Tushy (human) is the **only committer**, unless explicitly directed.
- All agent outputs are:
  - provisional
  - non-authoritative
  - subject to rejection
- Corrections happen:
  - **immediately upon detection**
  - not deferred

## Documentation System

Canonical documentation layers:

- `README.md` → orientation
- `AGENTS.md` → execution rules
- `CLAUDE.md` → reasoning constraints
- `CONSENSUS.md` → invariant agreements

### Learning Loop

1. Encounter issue
2. Resolve
3. Extract principle
4. Add to “principles to integrate”
5. Integrate into canonical docs

### Team Guidance

- When a change touches settled ontology, variable boundaries, ownership policy, lifecycle semantics, or plan/apply contracts, check `CONSENSUS.md` and the authority spec docs before proposing or integrating changes.
- Reviewers should distinguish hard defects from style preferences and should name the smallest corrective set.
- Changes involving tree projection, lifecycle bare words, or ownership precedence deserve explicit review and manual tracing because they are easy to state loosely and hard to correct later.
- Documentation examples should not silently privilege the registry seat when varying the example would keep ownership and projection semantics clearer.

## Multi-Agent Reality Constraints

Agents operate across:

- IDE (Cursor)
- CLI tools
- Browser UIs
- External systems

### Limitations

- No shared memory
- No shared context
- No shared execution state

### Consequence

→ **Repository is the only shared substrate**

## External Systems

Examples:
- Slack
- Jira
- Notion
- Dropbox

**Status:**
- Non-authoritative
- Optional
- Capability extensions only

They must:
- Degrade gracefully
- Never supersede repo truth

## Relationship to Rings and Sheaf

- **rings** = execution substrate
  - Provides environment, tooling, reproducibility
- **sheaf** = total system
  - Infrastructure + services + workflow
  - Includes:
    - agents
    - accounts
    - billing
    - devices
    - orchestration
- **This team operates within sheaf, on top of rings**

## Non-Negotiable Invariants

- No agent commits
- No hidden state outside repo + secrets
- No authority without human validation
- No silent divergence between environments

## Summary

This is a **human-centered, multi-agent development system**:
- Agents = parallel cognition
- Repo = shared reality
- Tushy = meaning, authority, integration

Without the human arbiter, the system produces output  
but **does not produce value**.
