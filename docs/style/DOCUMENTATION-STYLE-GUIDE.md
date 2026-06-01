# Documentation Style Guide

> **Status:** Active authority.
> **Scope:** Prose style for specifications, architecture documents, and explanatory documentation in `docs/`.
> **Relationship to other docs:** [`SHELL_STYLE_GUIDE.md`](./SHELL_STYLE_GUIDE.md) governs code style, file headers, function docblocks, and structured code comments. This document governs documentation prose.

-----

## 1. Purpose

Documentation in `docs/` must be clear, exact, and easy to read without shared context. A document should define its terms, state its rules, and explain its behavior in plain language.

The goal is not decorative prose. The goal is a specification or explanation that a new reader can follow without guessing.

-----

## 2. Core Rules

1. **Define the pattern once. Name it once. Reuse the name.**
   Do not make the reader repeatedly parse raw structural patterns such as `@` prefixes or `*.d/` suffixes when a defined term will do.

2. **State rules as rules.**
   Write invariants and constraints as direct statements. Do not soften them into observations.

3. **Separate structure from behavior.**
   Define what the system is before describing what it does.

4. **Use plain declarative language.**
   Prefer short, direct sentences. Avoid philosophical or ornamental phrasing.

5. **Use strict logic without a strict tone.**
   A specification may be exact without sounding theatrical, punitive, or inflated.

6. **State what does not apply.**
   If a rule is local, say where it stops. If an exception exists, name it directly.

7. **Use examples after the rule, not instead of the rule.**
   Examples illustrate. They do not replace the definition.

8. **Each section should stand on its own.**
   A reader should not need private context from earlier discussion to understand a section.

9. **No brittleness, and stay in your lane.**
   A rule should be about what it authorizes or forbids. It does not legislate what everything else doesn't do.

10. **Say the thing itself.**
    Do not fill the document with commentary about what the document, section, or paragraph is doing unless that boundary prevents a real misunderstanding.

11. **Do not make lossy edits.**
    A revision must not drop operative distinctions, weaken a correct claim, or trade precision for tidiness.

12. **Cite the owning authority when restating a cross-document rule.**
    When a concept is owned by another authority document and restated here, cite the owning document when divergence would matter. Restatement without an authority pointer is a consistency hazard, not duplication for clarity.

13. **In revision work, prefer integration over replacement.**
    Keep section structure, especially when it is already carrying meaning. Preserve explicit contrasts, inventories, and step-by-step guidance. Do not compress concrete prose into abstract summaries.

14. **Never hard wrap standalone prose (markdown).** (DOES NOT APPLY TO COMMENTS IN CODE. ONLY STANADLONE PROSE MARKDOWN DOCUMENTS)
    Let paragraphs flow as full lines unless a specific syntax requires line breaks.

-----

## 3. Definitions

Define structural syntax before building arguments on top of it.

Good pattern:

- define the form
- assign it a formal noun
- use that noun consistently afterward

Example:

- `@name.d/` inside `@core/` is a **module-correspondent package**
- `aliases.d/` inside package-space is a **routing signal**

Do not alternate freely between:

- the raw syntax
- an ad hoc paraphrase
- an undefined near-synonym

If a term is worth using, define it. If it is not worth defining, do not use it.

-----

## 4. Allowed and Disallowed Language

### 4.1 Use

- direct rule statements
- ordinary nouns
- defined technical terms
- short transition sentences that mark scope or sequence
- tables when they clarify category or contrast
- numbered procedures when order matters

### 4.2 Avoid

- metacommentary about the draft, revision, or editorial process
- handoff language
- apologies or drafting residue
- philosophical expansion where a plain sentence would do
- repeated raw pattern language when a formal term already exists
- weak phrases such as "kind of", "roughly", "more or less", or "basically" in specifications
- process narration, self-justifying scaffolding, or epistemic throat-clearing when the checked result can simply be stated

Bad:

- "This revises the earlier wording..."
- "What this really means is..."
- "In a sense..."
- "To be precise..."
- "It's worth noting that..."
- "Let me distinguish..."

Good:

- "Hidden cross-projection occurs only when the corresponding `@core` package exists."

Bad:

- "This section explains how to think about..."
- "This document is not an architecture spec."
- "Use this section when..."

Good:

- "Read authority docs before proposing semantic changes."
- "Quote the exact sentence under discussion."

-----

## 5. Invariants and Constraints

An invariant is an absolute rule, not a mood or tendency.

Write:

- "A package cannot contain a module."
- "Outside `@core/` scopes, the `.d` suffix on a prefixed name carries no module-layer meaning."
- "Bare words are resolved at plan time."
- "Lifecycle hooks are evaluated at apply time."

Do not write:

- "Packages generally do not contain modules."
- "The system tends to treat..."

If the rule is local, say where it applies. If the rule has an exception, state the exception explicitly.

If the rule depends on resolution, evaluation, or freezing, state when it happens. Do not leave timing implicit.

Do not add negative anti-rules merely to make the system sound closed.

-----

## 6. Structure Before Action

Documentation should usually appear in this order:

1. Definitions
2. Static structure
3. Dynamic behavior
4. Invariants
5. Worked examples

This order may be adjusted for short documents, but the distinction must remain clear.

Static structure answers:

- what exists (ontology)
- how it is named
- how pieces relate (mereology)

Dynamic behavior answers:

- what runs
- in what order
- with what effect

Do not collapse these into one drifting section unless the document is extremely short.

-----

## 7. Examples and Diagrams

Examples should annotate the real structure being described.

Use examples to:

- ground a definition
- show a boundary
- show a before/after relation
- make a projection or routing rule concrete

When a system has multiple co-equal representations, examples must not silently privilege one view. Rotate registry seat, projected view, reverse-projected view, and correspondent seat where relevant, or explicitly label which view is shown.

If every worked example in a section uses the same ownership direction, path form, or seat, check whether the prose claims co-equality that the examples silently contradict.

Diagrams should clarify ordering, hierarchy, or data flow. They should not decorate the page.

Use:

- tables for categories and contrasts
- numbered lists for procedures
- diagrams for sequence or layered relationships
- annotated trees for filesystem structure

-----

## 8. Lexicon Discipline

Use one term for one meaning (the Flaubert standard).

If two ideas differ, give them different names.

If one idea appears in two structural forms, define the common idea and then state the form-specific rule.

If two states are architecturally co-equal, say so explicitly. Do not smuggle hierarchy in through terms like "preferred", "normal", "legacy", or "tolerated" unless the design actually defines a hierarchy.

When a metaphorical or compressed term is useful, its operational definition must be plain.

Evocative references are acceptable when they function as high-yield compression for capable readers or agents. They must reinforce an already stated rule, not replace one.

For example:

- a term like `facet` is acceptable only if the document defines exactly what counts as a facet and what does not
- a term like `module map` should be avoided if a plainer and more accurate term such as `set of canonical modules` or `canonical module tree` exists

The document should never depend on the reader sharing the author's intuition about a term.

-----

## 9. Revision Standard

A good revision does at least one of these:

- defines a term that was previously used ad hoc
- replaces observational language with a rule
- separates static structure from dynamic behavior
- removes draft residue or private shorthand
- makes a section understandable without external context
- completes an ontology rename and removes transitional residue rather than stopping at global substitution
- replaces stale conflicting text in the body instead of appending a corrective paragraph beside it
- identifies whether a needed update is a contradiction, omission, clarification, or migration note and integrates it accordingly

A bad revision does any of these:

- adds jargon without defining it
- narrates the act of revising instead of stating the rule
- increases abstraction without increasing precision
- preserves ambiguity for the sake of style
- drops distinctions or content that the original text was already carrying correctly
- justifies a draft's robustness solely by citing the same draft instead of checking authority docs, implementation reality, or explicit design intent

-----

## 10. Minimum Check Before Merging

Before accepting a documentation change, verify:

- terms are defined before heavy reuse
- each section can be read on its own
- rules are written as rules
- examples illustrate a stated rule
- boundaries and non-applicability are explicit
- no paragraph depends on invisible context from chat or draft history
- the revision did not lose semantic content or introduce a regression

If a sentence sounds like meeting notes, it is not ready.
