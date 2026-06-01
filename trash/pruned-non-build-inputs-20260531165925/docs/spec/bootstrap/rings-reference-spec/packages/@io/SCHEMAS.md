# SCHEMAS.md

## Core terms

- A **schema** is a definition of how a command accepts input and options, and how those are interpreted before execution.

- A **backend** is a **named implementation family** that implements one **shim** for each public command. Each public command shim may be implemented using one (sub)command (e.g. `gum filter`) of an executable `gum`, separate executables (`bat`,`glow`), or shell-native code.

In other words:

```txt
gum backend      → may call gum filter
crazy backend    → may call different binaries per leaf
native backend   → calls no external binary
```

So for `io::in::filter`:

```txt
backend implementation family name = gum
backend executable command  = gum filter
backend shim     = code that maps a normalized input to the backend executable command
```

- **Normalized** means: parsed input is represented in a consistent form: named options as `key=value` pairs, together with any remaining, validated positional arguments.

- A **public command** is the interface exposed to the user. A schema defines this interface but does not execute it.

- The **leaf** of a public command is the concrete implementation of that public command. It only implements `--help`, dispatching everything else to the **backends**.

- A **worked (public) command** is a public command whose interface has been fully derived in [`IO-DERIVATION-PLAN.md`](./IO-DERIVATION-PLAN.md), including its public options, private options, and supported backends.

## Purpose of a schema

A schema defines the interface and normalization rules for a backend-mapped public command. It does not implement the command logic.

It specifies:

1. Accepted input sources

   - stdin, argv, or both
   - whether input is required
   - how input is split (e.g., newline-delimited records)

2. Supported options

   - option names
   - data types (string, boolean, integer)
   - default values
   - environment variable fallbacks

3. Visibility of options

   - public: part of the command’s external interface
   - private: internal or auxiliary, not part of the primary interface, passed through to the backend unprocessed.

4. Normalized output structure

   - how parsed input is represented in a consistent normalized form
   - named options are emitted as `key=value` pairs
   - remaining validated positional arguments stay positional

5. Backend eligibility constraints (conditional narrowing)

   - how specific options restrict which backends are allowed to run
   - defined per-option using `--eligibility`
   - evaluated after parsing, before dispatch

Backends (x, y, z) are separate implementations of the same public command, e.g.
`gum filter` and `fzf` are backend executable commands for backends `gum` and `fzf`.
The schema ensures all backends uniformly receive the same normalized representation, straightforwardly mappable to concrete executables / functions within the shims.

---

## Structure of a schema

### 1. Command identity & input specification

#### Command identity

- Example: `io::_backend::define "io::in::choose"` declares the schema for the public command `io::in::choose`.

#### Input specification (`--input`)

Use `--input` to declare where command input may come from.

The value may be:

- `stdin`
- `argv`
- both, written together as `"stdin argv"`

`--delimiter` and `--required` belong to that same input declaration. They are not separate top-level schema directives.

If `--input` is only `argv`, do not add `--delimiter`. There is no stdin stream to split.

- Input configuration (full list):

  - `--input "stdin argv"`: both sources are allowed
  - `--delimiter '\n'`: input is split into records by newline
  - `--required yes`: at least one record must be present

These are written together as one grouped input declaration:

Example:

```sh
--input "stdin argv" --delimiter '\n' --required yes
```

This encompasses the diversity of expected input shapes.

This means:

- input may come from standard input, command arguments, or both
- newline splits standard input into records
- the command expects at least one input record

Another example:

```sh
--input argv --required no
```

This means:

- input comes from command arguments only
- no delimiter is applied
- input is optional

---

### 2. Positional groups (`--positional`)

Use `--positional` to declare a **positional group**: a sequence of leading `argv` values, i.e. positional arguments `${@}`, collected by **arity** (number of arguments). A positional group consumes its values from **argv** according to `--arity` (arguments may thus only be members in at most 1 positional group)

Example declaration:

```
    --positional \
        --arity <number> 
        --type <type> 
        --default <default-value(s)>
        --maps[-to] <backend-option>
```

- `--arity`, `--type`, and `--default` are optional.
- Default `--arity` is 1 (i.e. the positional group consumes the next argument (`argv`)) (§2.1).
- Default `--type` is `string` (§2.2)
- `--enum` is unset by default. When set, constrains accepted input to listed values (§2.3).
- `--default` is unset by default (§2.4).
- `--maps[-to]` is unset by default. When set, maps the positional arguments of the group to the specified `<backend-option>` (§2.5).

The group is parsed and type-checked. If unmapped, it remains positional. If mapped, it is consumed from `argv` (not passed positionally) and re-included as part of the **normalized output**.

#### 2.1 Arity (`--arity`)

`--arity <value(s)>` declares the required number(s) of arguments for a positional group, which it consumes.
> _`--arity` also constrains the number of parameters for an option (§3)._

- `<value(s)>` is a particular arity (an `integer`) or multiple arities.
- any separator may be used (`,`, space, `;`, `|` ...) to separate arities.

Examples (all equivalent):

- `--arity "1,2,4"`
- `--arity "1 2 4"`
- `--arity "1|2|4"`

A parsed list of positional arguments must match one of the allowed lengths.

#### 2.2 Type (`--type`)
  
- `--positional` defaults to `string`
- `--type <type>` is only needed when you want a non-`string` type, such as `integer`. Do not add `--type` unless you want to explicitly constrain to a different type.
- determines validation + conversion (performed _once_ centrally)

#### 2.3 Enum (`--enum`)

`--enum <value> [value ...]` in a `--positional` group declaration restricts which leading positional parameters the group may capture to one of the listed values. If the next argument does not match any member of the `--enum`, the value is not captured by that group. It is checked after `--type`, if supplied.

When `--arity` specifies more than one positional argument, each parsed argument must appear in the `--enum` list.

```sh
io::_backend::define "io::layout::align" \
    --input "stdin argv" --required yes \
    --positional --enum left center right --maps-to align
```

#### 2.4 Default (`--default`) values

- `--default <default-value(s)>` (optional)
- Records one or more default values for the positional group.
- Unset by default. When set, will be used when fewer arguments than required by `--arity` are provided.

> _If `--arity` is present, `<default-value(s)>` will be split (if provided as a single `string`) and parsed based on arity._

#### 2.5 Internal renaming (`--maps` / `--maps-to`)

`--maps` and `--maps-to` declare the backend option(s) the normalized output may optionally be mapped to.

If `--maps` / `--maps-to` is set:

- the positional group is consumed from argv
- the group is arity-checked and type-checked
- the values are emitted as the named `key=value` option
- the consumed values are not passed positionally

Example:

- CLI positional-group: `${1} ${2} ${3} ${4}`
- Backend option flag: `padding`

Use this when a backend option takes arguments equivalent to a positional group:

```sh
    io::layout::margin $1 $2 $3 $4 "$text"
    io::layout::margin --margin $1 $2 $3 $4 -- "$text"
```

`--maps` and `--maps-to` may take more than one name when a positional group corresponds to more than one backend option name. If `--maps` / `--maps-to` is omitted:

- the positional group is still consumed from argv
- the group is still arity-checked and type-checked
- the values are passed positionally after `--`
- no `key=value` option is produced for that group

`--maps-to` is what turns a captured positional group into a named backend option.

---

#### 2.6 Example: concrete example of a schema using positional groups

```sh
io::_backend::define "io::layout::margin" \
    --input "stdin argv" --required yes \
    --positional --type integer --arity "1,2,4" --maps-to margin \
    --option: "margin" --type integer --arity "1,2,4" \
        --default "0" \
        --env RINGS_IO_LAYOUT_MARGIN LAYOUT_MARGIN
```

- `--margin` accepts the same arity from either route
- both the positional group and the public option map to a backend command's `--margin`

---

### 3. Options (`--option|--option:`)

Use `--option` for boolean flags and `--option:` for value-taking options.

- `--option` declares a boolean public option (flag). Defaults to public.
- `--option:` declares an option that takes a value. Defaults to public.

Add `--private` to either to mark it private.

#### 3.1 Public options

Public options are part of the main command interface. They are the options that callers are meant to use and rely on, and documented in user-facing `--help`.

#### 3.2 Private options

Private options are for backend-specific behavior. They are recognized and passed through, but they are not part of the main command interface.

`--private`:

- option is parsed but not part of the primary interface
- private options are recognized and passed through

Private options usually do not need:

- defaults
- environment variables
- type conversion

In most cases, the schema only needs to say:

- the option exists
- whether it takes a value

---

Each option declaration includes:

#### 3.3 Name

- `--option <name>`
  - defines a public boolean option; i.e. a flag (e.g., `--multi`, `--exact`)

- `--option: <name>` (value-taking variant)
  - defines a public argument-taking option, (e.g., `--margin <value>`)

- `--option:` accepts the same attributes as `--positional`: namely `--arity`, `--type`, `--enum`, `--default`, and `--maps-to`.
  - default **arity** to `1` and **type** to `string` respectively, unless otherwise specified. `maps-to` default maps to the synonymous backend option (see §3.8).

Each `--option` / `--option:` declaration may include additional option attributes such as `--alias`, `--aliases`, `--env`, and `--eligibility`. These are all part of one option declaration, not separate top-level arguments to `io::_backend::define`.

#### 3.4 Optional arity (`--arity`)

`--option:` may also use `--arity <value(s)>`.

As in §2.1,

- `<value(s)>` is a particular arity (`integer`) or arities (`--arity "1 2 4"`).
- Any separator may be used (`,`, space, `;`, `|` ...) to separate arities

For options this means:

- the number of parameters must match any specified `--arity`
- all values must always match `--type`

#### 3.5 Optional type (`--type`)
  
Determines validation + conversion (performed _once_ centrally)

- `--option` defaults to boolean.
- `--option:` defaults to string.

Per §2.2, Do not add `--type <type>` unless you expect a different type, such as `integer`:

```sh
io::_backend::define "io::layout::width" \
    --option: "width" --type integer
```

#### 3.6 Optional enum (`--enum`)

Analogous to §2.3, `--enum <value> [<value> ...]` in a `--option:` declaration restricts the accepted option parameters to one of the listed `--enum` values. It is checked after `--type`, if supplied.

In contrast to `--positional` groups, if the `--option:` receives any parameters that do not match any member value of the enum, the command fails.

When `--arity` specifies more than one potential value, each value must match a member of the enum.


```sh
io::_backend::define "io::layout::align" \
    --input "stdin argv" --required yes \
    --positional --enum left center right --maps-to align \
    --option: "align" --enum left center right --default left --alias alignment \
    --option: "width" --type integer
```

#### 3.7 Optional default (`--default`) values

As in §2.4,

- `--default <default-value(s)>` (optional)
- `--default` records the option's `<default-value(s)>`, optionally split by `--arity`.

#### 3.8 Optional internal renaming (`--maps` / `--maps-to`)

As in §2.5, `--maps[-to]` maps the public option to one or more backend options. This is optional for named options: by default, each public option maps to the backend option with the same name.

`--maps` and `--maps-to` are used when the backend option name(s) differ from the CLI name:

Example:

- CLI flag: `select-if-one`
- Backend flag: `auto_pick_single`

```sh
--option "select-if-one" --maps-to "auto_pick_single"
```

If the option names are the same, do not write a mapping. Just do this:

```sh
--option: "prompt"
```

Not this:

```sh
--option: "prompt" --maps-to prompt
```

Also as in §2.5, `--maps` and `--maps-to` may take more than one name when the public option corresponds to more than one backend option.

#### 3.9 Optional additional CLI spellings (`--alias`, `--aliases`)

Use `--alias` to accept more than one CLI spelling for the same option.

`--aliases` is also accepted. Both forms mean the same thing.

Alias names are bare alternative option names, without the `--` prefix. Do not redundantly repeat the canonical name as an alias.

- `--alias <name> [name ...]` adds one or more extra spellings
- `--aliases <name> [name ...]` does the same thing
- these are written on the same `--option` or `--option:` declaration as the rest of the option attributes
- in schemas and examples, prefer `--alias`
- alias names are written without the `--` prefix

All spellings refer to the same option.

This means:

- the same validation rules apply
- the same default and environment fallback rules apply
- the same normalized field is produced
- backends receive the same option regardless of which spelling the caller used

Example:

```sh
--option: "root" --alias base
```

This accepts both `--root` and `--base`. Both fill the same option.

Private options use the same mechanism:

```sh
--option: "file" --private --alias path
```

This accepts both `--file` and `--path` as spellings for the same private option.

`--alias` adds CLI spellings.
`--maps-to` changes the backend-facing name used in the normalized output.

#### 3.10 Optional environment variables (`--env`) (coupled overrides)

- `--env <ENV_VAR> [ENV_VAR ...]` (optional); environment variable(s) fallback;
- `--env` records the environment variables that may supply a value for the same option.
- if set, will be used when the option is not explicitly provided by caller
- evaluated in order

 > If the option is not passed on the command line, the parser checks the `ENV_VARs` as they appear in the list—earlier taking precedence—then the fallback default value.

#### 3.11 Optional backend eligibility constraints (`--eligibility`)

- `--eligibility` (optional, as needed)
- restrict which backends may run when this option participates in resolution

Form:

```sh
--eligibility "when=always|present allow=id,id,..."
```

Rules:

- The value is a single string.
- It contains two assignments separated by a space:

  - `when=...`
  - `allow=...`
- Backend identifiers under `allow=` are comma-separated.
- This syntax is internal to the schema. It is not related to CLI flag syntax.

Meaning:

- `allow=id,id,...`

  - lists the backend identifiers that remain allowed when this rule is used

- `when=always`

  - use this whenever the option has a parsed value
  - that includes values from:

    - command-line arguments
    - environment variables
    - default values

- `when=present`

  - use this only when the user explicitly passed the option on the command line
  - values supplied only by environment variables or defaults do not limit backend choice

Effect:

- The dispatcher looks at every parsed option with an `--eligibility` rule.
- Each rule may narrow the allowed backend list.
- If more than one rule applies, the dispatcher keeps only the backends allowed by all of them.

Example (from `filter`-style usage):

```sh
--option: "query" --eligibility "when=present allow=gum,fzf"
--option "filter" --eligibility "when=always allow=fzf,native"
```

Meaning:

- `query` limits backend choice to `gum,fzf` only if the user passed `--query`
- `filter` limits backend choice to `fzf,native` whenever it has a parsed value

#### 3.12 No conflict with convergent backend-option mappings

If both a positional group and/or multiple options map to the same backend option, there is no conflict: the last argument occurring in `argv` takes precedence:

`io::layout::margin --margin 3 --margin-alias 0 -- 1 2` # `1 2` takes precedence over `0` which takes precedence over `3`.

#### Examples

Use `--option` for a private flag:

```sh
--option "ordered" --private
```

Use `--option:` for a private option that takes a value:

```sh
--option: "input-delimiter" --private
```

More examples:

```sh
--option: "prompt" --default "Choose:"
```

```sh
--option: "limit" --type integer --env RINGS_IO_IN_CHOOSE_LIMIT IO_CHOOSE_LIMIT
```

```sh
--option "default-yes" --default no
```

### 4. Style options (`--style`)

Use `--style` to specifically declare a style option. Defaults to public.

- `--style <style-name>`
  - groups related parameters (e.g., display attributes) indexed by `.foreground` and `.background` fields. E.g. `--style "name"` implies (public) options `--name.foreground` and `--name.background`.
  - Style options may also be marked `--private`. They are then passed through without any validation like any private option.
  - when a style is private, the generated style fields are private too
  - by default, styles are part of the public interface; add `--private` only when the generated style fields must not be part of the primary public surface

#### 4.1. Style examples

Example:

```sh
--style "cursor"
--style "header"
--style "item"
--style "selected"
```

This avoids repeating separate foreground and background option declarations by
hand.

Private styles work the same way:

```sh
--style "selected" --private
--style "match" --private
```

### 5. SKILL : Defining a schema and implementing the leaf and backend shims

#### 5.1 First Step : Defining the schema

1. Assign a command identifier

   - e.g., `io::widgets::do-thing`

2. Define input behavior

   - source(s): stdin, argv, or both
   - whether input is required
   - delimiter if input is structured
   - write these together as one `--input` declaration

3. Define positional groups when needed. Use `--positional` with optional `--type`, `--arity`; as well as `--maps-to` (if mapping the positionals to a backend option is desired).

4. Define public options

   - name, defaults
   - add `--type` only when the default type is not right
   - optional environment fallbacks
   - optional backend constraints (`--eligibility`)
   - optional `--maps` / `--maps-to` when the backend name differs

5. Define private options

   - mark them as private
   - use `--option` for private flags
   - use `--option:` for private options that take a value
   - keep them short unless they truly need more fields

6. Define style options if needed

   - i.e. `.foreground` `.background`-indexed parameters with `--style`

#### 5.2 Next steps : Implementing the leaf and backend shims

When implementing the corresponding **leaf** & **backend shims** for a **worked** **public command** remember:

- each **public command** has exactly one **leaf**
- each backend implements exactly one **shim** for that public command
- each **shim** _consumes_ the same **normalized input**
- each **shim** _implements_ its own execution dispatch logic (precise wrapping of backend commands)

---

### 6. Minimal schema skeleton

A minimal schema may define only argv input, a small set of public options, and public styles.

Example:

```sh
io::_backend::define "io::example::minimal" \
    --input argv --required no \
    --option: "prompt" --default "Confirm?" \
    --option "default-yes" \
    --style "prompt" \
    --style "selected" \
    --style "unselected"
```

This shows:

- argv-only input with no delimiter
- a string option and a boolean option, both written without redundant type boilerplate
- styles that are part of the public interface

Larger commands add stdin input, delimiter, private options, eligibility, and mappings as needed.

### 7. Unified example

The current `choose` schema looks like this:

```sh
io::_backend::define "io::in::choose" \
    --input "stdin argv" --delimiter '\n' --required yes \
    --option: "prompt" --env RINGS_IO_IN_CHOOSE_PROMPT IO_CHOOSE_PROMPT \
    --option: "header" --env RINGS_IO_IN_CHOOSE_HEADER IO_CHOOSE_HEADER \
    --option: "limit" --type integer --env RINGS_IO_IN_CHOOSE_LIMIT IO_CHOOSE_LIMIT \
    --option "multi" --env RINGS_IO_IN_CHOOSE_MULTI IO_CHOOSE_MULTI \
    --option "select-if-one" --env RINGS_IO_IN_CHOOSE_SELECT_IF_ONE IO_CHOOSE_SELECT_IF_ONE --maps-to auto_pick_single \
    --option: "input-delimiter" --private \
    --option: "output-delimiter" --private \
    --option: "label-delimiter" --private \
    --option "ordered" --private \
    --option "show-help" --private \
    --option: "timeout" --private \
    --option: "cursor-prefix" --private \
    --option: "selected-prefix" --private \
    --option: "unselected-prefix" --private \
    --option: "selected" --private \
    --option "strip-ansi" --private \
    --option: "padding" --private \
    --style "cursor" \
    --style "header" \
    --style "item" \
    --style "selected"
```

This fully defines the public interface shown by `leaf --help`s, along with private backend pass-through options.

This example shows the current schema language:

- grouped `--input`
- public options with inferred default types, plus explicit `--type` only where needed
- `--maps-to` when the backend name is different
- `--option:` for private options that take a value
- plain `--option ... --private` for private flags
- grouped style settings
- (when present) per-option backend narrowing via `--eligibility`

## Summary

A schema defines the input format, options, normalized representation, and conditional backend constraints for a command. Backends implement execution using that normalized representation.
