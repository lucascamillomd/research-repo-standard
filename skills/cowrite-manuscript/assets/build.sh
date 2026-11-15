#!/bin/sh
# Compile main.tex and supplementary.tex in bundle/ and put the PDFs beside them.
# Run from any directory. Needs Tectonic, or TeX Live or MacTeX with latexmk.
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
mkdir -p bundle
if [ -n "${TECTONIC:-}" ]; then
  engine=$TECTONIC
elif command -v tectonic >/dev/null 2>&1; then
  engine=tectonic
elif command -v latexmk >/dev/null 2>&1; then
  engine=latexmk
else
  echo 'Install Tectonic, or TeX Live or MacTeX with latexmk, or set TECTONIC to its path.' >&2
  exit 1
fi
for target in main supplementary; do
  [ -f "$target.tex" ] || continue
  if [ "$engine" = latexmk ]; then
    latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir=bundle "$target.tex"
  else
    "$engine" --keep-logs --keep-intermediates --outdir bundle "$target.tex"
  fi
  test -s "bundle/$target.pdf"
  cp "bundle/$target.pdf" "bundle/.$target.pdf.tmp"
  mv "bundle/.$target.pdf.tmp" "$target.pdf"
done
