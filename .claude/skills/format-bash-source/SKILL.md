---

argument-hint: "[optional *.sh file or folder paths]"
description: Format Bash (*.sh) files to match .claude/CODE_STYLE.md, the repository's source of truth for shell style. Use when the user asks to format, fix, or apply the code style to shell scripts. Runs in two modes — with no arguments it formats every *.sh file modified locally on the current branch (both committed on branch and not yet committed changes); with file or folder paths as arguments it formats those targets instead.
name: format-bash-source

---

# Format Bash Source

Reformat Bash scripts so they comply with [.claude/CODE_STYLE.md](../../CODE_STYLE.md), the authoritative style guide for every `*.sh` file in this repository.

## Load the Style Guide

Read `.claude/CODE_STYLE.md` in full before touching any file. It is the single source of truth; every rule you apply must come from it. Do not invent rules or rely on generic Bash conventions that the document does not state. If the document and a file disagree, the document wins.

## Resolve the Target Files

There are two modes. Pick the mode from whether arguments were provided.

### Default Mode (No Arguments)

Format every `*.sh` file modified locally on the current branch — both the changes already committed on the branch (relative to `master`) and the changes not yet committed. Collect them with:

```bash
{
	git diff --name-only --diff-filter=ACMR master...HEAD
	git diff --name-only --diff-filter=ACMR
	git diff --name-only --cached --diff-filter=ACMR
	git ls-files --others --exclude-standard
} | sort --unique | grep '\.sh$'
```

This covers commits made on the branch (versus `master`), unstaged changes, staged changes, and new untracked scripts. If the branch's base is not `master`, substitute the correct base branch. If the list is empty, report that there are no locally modified `*.sh` files and stop.

### Argument Mode (Paths Provided)

When the skill is invoked with arguments, treat each argument as a file or a folder:

- A path ending in `.sh` is formatted directly.
- A folder is expanded to every `*.sh` file under it:

	```bash
	find "${path}" -type f -name '*.sh'
	```

- Ignore arguments that resolve to no `*.sh` files, but report each one that was skipped so the user knows.

The arguments passed to this skill are: ${ARGUMENTS}

## Format Each File

For every target file, read it and apply the rules from `.claude/CODE_STYLE.md` using `Edit`. Make only style changes — never alter the script's behavior, logic, or output. The checks to enforce include (this is a reminder, not a replacement for reading the document):

- **File layout**: shebang, blank line, sorted `source` block, blank line, function definitions, single trailing `main` invocation, no blank last line; `_`-prefix for internal files.
- **Functions**: `function name` form (no `()`), `snake_case`, verb prefixes, `_`-prefix for local functions, globals declared before locals.
- **Variables**: `UPPER_SNAKE_CASE` for globals/env, `lower_snake_case` for locals (`_UPPER` when shared across local functions), `local` declarations for every lowercase variable a function assigns, including `for` loop variables and `read` targets (declared right before the loop), no spaces around `=`, always braced and quoted (`"${var}"`), the whole parameter quoted when a variable is adjacent to literal text (`"release.${name}.pom"`, not `release."${name}".pom`; literal kept outside quotes only for a glob or for a Git URL/ref/refspec/tag passed to `git`), locals declared close to first use rather than batched at the top, the enumerated Bash-specific parameter expansions (`${var##*/}`, `${var%/*}`, `${var##*:}`, `${var%.*}`, `${var#prefix}`, `${var/a/b}`) rewritten to the legible equivalents listed in CODE_STYLE.md (every other expansion left unchanged), `$((...))` arithmetic with no inner spaces, `$(...)` over backticks, a single command substitution, parameter expansion, or arithmetic expansion left unquoted when it is the entire right-hand side of a bare `x=`, `local x=`, `export x=`, `readonly x=`, or `declare x=` assignment, no trailing `;` at the end of a `$( ... )`.
- **Sorting**: `source` lines, function definitions, and same-location local variable declarations sorted case-sensitively (`../` before `./`). This is mechanical, not a judgment call — apply it even when the current order looks like a deliberate "template" and even when it means moving whole function bodies. Functions sort alphabetically with globals before locals and `main` in its alphabetical position (it is not pinned first or last); reordering definitions never changes behavior, since execution order comes from the calls in `main`, not the definition order.
- **Commands**: `awk` parameters wrapped in `""` (the field separator counts as a parameter — rewrite the attached `-F=` / `-Fx` forms to `-F "="` / `-F "x"`) and `awk` instructions in `''`, `sed` regex expressions in `""` (even when they contain `$`) with the program always passed via `--expression`, never as a bare positional argument (`sed --expression "s/a/b/"`, not `sed "s/a/b/"`) — this applies to standalone single-script `sed` and to `sed` nested in a command substitution; long form of flags preferred (e.g. `xargs --null`, not `xargs -0`); flags ordered alphabetically whether inline or broken, except order-dependent ones (`find` primaries, repeated `sed --expression`, `sed`'s `--regexp-extended`, which must precede `--expression`, and `zip`'s `-i`/`-x` include/exclude filters, which trail the input file list they act on rather than sorting in with the other flags); commands broken one argument per line with positionals last (e.g. `sed --expression "..." --in-place file`) when they carry three or more flags (e.g. `curl`) or when they exceed eighty columns (counting a tab as four columns) and carry at least two flags to spread, except a command whose syntax pins a positional first (`find`'s path), with an option and its value counting as one flag, positionals counting toward neither threshold, anything else staying inline, the break applying even inside `if` / `if !` conditions, and a line being left alone when it is still over eighty columns after breaking because a single argument is itself that long; put a space between a redirection operator and its target (`&> /dev/null`, not `&>/dev/null`), but `2>&1`, `>&2`, and `<(...)` / `>(...)` stay attached.
- **Control flow**: `then` (including after `elif`) and `do` on their own line, single-bracket `[ ... ]` tests by default but `[[ ... ]]` for pattern/regex matching, `${BASH_SOURCE[0]}` comparisons, lexicographic `<`/`>` string comparisons, and numeric comparisons (`-eq`, `-ge`, etc.) — but a numeric comparison whose operator is held in a variable (`[ "${a}" "${operator}" "${b}" ]`) stays single-bracket, since `[[ ... ]]` needs a literal operator — `==` for strings, aligned multiline conditions, no parentheses around a single boolean function, variable, command, or pipeline (parentheses only for combined conditions, with `(( ))` arithmetic and awk/jq program `if (...)` left untouched).
- **Indentation/spacing**: tabs only, single blank line between logical statements, no blank line just inside `{` / `}`.
- **Pipelines**: long pipelines and `curl`-style commands broken across lines with `| \` continuations indented one tab; a space after `$(` when a pipeline or command is broken inside a command substitution; a compound command (`while`, `for`, `until`, `if`) ending a broken pipeline taking the continuation indent like any other stage, with its `do`/`done` (or `then`/`fi`) and body aligned to that stage rather than left at the opening statement's indent.
- **Return codes**: named `LIFERAY_COMMON_EXIT_CODE_*` constants, quoted (but boolean functions return bare `0`/`1`); a `trap` body single-quoted with the constant quoted inside it (`trap 'return "${LIFERAY_COMMON_EXIT_CODE_BAD}"' ERR`).
- **Comments / shared helpers**: `#`-delimited comment blocks, `lc_*` helpers over reimplementation. Do not convert between `echo` and `lc_log` — that choice is semantic and is left to the author, not the formatter.

Skip `.claude/CODE_STYLE.md` itself and any non-`*.sh` file.

## Verify Idempotency

The formatter must be idempotent: a second run on an unchanged tree must produce **zero** edits. To guarantee this:

- Only edit code that *strictly violates* a rule you can cite by name. Never replace one compliant form with another equally-compliant form.
- After editing a file, rescan it. If a second pass would make any further change, either make it now or recognize that the triggering rule is too subjective to auto-apply — and leave the code alone.
- The "too subjective" exception is narrow: it covers only rules that genuinely require judgment, never deterministic ones. Sorting (`source` lines, function definitions, local declarations), bracket choice, quoting, and the enumerated parameter-expansion rewrites are all mechanical and must always be applied — do not skip them because the change is large (e.g. moving a function body) or because the existing order resembles an intentional layout.

### Verification Sweep

Reading each file is the primary check, but it is easy to miss a class of violation across many files — especially when the work is split across several passes or subagents that may apply a rule unevenly. After editing, rescan the target files with these greps and confirm every remaining hit is intentional. Each is a deterministic rule, so a hit is either a real violation to fix now or an explainable exception (and never both):

```bash
# Parenthesized conditions — every hit must be a combined (&& / ||) condition, a
# `(( ))` arithmetic evaluation, or awk/jq program syntax; a single command,
# pipeline, function, or variable wrapped in ( ) is a violation.
grep -nE '\b(if|elif|while) +!? *\(' "${files[@]}"

# Quoted single-expansion scalar RHS — `local x="${1}"` / `x="$(...)"` / `x="$((...))"`
# must be unquoted; this includes export/readonly/declare assignments.
grep -nE '^[[:space:]]*(local |export |readonly |declare (-[A-Za-z]+ )?)?[A-Za-z_][A-Za-z0-9_]*="(\$\{[A-Za-z0-9_@#?]+\}|\$\(\([^"]*\)\)|\$\([^")]*\))"[[:space:]]*$' "${files[@]}"

# A variable adjacent to a literal path must be quoted as one parameter
# (`"${dir}/file"`, not `"${dir}"/file`). Every hit must be a glob (`"${dir}"/*.zip`)
# or a git URL/ref — otherwise merge the quotes.
grep -nE '"\$\{[A-Za-z0-9_]+\}"/' "${files[@]}"

# sed program passed as a bare positional instead of via --expression.
grep -nE "\bsed( +--[a-z-]+(=[^ ]+)?)* +['\"]" "${files[@]}" | grep -v -- '--expression'

# sed's --regexp-extended must precede --expression (a later one leaves an
# extended-regex script parsed as basic, breaking `(`, `|`, `+`, `\1`).
grep -nE '\bsed\b.*--expression.*--regexp-extended' "${files[@]}"

# Inline `; then` / `; do`, backticks, and attached awk `-F`.
grep -nE '; *(then|do)\b' "${files[@]}"
grep -nE '[^\\]`|^`' "${files[@]}"
grep -nE "awk[^|]*-F[^ \"']" "${files[@]}"

# Enumerated parameter expansions that must be rewritten.
grep -nE '\$\{[A-Za-z0-9_]+(##\*[/:]|%/\*|%\.\*|/[^}]+/[^}]*)\}' "${files[@]}"

# A command broken across lines inside `$( ... )` must use the split opening
# `$( \` with the command on the next line, never attached as `$(command \`.
grep -nE '\$\([a-z]+ \\$' "${files[@]}"

# Redirection operator must have a space before its target (`&> /dev/null`, not
# `&>/dev/null`); fd-duplication (`2>&1`, `>&2`) stays attached, so it is filtered out.
grep -nE '(&>>?|[0-9]>>?)[^ &0-9]' "${files[@]}" | grep -vE '2>&1|>&[0-9]'

# Line length — a line over eighty columns (counting a tab as four columns) carrying two
# or more flags must be broken one argument per line. Lines with fewer than two flags and
# lines whose length comes from a single argument longer than the limit cannot be broken,
# so they are left alone.
awk '{ line = $0; gsub(/\t/, "    ", line); if (length(line) > 80 && gsub(/ --[a-zA-Z][a-zA-Z-]*/, "&") >= 2) print FILENAME":"FNR }' "${files[@]}"

# Undeclared function variables: every lowercase variable a function assigns (`x=`,
# `for x in`, or a `read` target) must be declared `local` earlier in that function.
awk '
	/^function / { infn = 1; split("", declared) }
	/^}$/ { infn = 0 }
	{ line = $0; sub(/^[\t ]+/, "", line); names = "" }
	line ~ /^local / { n = split(line, t, / +/); for (i = 2; i <= n; i++) { sub(/=.*/, "", t[i]); declared[t[i]] }; next }
	infn && match(line, /^for [a-z_][a-z0-9_]* /) { names = substr(line, 5, RLENGTH - 5) }
	infn && match(line, /(^|while |\| *)(IFS=[^ ]* )?read( +-[a-zA-Z]+( +"[^"]*")?)* +[a-z_][a-z0-9_ ]*/) { names = substr(line, RSTART, RLENGTH); sub(/.*read( +-[a-zA-Z]+( +"[^"]*")?)* +/, "", names) }
	infn && match(line, /^[a-z_][a-z0-9_]*=/) { names = substr(line, 1, RLENGTH - 1) }
	{ n = split(names, list, / +/); for (i = 1; i <= n; i++) if (list[i] != "" && !(list[i] in declared)) print FILENAME":"FNR": "list[i] }
' "${files[@]}"

# Numeric comparison must use [[ ... ]], never single-bracket [ ... -eq/-ne/-lt/-le/-gt/-ge ... ]
# (its arithmetic context tolerates empty/noninteger operands). Every hit is a violation; the
# regex matches only literal operators, so variable-operator tests (`[ "${a}" "${operator}" "${b}" ]`,
# which must stay single-bracket) never appear. Comparing a count (`wc`/`grep --count`) via
# `==`/`!=` is also numeric, but recognizing the operand as numeric is semantic and left to
# author/review, not swept or auto-converted here.
grep -nE '(^|[^[])\[ [^]]*-(eq|ne|lt|le|gt|ge)( |\])' "${files[@]}"

# A trap body must be single-quoted with the constant quoted inside it. The first grep
# catches a double-quoted body (expands at install time); the second catches a single-quoted
# body that left the constant unquoted. The compliant form matches neither, so every hit
# is a violation.
grep -nE 'trap +"[^"]*(return|exit)' "${files[@]}"
grep -nE "trap +'[^']*(return|exit) +\\\$\{" "${files[@]}"

# A compound command (`while`, `for`, `until`, `if`) ending a broken pipeline keeps its
# `do`/`then` aligned with itself. Every hit is a `do`/`then` indented less than the
# compound command it belongs to, which happens when the pipeline continuation indented
# the compound command but left its block at the opening statement's indent.
awk '
	/^[\t]*(while|for|until|if|elif) / { ci = match($0, /[^\t]/) - 1; pend = 1; next }
	pend && /^[\t]*(do|then)$/ { di = match($0, /[^\t]/) - 1; if (di < ci) print FILENAME":"FNR }
	{ pend = 0 }
' "${files[@]}"

# Blank-line layout around functions (each must report nothing). These catch
# sort/relocation dropping the separator between definitions, or a stray blank
# line just inside the braces.
for file in "${files[@]}"
do
	# adjacent function definitions with no blank line between them
	awk 'p=="}" && /^function / {print FILENAME":"NR} {p=$0}' "${file}"

	# blank line immediately after a function opening `{`
	awk '/^function .*{$/ {getline n; if (n ~ /^[[:space:]]*$/) print FILENAME":"NR}' "${file}"

	# blank line immediately before a closing `}`
	awk 'p ~ /^[[:space:]]*$/ && /^}$/ {print FILENAME":"NR} {p=$0}' "${file}"
done
```

This list is not exhaustive — it targets the mechanical rules most prone to slipping through. Reading remains the source of truth; treat the greps as a backstop, not a replacement.

## Report

Summarize what happened: list each formatted file with a short note of the changes made, and list any paths that were skipped and why. If a file was already compliant, say so rather than editing it.
