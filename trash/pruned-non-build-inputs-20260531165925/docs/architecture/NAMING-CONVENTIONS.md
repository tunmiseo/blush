# Namespace Derivation Conventions

> **Status: active reference (BLE-local restatement).** Moved from `notes/naming-conventions`
> on 2026-05-29. The authority for namespace derivation and singleton/promotion rules is the
> rings spec [`PACKAGES.md`](../rings/PACKAGES.md) §3 and [`CONSENSUS.md`](../agents/CONSENSUS.md)
> §6. This file is a concise BLE-local restatement; where it and those documents differ, they win.

The namespace of a function (`a::b::c::*`) is rigidly tied to the filesystem hierarchy of the packages (`@a/@b/@c`). There is a strict, unidirectional mapping from package path to namespace scope. 

**Rule 1: Path implies Namespace**
If a file exists at `src/@a/@b/@c/c.bash`, its namespace scope **must** be `a::b::c::`. The namespace is derived directly from the `@`-prefixed directory structure. 

**Rule 2: Semantic Collapsing is Allowed (Ancestral Hosting)**
You do not strictly need the `@c` directory to use the `a::b::c::` namespace, provided that the file defining those functions is hosted within the direct ancestral chain that owns that semantic. 
For example, placing the file `c.bash` directly inside `src/@a/@b/` is completely valid. It is an uncollapsed singleton that still implies the `a::b::c::` namespace because it sits correctly under `@a/@b` and acts as the "file form" of the `@c` subpackage.

**Rule 3: No Divergent Hosting (Conflicts Forbidden)**
You cannot define a namespace in a package branch that contradicts the namespace. 
For example, you cannot define `ble::decode::send_unmodified_key::*` inside `src/@ble/@decode/@widget/widget.bash`. The `@widget` package scope (`ble::decode::widget::`) is completely divergent from the `send_unmodified_key` scope. To resolve this, `send_unmodified_key::*` must either be moved to its rightful ancestral path (e.g., `src/@ble/@decode/send_unmodified_key.bash`) or folded properly into the `@widget` namespace if `@widget` is meant to own that semantic.

**Rule 4: Singleton Collapse is the Default**
By default, if a subpackage consists of only a single file, it should be collapsed into its parent directory. 
If `@a/@b/@c` contains only `c.bash`, you should collapse it into `src/@a/@b/c.bash`. The file `c.bash` acts as the definitive "file form" of the `@c` package. It still strictly implies the namespace `a::b::c::`.

**Rule 5: Promote (Uncollapse) when adding artifacts**
A collapsed singleton must be "promoted" into a full subpackage directory (`@c/`) the moment it gains additional artifacts. 
If `src/@a/@b/c.bash` needs to be split into a public API (`c.bash`) and private helpers (`_c.bash`), or if it requires supplementary files, it must be promoted to `src/@a/@b/@c/c.bash` and `src/@a/@b/@c/_c.bash`. 
Promotion is always identity-retaining—the primary file remains `c.bash`, it never becomes `main.bash`.

**Rule 6: Exemptions to Singleton Collapse**
Certain directory types are strictly exempted from being collapsed into singletons, even if they contain only one file. These include:
- `config.d/` (Application configuration tree)
- `meta.d/` (Package metadata)
- `data.d/` (Static data payloads)

In summary: **Start with a collapsed singleton (`c.bash`). Promote it to a directory (`@c/c.bash`) only when you need to group multiple files under that specific package scope.** 

> **Namespace scopes are not arbitrary labels; they are structural reflections of the package tree.** Hyphens in scopes like `async-read` or `kill-ring` aren't just syntax errors; they indicate that the codebase is pretending `@async-read` or `@kill-ring` are valid packages, meaning we must fix the namespace and ensure they live in the correct ancestral file path (like we did by placing `async_read.bash` directly under `@edit`).