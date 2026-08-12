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
    if [[ "$key" == standard_version && "$relative_file" == SKILL.md ]]; then
      key_count="$(grep -Ec '^<!--[[:space:]]*standard_version:[^>]*-->$' "$file" || true)"
      if [[ "$key_count" -eq 1 ]] && ! awk '
        /^---$/ { delimiters++; next }
        delimiters == 2 && /^[[:space:]]*$/ { next }
        delimiters == 2 { exit !/^<!--[[:space:]]*standard_version:[^>]*-->$/ }
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

while IFS= read -r -d '' relative_file; do
  file="$ROOT/$relative_file"
  if ! LC_ALL=C grep -Iq . "$file" && [[ -s "$file" ]]; then
    continue
  fi

  if [[ "$relative_file" == *.md ]]; then
    if ! awk '
      /^```make[[:space:]]*$/ { in_make_fence = 1; next }
      /^~~~make[[:space:]]*$/ { in_make_fence = 2; next }
      in_make_fence == 1 && /^```[[:space:]]*$/ { in_make_fence = 0; next }
      in_make_fence == 2 && /^~~~[[:space:]]*$/ { in_make_fence = 0; next }
      !in_make_fence && index($0, "\t") { exit 1 }
    ' "$file"; then
      fail "tracked Markdown contains tabs outside make fences: $relative_file"
    fi
  elif [[ "$relative_file" != Makefile ]] && grep -q $'\t' "$file"; then
    fail "tracked text file contains tabs: $relative_file"
  fi
  if grep -qE '[[:blank:]]+$' "$file"; then
    fail "tracked text file contains trailing whitespace: $relative_file"
  fi
  final_two_bytes="$(LC_ALL=C tail -c 2 "$file" | od -An -t x1 | tr -d '[:space:]')"
  if [[ "$final_two_bytes" != *0a || "$final_two_bytes" == *0a0a ]]; then
    fail "tracked text file must end with one newline: $relative_file"
  fi
done < <(git -C "$ROOT" ls-files -z)

if ((FAILS == 0)); then
  pass "tracked text files contain no tabs or trailing whitespace and end with a newline"
else
  printf '%s\n' "$FAILS test(s) failed"
  exit 1
fi

echo "all quality tests passed"
