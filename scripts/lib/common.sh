# Shared helpers for build scripts. Source this from every stage script:
#   source "$(dirname "$0")/lib/common.sh"

set -euo pipefail

# Resolve repo root regardless of where the script is invoked from.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_DIR="${REPO_ROOT}/config"
SOURCES_DIR="${REPO_ROOT}/sources"
PATCHES_DIR="${REPO_ROOT}/patches"

# Load board + debian configs into the environment.
# shellcheck disable=SC1091
source "${CONFIG_DIR}/board.cubie-a7z.env"
# shellcheck disable=SC1091
source "${CONFIG_DIR}/debian.env"

# Logging.
_ts() { date -u +'%Y-%m-%dT%H:%M:%SZ'; }
log()  { printf '[%s] %s\n' "$(_ts)" "$*" >&2; }
warn() { printf '[%s] WARN: %s\n' "$(_ts)" "$*" >&2; }
die()  { printf '[%s] ERROR: %s\n' "$(_ts)" "$*" >&2; exit 1; }

# Require a binary on PATH or die.
require_bin() {
  command -v "$1" >/dev/null 2>&1 || die "missing required binary: $1"
}

# Require a non-empty variable.
require_var() {
  local name="$1"
  local value="${!name:-}"
  [[ -n "$value" ]] || die "config variable $name is empty (see config/*.env)"
}

# Idempotent git clone-or-fetch to a pinned SHA.
#   fetch_pinned <repo_url> <branch> <commit_sha> <dest_dir>
fetch_pinned() {
  local repo="$1" branch="$2" sha="$3" dest="$4"
  [[ -n "$sha" ]] || die "no commit SHA supplied for $dest (refusing to track a moving branch)"

  if [[ -d "$dest/.git" ]]; then
    local have
    have="$(git -C "$dest" rev-parse HEAD)"
    if [[ "$have" == "$sha" ]]; then
      log "  $dest already at $sha"
      return 0
    fi
    log "  $dest is at $have, moving to $sha"
    git -C "$dest" fetch --depth=1 origin "$sha" \
      || git -C "$dest" fetch origin "$branch"
    git -C "$dest" checkout --detach "$sha"
  else
    log "  cloning $repo @ $sha -> $dest"
    mkdir -p "$(dirname "$dest")"
    git clone --depth=1 --branch "$branch" --single-branch "$repo" "$dest"
    git -C "$dest" fetch --depth=1 origin "$sha" 2>/dev/null || true
    git -C "$dest" checkout --detach "$sha"
  fi
}

# Apply every *.patch in a directory in lexical order via `git am`.
apply_patches() {
  local src_dir="$1" patch_dir="$2"
  [[ -d "$patch_dir" ]] || return 0
  shopt -s nullglob
  local patches=( "$patch_dir"/*.patch )
  shopt -u nullglob
  [[ ${#patches[@]} -gt 0 ]] || { log "  no patches in $patch_dir"; return 0; }

  log "  applying ${#patches[@]} patch(es) from $patch_dir"
  # Ensure git identity exists for git am
  git -C "$src_dir" config user.email "build@cubie-a7z" 2>/dev/null
  git -C "$src_dir" config user.name "Cubie A7Z Build" 2>/dev/null
  for p in "${patches[@]}"; do
    log "    -> $(basename "$p")"
    git -C "$src_dir" am --keep-cr "$p" \
      || die "patch failed: $p (run 'git am --abort' in $src_dir)"
  done
}

