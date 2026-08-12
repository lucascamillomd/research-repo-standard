#!/usr/bin/env bash
# Quality contract tests for frontmatter and tracked text files. Plain bash; no framework.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILS=0
pass() { printf 'ok: %s\n' "$*"; }
fail() {
  printf 'FAIL: %s\n' "$*"
  FAILS=$((FAILS + 1))
}

frontmatter_files=(SKILL.md agents/code-simplifier.md)
required_keys=(name description standard_version)

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
    if [[ "$key" == standard_version ]]; then
      key_count="$(grep -Ec "${key}:" "$file" || true)"
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

text_files=()
while IFS= read -r -d '' relative_file; do
  if LC_ALL=C grep -Iq . "$ROOT/$relative_file" || [[ ! -s "$ROOT/$relative_file" ]]; then
    text_files+=("$relative_file")
  fi
done < <(git -C "$ROOT" ls-files -z)

for relative_file in "${text_files[@]}"; do
  file="$ROOT/$relative_file"
  if [[ "$relative_file" != Makefile && "$relative_file" != *.md ]] &&
    grep -n $'\t' "$file" > /dev/null; then
    fail "tracked text file contains tabs: $relative_file"
  fi
  if grep -nE '[[:blank:]]+$' "$file" > /dev/null; then
    fail "tracked text file contains trailing whitespace: $relative_file"
  fi
  final_byte="$(LC_ALL=C tail -c 1 "$file" | od -An -t x1 | tr -d '[:space:]')"
  final_two_bytes="$(LC_ALL=C tail -c 2 "$file" | od -An -t x1 | tr -d '[:space:]')"
  if [[ "$final_byte" != 0a || "$final_two_bytes" == 0a0a ]]; then
    fail "tracked text file must end with one newline: $relative_file"
  fi
done

if ((FAILS == 0)); then
  pass "tracked text files contain no tabs or trailing whitespace and end with a newline"
else
  printf '%s\n' "$FAILS test(s) failed"
  exit 1
fi

echo "all quality tests passed"
