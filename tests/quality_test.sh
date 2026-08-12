#!/usr/bin/env bash
# Quality contract tests for frontmatter and tracked text files. Plain bash; no framework.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT" || exit 1
FAILS=0
pass() { printf 'ok: %s\n' "$*"; }
fail() {
  printf 'FAIL: %s\n' "$*"
  FAILS=$((FAILS + 1))
}

frontmatter_files=(SKILL.md agents/code-simplifier.md)
required_keys=(name description standard_version)
markdownlint="$ROOT/node_modules/.bin/markdownlint-cli2"

if ! command -v mise > /dev/null 2>&1; then
  echo "tests/quality_test.sh: mise is required for pinned quality dependencies" >&2
  exit 1
fi
if [[ ! -x "$markdownlint" ]]; then
  mise exec -- npm ci > /dev/null
fi

lint_markdown() {
  mise exec -- "$markdownlint" --no-globs "$@" > /dev/null 2>&1
}

if printf '# Test\n\n   %smake title=x\n\trecipe\n   %s\n' '````' '````' | lint_markdown -; then
  pass "Markdown tabs are allowed in parsed make fences"
else
  fail "Markdown tabs are allowed in parsed make fences"
fi

if printf '# Test\n\n~~~text\n%smake\n\trecipe\n%s\n~~~\n' '```' '```' | lint_markdown -; then
  fail "make-looking content inside a non-make fence must not allow tabs"
else
  pass "make-looking content inside a non-make fence does not allow tabs"
fi

if printf '# Test\n\n<script>\n%smake\n\trecipe\n%s\n</script>\n' '```' '```' | lint_markdown -; then
  fail "make-looking content inside raw HTML must not allow tabs"
else
  pass "make-looking content inside raw HTML does not allow tabs"
fi

for relative_file in "${frontmatter_files[@]}"; do
  file="$ROOT/$relative_file"
  first="$(sed -n '1p' "$file")"
  second_delimiter="$(grep -n '^---$' "$file" | sed -n '2p')"
  if [[ "$first" == '---' && -n "$second_delimiter" ]]; then
    pass "frontmatter delimiters present: $relative_file"
  else
    fail "frontmatter delimiters present: $relative_file"
    continue
  fi

  frontmatter="$({
    awk '
      NR == 1 && /^---$/ { in_frontmatter = 1; next }
      in_frontmatter && /^---$/ { exit }
      in_frontmatter { print }
    ' "$file"
  })"

  for key in "${required_keys[@]}"; do
    if [[ "$key" == standard_version && "$relative_file" == SKILL.md ]]; then
      version_pattern='^<!--[[:space:]]*standard_version:[^>]*-->$'
      key_count="$(grep -Ec "$version_pattern" "$file" || true)"
      if [[ "$key_count" -eq 1 ]] && ! awk '
        /^---$/ { delimiters++; next }
        delimiters == 2 && /^[[:space:]]*$/ { next }
        delimiters == 2 {
          found = /^<!--[[:space:]]*standard_version:[^>]*-->$/
          exit
        }
        END { exit !found }
      ' "$file"; then
        key_count=0
      fi
    elif [[ "$key" == standard_version ]]; then
      key_count="$(grep -Ec '^standard_version:' <<< "$frontmatter" || true)"
    else
      key_count="$(grep -Ec "^${key}:" <<< "$frontmatter" || true)"
    fi
    if [[ "$key_count" -eq 1 ]]; then
      pass "frontmatter has one $key key: $relative_file"
    elif [[ "$key_count" -eq 0 ]]; then
      fail "frontmatter missing $key key: $relative_file"
    else
      fail "frontmatter duplicates $key key: $relative_file"
    fi
  done

  duplicate_keys="$({
    printf '%s\n' "$frontmatter" |
      grep -E '^[A-Za-z_][A-Za-z0-9_-]*:' |
      sed 's/:.*//' |
      sort |
      uniq -d || true
  })"
  if [[ -z "$duplicate_keys" ]]; then
    pass "frontmatter keys are unique: $relative_file"
  else
    fail "frontmatter has duplicate keys: $relative_file ($duplicate_keys)"
  fi
done

tracked_markdown=()
while IFS= read -r -d '' relative_file; do
  file="$ROOT/$relative_file"
  if [[ "$relative_file" == *.md ]]; then
    tracked_markdown+=("$relative_file")
  elif ! LC_ALL=C grep -Iq . "$file" && [[ -s "$file" ]]; then
    continue
  elif [[ "$relative_file" != Makefile ]] && grep -q $'\t' "$file"; then
    fail "tracked text file contains tabs: $relative_file"
  fi
  if grep -q $'\r' "$file"; then
    fail "tracked text file contains carriage returns: $relative_file"
  fi
  if grep -qE '[[:blank:]]+$' "$file"; then
    fail "tracked text file contains trailing whitespace: $relative_file"
  fi
  final_two_bytes="$(LC_ALL=C tail -c 2 "$file" | od -An -t x1 | tr -d '[:space:]')"
  if [[ "$final_two_bytes" != *0a || "$final_two_bytes" == *0a0a ]]; then
    fail "tracked text file must end with one newline: $relative_file"
  fi
done < <(git -C "$ROOT" ls-files -z)

if ((${#tracked_markdown[@]} > 0)) && ! lint_markdown "${tracked_markdown[@]}"; then
  fail "tracked Markdown violates the pinned lint contract"
fi

if ((FAILS == 0)); then
  pass "tracked files satisfy Markdown and text quality contracts"
else
  printf '%s\n' "$FAILS test(s) failed"
  exit 1
fi

echo "all quality tests passed"
