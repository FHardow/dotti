#!/usr/bin/env bash
# Render theme/templates/** into the repo using theme/palette.sh.
# A template at theme/templates/<path>.tmpl is written to <repo>/<path>.
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
palette="$root/theme/palette.sh"
templates="$root/theme/templates"

set -a
# shellcheck source=palette.sh
source "$palette"
set +a

# Only substitute palette variables, so other `$` in templates survive.
vars=$(grep -oE '^[a-z_]+=' "$palette" | tr -d '=' | sed 's/^/$/' | tr '\n' ' ')

while IFS= read -r -d '' tmpl; do
  rel=${tmpl#"$templates/"}
  out="$root/${rel%.tmpl}"
  mkdir -p "$(dirname "$out")"
  envsubst "$vars" <"$tmpl" >"$out"
  echo "rendered ${out#"$root/"}"
done < <(find "$templates" -type f -name '*.tmpl' -print0)
