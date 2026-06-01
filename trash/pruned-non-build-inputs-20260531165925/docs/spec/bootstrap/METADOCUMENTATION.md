# Metadocumentation

> **Status:** Generic metadocument.
> **Scope:** Common repository-document types used in agent-managed or human-managed agentic projects.

---

## 1. Purpose

Many repositories now use a small set of recurring documents to help humans and agents work in the same tree without guessing at **roles, expectations, or settled decisions**.
Those agents may operate through local tools, terminal workflows, browser interfaces, or collaborative systems, and they may differ widely in capability, persistence, and execution authority.

This document describes four common document types that may coexist:

- `AGENTS.md`
- `CLAUDE.md`
- `CONSENSUS.md`
- `README.md`

Not every repository needs all four. When they do appear together, they are easier to maintain when each one has a **distinct role** and does not quietly absorb the others.

---

## 2. The Four Common Document Types

### 2.1 `AGENTS.md`

`AGENTS.md` defines **how work is carried out** in a repository.

It establishes:

- canonical commands and workflows (e.g. build, test, lint, run, deploy)
- environment expectations
- repository structure and likely entrypoints
- operational constraints and safe defaults (e.g. do not mutate X, always use Y interface)
- review and handoff method

It is principally machine-oriented and execution-oriented. It tells an agent **what kinds of actions make sense** in the repository and **what operational boundaries should be respected**.
It does not enforce permissions by itself. It defines the set of meaningful actions: expected to succeed, and considered correct within the repository.
A good `AGENTS.md` assumes that some agents begin with limited or unknown execution authority and helps them discover what they can actually do before they act, especially in sandboxed or tool-constrained environments.

It is not primarily a **style guide**, a **design philosophy document**, or a **ledger of settled decisions**.

### 2.2 `CLAUDE.md`

`CLAUDE.md` defines **how an agent should interpret, reason about, review, modify, and write** within a project.

It answers: **how should I think, decide, and write while operating in this project?**

It establishes:

- coding and writing preferences
- reasoning constraints
- review taxonomy
- stylistic expectations
- project-specific design taste

**Coding is usually its principal arena**, but the same guidance often applies to review, design, and documentation work as well.

Despite the filename, it is not limited to one product or provider. In practice, many agents and many human collaborators can use it as a local reasoning and writing guide.

It does not primarily define **what actions are available**. It defines **how decisions should be made and how outputs should look**.

### 2.3 `CONSENSUS.md`

`CONSENSUS.md` records points that are **already settled** and should not be casually reopened.

It answers: **has this been decided already, and am I allowed to revisit it?**

It is meant to be **binding across agents and sessions**.

It establishes:

- finalized design choices
- resolved tradeoffs
- rejections of alternatives
- invariants that must not drift

Its purpose is **stability**. It reduces repeated debate, accidental drift, and revisions that quietly contradict earlier decisions.

It is not a workspace for **open brainstorming**. It is not immutable, but its revisions should be **deliberate, atomic, and surgical**.

This helps prevent:

- re-litigation of prior decisions
- stylistic or architectural drift
- hallucinated "improvements" that contradict established design

### 2.4 `README.md`

`README.md` is the **human-first orientation document**.

It answers: **what is this, and how do I orient myself quickly enough to begin?**

It establishes:

- project identity
- purpose
- system shape at a high level
- first useful interaction
- navigation to deeper documentation
- a small amount of optional status or example material when that helps

It is often the first document a person sees. Agents often read `README.md` first, so it also anchors first-pass repository semantics.

`README.md` is not an **agent-control document**. It is not the place for **detailed execution contracts**, **reasoning directives**, or **settled decision ledgers**. Those belong in `AGENTS.md`, `CLAUDE.md`, and `CONSENSUS.md` respectively.
When a project uses those documents, `README.md` should route readers to them explicitly with a single clear directive block.
This helps prevent high-level orientation prose from being misread as operational instruction.

`README.md` is also not a wiki, tutorial archive, exhaustive API reference, or philosophical essay. Keep long tutorials, exhaustive reference material, and extended essays elsewhere.

A strong `README.md` should render cleanly on a repository landing page, support **fast human comprehension**, and enable **first successful action within minutes**.

> _Orientation, not exposition._

**Tone and Style**

`README.md` should be:

- **dense and economical**
- **plain-speaking and efficient**
- **typically shorter than deeper design or architecture documentation**
- **free of narrative drift**

When a comparison helps, aim for the register of strong open-source documentation such as GNU manuals or IETF prose: direct, information-dense, and non-marketing.

---

## 3. README Responsibilities

A good `README.md` covers six responsibilities:

### 3.1 Identity

Name the project and describe it in one precise, non-marketing sentence.

### 3.2 Purpose

State what problem the project addresses and why it exists.
State the design intent when that helps frame the reader's mental model before deeper exposition.

### 3.3 System Shape

Show the high-level structure and major components without forcing the reader into deep internals. The reader should be able to avoid blind exploration.

### 3.4 First Interaction

Show the smallest useful path to running, installing, initializing, configuring, testing, or exploring the project.
This is often the most operationally critical section.

### 3.5 Navigation

Route readers to the deeper documents that answer narrower questions. `README.md` is the router, not the full map.

### 3.6 Optional Context

Add status, examples, screenshots, or similar material only when they materially improve orientation.
Keep examples minimal. Use screenshots only when the system is genuinely interface-heavy.

---

## 4. How These Documents Relate

These documents work best when they are distinct but cooperative.

- `AGENTS.md` explains how to operate.
- `CLAUDE.md` explains how to reason and write.
- `CONSENSUS.md` explains what is already settled.
- `README.md` explains what the project is and how to orient quickly.

Repositories do not need one universal reading order for every reader or every tool. In practice, the order in which agents encounter documents is often partly stochastic. Even so, a default entry order is still useful.

**Default agent entry order**

1. `README.md` for orientation and first-pass repository semantics
2. `AGENTS.md` for executable capabilities, tooling, and operational boundaries
3. `CLAUDE.md` for reasoning, review, and writing guidance
4. `CONSENSUS.md` for settled decisions before proposing change

This is the default orientation order, not a universal law. Task-specific work may require a narrower or different read path.

The important point is not one rigid sequence. The important point is that **each document has a clear job** and does not silently duplicate the others.

---

## 5. Multi-Agent Reality

These document types should remain usable across heterogeneous agent environments. Agents vary in memory, context windows, execution authority, tool access, and persistence. They often do not share memory, do not share context windows, and do not share consistent execution environments. The documents should therefore make roles, boundaries, and expectations stable and well-defined inside the repository itself, without assuming one shared runtime or one shared integration surface.

#### Local (high execution authority)

Agents in local tools often have broad filesystem access, richer tool access, and greater mutation authority. They can usually inspect and change more, so the documents must make operational boundaries explicit.

#### Browser (low execution authority, high reasoning)

Browser-based agents often have weaker local access but stronger long-form reasoning or synthesis capacity. They need role clarity, settled decisions, and clear routing even when they cannot inspect or execute directly.

#### Terminal

Terminal agents often sit between the two. They may have command access and some repository visibility, but with constrained tools, partial context, or stricter mutation boundaries.

#### Collaborative / persistent layer

Collaborative systems may preserve discussion, tasks, or partial context across time, but they do not solve the deeper problem of state persistence across agents. They do not guarantee one shared memory or one shared execution environment. Repository documents should not depend on those systems in order to remain coherent.

A tool, integration, or external system may be used without becoming a core dependency. `AGENTS.md` should distinguish clearly between tools the project may use, integrations that are optional, and dependencies without which core work actually breaks.

For `AGENTS.md` specifically, define which external interactions are valid, expected, and optional. Do not assume optional integrations are available. Do not block core work on unavailable optional integrations. When an integration is optional, say how to proceed without it.

Before revising `AGENTS.md` from this metadocument, especially around tooling or newly discovered tools, check with the project owner or maintainer (Tushy).

Concrete examples:

- If issue-tracker access is configured, reflect completed work there; otherwise continue with the in-repo workflow.
- If chat or notification integration is available, publish consensus updates there; otherwise record them only in-repo.

The repository remains the authoritative source of truth for its own operation and decisions.

---

## 6. Common Failure Modes

These documents become harder to trust when they fail in predictable ways.

### 6.1 Role Drift

One document starts absorbing another document's job. A `README.md` becomes an execution contract. An `AGENTS.md` becomes a style guide. A `CLAUDE.md` becomes a decision ledger.

### 6.2 Internal Contradiction

An introduction defines one model, later sections use another, and the summary silently mixes both.

### 6.3 Undefined Jargon

A compressed term appears because it sounds useful, but the text never defines it clearly enough to reuse with confidence.

### 6.4 Drafting Residue

The document still contains revision talk, handoff chatter, personal notes, or editorial process language that should never have survived into the document body.

### 6.5 Soft Hierarchy Leakage

Two states are meant to be co-equal, but the prose quietly privileges one through words like "preferred," "normal," or "tolerated" without actually defining a hierarchy.

### 6.6 Timing Drift

A rule depends on when something is resolved, frozen, or evaluated, but the document leaves that timing implicit.

### 6.7 Half-Completed Renames

A term changes, but the old and new names remain mixed in ways that make the ontology look unsettled even when the design is already clear.

### 6.8 Biased Examples

Examples repeatedly show one valid view, path, or representation and quietly train the reader to think it is the only real one.

---

## 7. Quality Criteria

These document types are more robust when they follow a small set of generic disciplines:

- define terms before relying on them heavily
- keep one name for one meaning
- separate structure from behavior
- write rules directly when the text is normative
- remove drafting residue instead of preserving it
- state timing when timing affects the rule
- name co-equality explicitly when that is the design
- complete renames cleanly
- use examples that clarify rather than bias

This is not a demand for one uniform style across all repositories. It is a reminder that these document types work best when they are clear, internally consistent, and easy to trust.

---

## 8. Separation of Concerns

The documents are intentionally orthogonal and non-duplicative, each governing a distinct axis:

- **`AGENTS.md`** → what is executable
  - what can be done and how to do it
- **`CLAUDE.md`** → how to reason, review, and write
  - how to think and judge while doing the work
- **`CONSENSUS.md`** → what is fixed
  - what is already decided and should not be casually reopened
- **`README.md`** → what this is and how to begin
  - a human-first orientation interface that is structured tightly enough to be machine-usable without becoming machine-governing

---

## 9. Summary Table

| Document | Primary Role | Common Failure Without It |
| --- | --- | --- |
| `AGENTS.md` | Working method and execution guidance | Invalid operations, unsafe assumptions, weak handoffs |
| `CLAUDE.md` | Reasoning, writing, and review guidance | Style drift, poor judgment, inconsistent edits |
| `CONSENSUS.md` | Settled decisions and repeated invariants | Re-litigation, semantic drift, accidental contradiction |
| `README.md` | Human-first orientation and routing | Slow onboarding, poor navigation, confused first contact |

This documentation set aims at **zero-entropy assimilation and execution**: capability, reasoning, and settled truth are separated clearly enough to reduce inconsistency, prevent accidental drift, and support more deterministic agent behavior across tools.