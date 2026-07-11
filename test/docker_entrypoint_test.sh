#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/bin"
trace="$tmpdir/rails.trace"

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'printf "%s\\n" "$*" >> "$TRACE"' \
  > "$tmpdir/bin/rails"
chmod +x "$tmpdir/bin/rails"

run_entrypoint() {
  (
    cd "$tmpdir"
    TRACE="$trace" "$repo_root/bin/docker-entrypoint" "$@"
  )
}

run_entrypoint ./bin/rails server -b 0.0.0.0 -p 3000
grep -Fx 'db:prepare' "$trace" >/dev/null
grep -Fx 'server -b 0.0.0.0 -p 3000' "$trace" >/dev/null
! grep -Fx 'db:seed' "$trace" >/dev/null

: > "$trace"
run_entrypoint ./bin/rails runner 'puts :ok'
! grep -Fx 'db:prepare' "$trace" >/dev/null

printf '%s\n' 'docker-entrypoint behavior verified'
