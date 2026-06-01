# Do not do any of this:

- Do not write a plausible (read: bullshit I 100% reject) local Bash implementation from the desired behavior. Copy upstream first, then translate.
- Do not “simplify” upstream algorithms before the upstream body is present in the rings target.
- Do not use Bash 5 idioms as a license to replace the algorithm. They are only allowed as obvious mechanical edits after copying upstream.
- Do not add tests, lints, maps, lanes, or closure checks as the work product when the missing thing is a body port.
- Do not reclassify map rows to make the map clean instead of porting the upstream symbol.
- Do not call something dropped because there is “no current caller” when upstream exposes it as a utility API.
- Do not create facades, registries, queues, stores, or wrapper layers that upstream does not have.
- Do not reshape packages or aliases as busywork when the blocker is a missing faithful function body.
- Do not “fuse” upstream private helpers away unless the copied upstream logic is visibly present and the fusion is a mechanical translation.
- Do not make tests define behavior. Tests verify copied upstream behavior; they do not authorize invented behavior.
- Do not claim closure from breadth, counts, local unit tests, or zero unclassified symbols.
- Do not edit docs/status prose instead of doing the port.
- Do not run broad scripted rewrites without an atomic recovery point.
- Do not narrate diligence as a substitute for results.
- If the upstream body does not fit the current boundary, reshape the boundary or stop and report the blocker. Do not bridge it with original code.

> **Open the upstream function, copy the body, translate names and calls, preserve semantics. Everything else is secondary.**

No translation, upstream provenance, or migration comments allowed. Only architecture comments: package shape, functional purpose, justified design choices, high-yield concerns, caveats and rationale. All implementation details must pertain to its functional role (what does it do? why? how does it fit in the system?). Avoid jargon, unearned abstractions (don't use consume if the resource isn't destroyed), and undefined high-level language ("provisions", "consumes", "the calling frame") that don't clearly map to the actual code or apply in a Bash context. Do not mention this file.

Use `/usr/local/bin/trash` or `trash` or `mv <file> ./trash`.