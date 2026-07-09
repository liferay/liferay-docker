# Bash Code Style

This document is the source of truth for the style of every Bash file in the `liferay-docker` repository. It defines how files are structured, named, formatted, and documented so that all scripts read consistently regardless of author.

It applies to every `*.sh` file in the repository, including executables, internal (`_`-prefixed) helpers, and test files. When the rules here and the existing code disagree, this document wins and the code should be updated to match. To apply these rules, run the [`format-bash-code`](skills/format-bash-code/SKILL.md) Claude skill: invoke `/format-bash-code` with no arguments to format every `*.sh` file you have modified locally on the current branch (both the changes already committed on the branch and the changes not yet committed), or pass file or folder paths to format those targets instead.

## Table of Contents

- [Main Structures](#main-structures)
	- [Files](#files)
	- [Functions](#functions)
	- [Test File](#test-file)
	- [Variables](#variables)
- [Sorting](#sorting)
	- [`source`](#source)
	- [`function`](#function)
- [Commands](#commands)
	- [Command Flags](#command-flags)
- [Comments](#comments)
- [Control Flow](#control-flow)
- [Indentation and Spacing](#indentation-and-spacing)
- [Pipelines](#pipelines)
- [Return Codes](#return-codes)
- [Shared Helpers](#shared-helpers)
	- [Logging](#logging)

## Main Structures

### Files

Files used only by other files (internal use) take a leading `_` (e.g. `_file.sh`); files meant to be executed by end users do not (e.g. `file.sh`).

Additionally, every file must follow the same top-to-bottom layout:

- Shebang `#!/bin/bash` for Linux environments or `#!/usr/bin/env bash` for multiplatform environments, followed by a blank line. Both forms are valid; which one to use depends on where the script runs and is the author's choice.
- `source` statements for dependencies, followed by a blank line.
- Function definitions.
- A single `main` invocation as the last line. Use `main "${@}"` when the file takes parameters and plain `main` when it does not; both are valid, and the choice is the author's.
- Files meant to be both executed and sourced guard their `main` body so it only runs when the file is executed directly.
- The last line is never blank.

```bash
#!/bin/bash

source _file_a.sh
source file_b.sh

function function_1 {
	...
}

function function_2 {
	...
}

function main {
	if [[ "${BASH_SOURCE[0]}" != "${0}" ]]
	then
		return
	fi

	function_1
	function_2
}

main
```

### Functions

- Declare functions with the keyword `function` followed by the name only, without `()`.
- Wrap the function body in `{}`.
- Name functions in `snake_case`.
- Use verb-prefixed names that describe the action:
	- `get_*` for functions that echo a value.
	- `is_*` and `has_*` for boolean predicates.
	- `add_*`, `build_*`, `clean_*`, `set_*`, `update_*`, etc.
- Name local functions with a leading `_` (e.g. `_function_local`).
- Name global functions, which are invoked by other files, without the leading `_` (e.g. `function_global`).

```bash
function function_global {
	...
}

function _function_local {
	...
}
```

### Test File

Test files follow the same structure as the Files and Functions sections, with a few additions:

- Add `source _test_common.sh` to import the test utilities `assert_equals`, `common_set_up`, and `common_tear_down`. Of these, only `assert_equals` is required; `common_set_up` and `common_tear_down` are optional.
- Add a `source` for the file being tested.
- Declare functions `set_up` and `tear_down` to create and destroy the test dependencies, respectively.
- Prefix test files and test functions with `test_`: for a file named `file_a.sh`, create `test_file_a.sh` and name its test functions `test_file_a_function_1`, `test_file_a_function_2`, etc.

```bash
#!/bin/bash

source _test_common.sh
source file_a.sh

function main {
	test_file_a_function_1
	test_file_a_function_2
}

function set_up {
	common_set_up

	...
}

function tear_down {
	common_tear_down

	...
}

function test_file_a_function_1 {
	_test_file_a_function_1 "0" "true"
	_test_file_a_function_1 "1" "false"
}

function test_file_a_function_2 {
	...
}

function _test_file_a_function_1 {
	assert_equals "$(function_1 "${1}")" "${2}"
}

main
```

### Variables

- Name environment and global variables in upper snake case (e.g. `ENVIRONMENT_VARIABLE`).
- Declare local variables with `local` and name them in lower snake case (e.g. `local_variable`); if a local variable is shared across local functions, name it in upper snake case with a leading underscore (e.g. `_LOCAL_SHARED_VARIABLE`).
- Declare each local variable close to its first use rather than batching all declarations at the top of the function. For local variables that share the same first-use location, declare them together and apply [Sorting](#sorting). A consecutive run of `local` declarations with no blank line or other statement between them counts as one location and is sorted as a single block.
- Do not put spaces around `=` in assignments.
- Always wrap variable references in braces, and quote them (`"${variable}"`) everywhere except the single-expansion assignment case described at the end of this section. Bracing and quoting apply to positional and special parameters too: `"${1}"`, `"${@}"`, `"${#}"`, `"${?}"`.

```bash
function function_1 {
	echo "User ${_USER_ID} running function_1"

	local local_variable_1=${1}

	echo "${local_variable_1}"
}

function function_2 {
	echo "User ${_USER_ID} running function_2"

	local local_variable_2=${1}

	echo "${local_variable_2}"
}

function main {
	_USER_ID=$((RANDOM % 10))

	function_1
	function_2
}

main
```

- When a variable reference is adjacent to literal text, quote the entire parameter, with the variable braced, rather than isolating the variable in its own quotes. Keep the literal outside the quotes in only two cases: a glob, where quoting the literal would change behavior (`"${dir}"/*.zip`); and a Git repository URL, ref, refspec, or tag passed to a `git` command, which keeps the surrounding literal bare for readability (`git@github.com:liferay/"${1}".git`).

```bash
echo "${variable} text"

rm "release.${product_name}-${version}.pom"

git remote add upstream git@github.com:liferay/"${1}".git
```

- Rewrite these Bash-specific parameter expansions to legible, portable equivalents (wrap the replacement in `$( ... )` when it is assigned to or used as a value):
	- `${var##*/}` becomes `basename "${var}"`
	- `${var%/*}` becomes `dirname "${var}"`
	- `${var##*:}` becomes `echo "${var}" | awk -F ":" '{print $NF}'`
	- `${var%.*}` becomes `echo "${var}" | sed --expression "s/\.[^.]*$//"`
	- `${var#prefix}` becomes `echo "${var}" | sed --expression "s/^prefix//"`
	- `${var/a/b}` becomes `echo "${var}" | sed --expression "s/a/b/"`

	Every other parameter expansion (`${var:-default}`, `${var:offset:length}`, `${#var}`, etc.) is permitted and must be left unchanged.

```bash
file_name=$(basename "${1}")

version=$(echo "${artifact}" | awk -F ":" '{print $NF}')
```

- Use `$(( ... ))` for arithmetic.

```bash
local fixed_issues_array_part_length=$((fixed_issues_array_length / 4))
```

- Use `$( ... )` for command substitution, never backticks (`` ` ` ``).
- On a scalar assignment — a bare `x=...`, a `local x=...`, or an `export`/`readonly`/`declare` `x=...` — whose entire right-hand side is a single command substitution `$( ... )`, a single parameter expansion `${ ... }`, or a single arithmetic expansion `$(( ... ))`, do not quote the right-hand side. Quote and brace everywhere else: any right-hand side that is more than a single expansion (a concatenation or an adjacent literal), command arguments, test operands, and interpolation.
- Do not add `;` at the end of `$( ... )`.

```bash
local architecture=$(dpkg --print-architecture)

local exit_code=${?}

local seconds=$((end_time - _BUILD_TIMESTAMP))

export TEST_MACHINE=$(uname --machine)
```

## Sorting

Sort alphabetically, case-sensitive. You can do this by selecting the lines to sort and using the instructions below:

- Sublime
	- Click on `Edit` > `Sort Lines (Case Sensitive)`
	- Shortcut: `Ctrl + F9`
- Visual Studio Code:
	- Shortcut: `F1` and choose `Sort Lines Ascending`

For specific rules of each structure, see next sections.

### `source`

List parent-directory sources (`../`) before current-directory sources (`./`).

```bash
source ../_file_a.sh
source ../file_b.sh
source ./_file_c.sh
source ./file_d.sh
```

### `function`

Sort function definitions alphabetically (case-sensitive), and declare every global-scope function before any local-scope (`_`-prefixed) function. Sort `main` into its alphabetical position like any other name; never pin it first or last. The order in the example below and in the [Files](#files) and [Test File](#test-file) templates follows from this rule — it is not a template to copy, so reorder definitions when they drift. Reordering is safe: behavior comes from the call order in `main`, not the definition order. Sort only top-level definitions; a function defined inside another is never hoisted or reordered.

```bash
function function_global_a {
	...
}

function function_global_c {
	...
}

function _function_local_b {
	...
}

function _function_local_d {
	...
}
```

## Commands

- Wrap `awk` parameters in `""`. The field-separator value is a parameter: pass it as a separate quoted argument and split the attached `-F=` and `-Fx` forms into `-F "="` and `-F "x"`.
- Wrap `awk` instructions in `''`.

```bash
awk -F "/" '{print $NF, $0}'
awk -F "=" '/^artifact.url=/ {print $2}'
```

- Wrap `sed` regex expressions in `""`. Always pass the `sed` program through the `--expression` flag, never as a bare positional argument (`sed --expression "s/a/b/"`, not `sed "s/a/b/"`). This applies even to a standalone single-script `sed` and to one nested inside a command substitution.

```bash
sed --expression "s/-lts//"
sed --expression "s/\n$//" --null-data "${file}.sha512"

echo "${date}" | sed --expression "s/[^0-9-]//g"
```

- Put a space between a redirection operator and its target file: `command &> /dev/null`, not `command &>/dev/null`. This covers `>`, `>>`, `<`, `2>`, `&>`, and the like. File-descriptor duplication (`2>&1`, `>&2`) and process substitution (`<(...)`, `>(...)`) are single tokens and stay attached.

```bash
git remote get-url upstream &> /dev/null

tail --lines=1 2> /dev/null
```

### Command Flags

- Always prefer the long form of command-line flags for readability.

```bash
cp --archive "${source}" "${destination}"

git commit --message "${2}"

grep --invert-match LRCI
grep --extended-regexp --quiet "^[0-9a-f]{40}$"

head --lines=1

mkdir --parents release-data

rm --force --recursive "${directory}"

sed --expression "s/^\([A-Z][A-Z0-9]*-[0-9]*\).*/\\1/"
```

- Short forms are only acceptable where no long form exists (e.g. `git clean -dfx`), or where this guide deliberately standardizes on a short form, as it does for `awk`'s field separator `-F` (write `-F ":"`, never `--field-separator ":"`). When a flag has more than one long-form spelling, use the one this guide shows; for example, write `sed -n` as `--quiet`, not `--silent`. When it is unclear whether a long form exists, the short form is acceptable too.

- Order a command's flags alphabetically, whether inline or broken across lines. The exceptions are flags whose order matters: a `find` expression (`-name`, `-type`, `-print0`, …) and repeated `sed --expression` scripts stay in their written order, `sed`'s `--regexp-extended` must come before `--expression`, and `zip`'s `-i`/`-x` include/exclude filters trail the input file list they act on (so they follow the positionals rather than sorting in with the other flags).

```bash
find "${dir}" -name "*.sh" -type f

sed --regexp-extended --expression "s/^open-jdk-//"

zip \
	-q \
	-r \
	"${archive}.zip" \
	"${source_dir}" \
	-i "*.sql"
```

- When a command carries three or more flags, break it across lines as well (see [Pipelines](#pipelines)).

## Comments

Comments are rare; prefer self-explanatory names. When a comment is needed, use a `#`-delimited block with blank comment lines above and below the text.

```bash
#
# Your comment here
#
```

## Control Flow

- Put `then` and `do` on their own line, never inline with `; then` or `; do`.

```bash
if [ -z "${LIFERAY_RELEASE_GIT_REF}" ]
then
	...
elif [ -n "${LIFERAY_RELEASE_GIT_SHA}" ]
then
	...
fi

for counter in {0..3}
do
	...
done
```

- Prefer single-bracket `[ ... ]` tests. Reserve `[[ ... ]]` for cases that need its features: pattern matching, regular-expression matching (`=~`), `${BASH_SOURCE[0]}` comparisons, lexicographic string comparisons with `<` or `>` (which `[ ... ]` would treat as input or output redirection), and numeric comparisons (`-eq`, `-ne`, `-lt`, `-le`, `-gt`, `-ge`). Numeric comparisons stay in `[[ ... ]]` because its arithmetic context tolerates empty or noninteger operands, whereas `[ ... ]` fails with "integer expression expected".
- Use `==` for string equality and the numeric operators above for numeric comparison. Comparing a value that is inherently an integer — for example a count from `wc --lines` or `grep --count` — against a number is a numeric comparison, so write it with a numeric operator in `[[ ... ]]` (`[[ "$(... | wc --lines)" -eq 1 ]]`), not as a string test (`[ "$(...)" == 1 ]`). Recognizing that an operand is numeric depends on knowing what the command produces, so this conversion is **not** applied by the [`format-bash-code`](skills/format-bash-code/SKILL.md) skill; it is an authoring guideline enforced in code review.
- When the comparison operator itself is held in a variable (`[ "${a}" "${operator}" "${b}" ]`), keep the single-bracket `[ ... ]`, because `[[ ... ]]` parses its operator token literally and cannot accept a dynamic operator.
- For multiline conditions, break after the logical operator (`||` / `&&`) and align continuation lines so the test lines up under the first one (one tab plus three spaces, matching the width of `if `).

```bash
if [ "$(get_release_output)" == "hotfix" ] ||
   [ "$(get_release_output)" == "nightly" ] ||
   [ "${BUILD_CAUSE}" != "TIMERTRIGGER" ]
then
	return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
fi
```

- Do not wrap a single boolean function, variable, command, or pipeline in parentheses. Parentheses are only needed for combined conditions.

```bash
if echo "$(basename "${line}")" | grep --quiet "\.class$"
then
	...
fi

if is_abc
then
	...
fi

if (is_abc && is_xyz)
then
	...
fi
```

## Indentation and Spacing

- Indent with **tabs**, never spaces.
- Separate logical statements within a function with a single blank line.
- Separate consecutive function definitions with a single blank line.
- Do not put a blank line immediately after the opening `{` of a function or immediately before the closing `}`.
- At most one blank line ever appears in a row. Beyond the blank-line rules in this section, the spacing is the author's to choose.

```bash
function function_name {
	mkdir --parents my_folder

	cd my_folder
}
```

## Pipelines

- Break a pipeline of three or more commands (two or more `|`) across lines, ending each line with `| \` and indenting the continuation by one tab. A two-command pipeline (a single `|`) stays on one line.

```bash
git log "tags/${ga_version}..HEAD" --pretty="%s %H" | \
	sed --expression "/c394bcbc1c36af47e66678c470d623568d3f1e88/c\LPD-27038/" | \
	grep --extended-regexp "^[A-Z][A-Z0-9]*-[0-9]+" | \
	sort | \
	uniq | \
	paste --delimiters=',' --serial > "${_BUILD_DIR}/release/release-notes.txt"
```

- Break a command that takes three or more flags across lines: one argument per line, the continuation indented one tab, positionals last. An option and its value count as one flag (`--max-time 300`); positionals do not count toward the three (`sed --expression "..." --in-place file`). The exception is a command whose syntax pins the operand first, such as `find` (`find "${dir}" -name "*.sh" -type f`). The break applies everywhere, including inside an `if` / `if !` condition; commands with two or fewer flags stay on one line (`rm --force --recursive`, `grep --extended-regexp --quiet`).

```bash
curl \
	--fail \
	--head \
	--max-time 300 \
	--retry 3 \
	--silent \
	--user "${LIFERAY_RELEASE_NEXUS_REPOSITORY_USER}:${LIFERAY_RELEASE_NEXUS_REPOSITORY_PASSWORD}" \
	"${file_url}"
```

```bash
if ! curl \
		--fail \
		--max-time 3 \
		--output /dev/null \
		--silent \
		"${url}"
then
	return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
fi
```

- Break a pipeline or command inside `$( ... )` the same way, adding a space after `$(` for readability:

```bash
local http_response=$( \
	curl \
		--header "Accept: application/vnd.github.v3.raw" \
		--header "Authorization: token ${LIFERAY_RELEASE_GITHUB_PAT}" \
		--include \
		--max-time 10 \
		--output "${file_name}" \
		--request GET \
		--retry 3 \
		--write-out "%{http_code}" \
		"https://api.github.com/repos/liferay/${repository_name}/contents/${file_path}?ref=${ref}")
```

## Return Codes

Use the named `LIFERAY_COMMON_EXIT_CODE_*` constants instead of bare numbers, and quote them on `return` and `exit`. If no named constant corresponds to the code, leave the numeric literal unchanged.

```bash
return "${LIFERAY_COMMON_EXIT_CODE_SKIPPED}"
return "${LIFERAY_COMMON_EXIT_CODE_BAD}"
return "${LIFERAY_COMMON_EXIT_CODE_OK}"
```

But, in boolean functions only — the `is_*` and `has_*` predicates — prefer bare `0` and `1` in the `return` statement.

## Shared Helpers

If `_liferay_common.sh` is available in the repository, `source` it and use the `lc_*` helper functions instead of reimplementing common behavior:

- `lc_background_run` / `lc_wait`: run functions concurrently and join them.
- `lc_cd`: change directory.
- `lc_download`: download files.
- `lc_get_property`: read properties from files `*.properties`.
- `lc_log`: leveled logging.
- `lc_time_run`: run a function and report its elapsed time.

### Logging

Use the `lc_log` helper with a level rather than raw `echo` for diagnostics. Reserve plain `echo` for user-facing output (help text, reproduction commands).

```bash
lc_log ERROR "No tag found."
lc_log DEBUG "File is available at ${file_url}."
lc_log INFO "${LIFERAY_RELEASE_GIT_REF} was already built in ${_BUILD_DIR}."
```

The `lc_log`-versus-`echo` choice is semantic and depends on intent, so it is **not** applied by the [`format-bash-code`](skills/format-bash-code/SKILL.md) skill; it is an authoring guideline enforced in code review. The formatter never rewrites `echo` to `lc_log` or vice versa.
