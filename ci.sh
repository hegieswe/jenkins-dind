#!/usr/bin/env bash
# =============================================================================
# ci.sh — Build & Push Docker Image ke Docker Hub dengan Docker Buildx + Attest
#
# Usage:
#   ./ci.sh              → build + push
#   ./ci.sh --info       → tampilkan build info saja (alias: -i, --dry-run, -n)
# =============================================================================

set -euo pipefail
export DOCKER_BUILDKIT=1

# ─── KONFIGURASI ──────────────────────────────────────────────────────────────
DOCKER_ORG="hegieswe"
DEFAULT_PLATFORM="linux/amd64,linux/arm64"
BUILDER_NAME="attest-builder"

# Auto-detect Docker Repo Name dari nama folder repository (mendukung env override dari Jenkins)
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
DOCKER_REPO="${DOCKER_REPO:-$(basename "$GIT_ROOT")}"
# ─────────────────────────────────────────────────────────────────────────────

# Warna
CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; DIM='\033[2m'; RESET='\033[0m'

_info()   { echo -e " • $(printf '%-10s' "$1"): ${BOLD}$2${RESET}"; }
ok()      { echo -e "${GREEN}✔ $*${RESET}"; }
warn()    { echo -e "${YELLOW}⚠ $*${RESET}"; }
err()     { echo -e "${RED}✖ Error: $*${RESET}" >&2; exit 1; }
run_cmd() { echo -e "${YELLOW}▶ $*${RESET}"; "$@"; }

# ─── Parse args ───────────────────────────────────────────────────────────────
INFO_ONLY=false
PUSH=true
for arg in "$@"; do
  case "$arg" in
    --info|-i|--dry-run|-n) INFO_ONLY=true ;;
    --local|-l)             PUSH=false ;;
  esac
done

# Deteksi Platform
if [[ "$PUSH" == "false" ]]; then
  # Untuk local build (--load), hanya dukung single platform (host arch)
  ARCH=$(uname -m | sed 's/x86_64/amd64/;s/arm64/arm64/;s/aarch64/arm64/')
  PLATFORM="linux/${ARCH}"
else
  PLATFORM="$DEFAULT_PLATFORM"
fi

# ─── Paths ────────────────────────────────────────────────────────────────────
REPO_DIR="$(pwd)"

# ─── Git Info ─────────────────────────────────────────────────────────────────
if GIT_TAG=$(git describe --tags --exact-match 2>/dev/null); then
  IMAGE_TAG="$GIT_TAG"
  BRANCH="production"
else
  IMAGE_TAG=$(git rev-parse --short=7 HEAD 2>/dev/null || echo "latest")
  BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
fi

FULL_IMAGE="${DOCKER_ORG}/${DOCKER_REPO}:${IMAGE_TAG}"

# ─── Build Info Box ───────────────────────────────────────────────────────────
MODE_STR="Push to Registry"
[[ "$PUSH" == "false" ]] && MODE_STR="Local Build (No Push)"

echo
echo -e "${DIM}╭─ ${RESET}${BOLD}Build Info${RESET}${DIM} ────────────────────────────────────────────╮${RESET}"
_info "Image"    "$FULL_IMAGE"
_info "Mode"     "$MODE_STR"
_info "Platform" "$PLATFORM"
_info "Branch"   "$BRANCH"
_info "Builder"  "$BUILDER_NAME"
echo -e "${DIM}╰────────────────────────────────────────────────────────────╯${RESET}"
echo

if [[ "$INFO_ONLY" == true ]]; then
  echo -e "${YELLOW}ℹ️  Info only mode - no build${RESET}"
  exit 0
fi

# ─── Step 1: Docker Login ─────────────────────────────────────────────────────
if [[ "$PUSH" == "true" ]]; then
  echo -e "\n${BOLD}▶ 1/3 Docker Hub Login${RESET}"
  if [[ -n "${DOCKER_PASSWORD:-}" && -n "${DOCKER_USERNAME:-}" ]]; then
    echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
    ok "Login berhasil."
  else
    warn "Env DOCKER_USERNAME/DOCKER_PASSWORD tidak diset. Menggunakan sesi login yang ada."
  fi
else
  echo -e "\n${BOLD}▶ 1/3 Docker Hub Login${RESET} ${DIM}(Skipped for local build)${RESET}"
fi

# ─── Step 2: Ensure Buildx Builder ───────────────────────────────────────────
echo -e "\n${BOLD}▶ 2/3 Ensure Buildx Builder '${BUILDER_NAME}'${RESET}"
if docker buildx inspect "$BUILDER_NAME" &>/dev/null; then
  run_cmd docker buildx use "$BUILDER_NAME"
  ok "Builder '${BUILDER_NAME}' sudah ada, diaktifkan."
else
  echo -e "${CYAN}📦 Membuat builder '${BUILDER_NAME}'...${RESET}"
  run_cmd docker buildx create --name "$BUILDER_NAME" --use
  ok "Builder '${BUILDER_NAME}' berhasil dibuat."
fi

# ─── Step 3: Build ────────────────────────────────────────────────────────────
ACTION_FLAG="--push"
# Attestations (termasuk provenance default) sering menyebabkan proses push ke Docker Hub hang / stuck
# atau error 400 Bad Request karena masalah kompatibilitas registry.
ATTEST_FLAGS=(--provenance=false) 

if [[ "$PUSH" == "false" ]]; then
  ACTION_FLAG="--load"
  # Attestations tidak didukung oleh local Docker daemon (non-containerd) saat --load
  ATTEST_FLAGS=()
fi

echo -e "\n${BOLD}▶ 3/3 Build & ${ACTION_FLAG#--} → ${FULL_IMAGE}${RESET}"
BUILD_START=$(date +%s)

run_cmd docker buildx build \
  --platform "$PLATFORM" \
  --no-cache \
  --builder "$BUILDER_NAME" \
  --build-arg "BRANCH=${BRANCH}" \
  --tag "$FULL_IMAGE" \
  ${ATTEST_FLAGS[@]+"${ATTEST_FLAGS[@]}"} \
  "$ACTION_FLAG" \
  .

BUILD_DURATION=$(( $(date +%s) - BUILD_START ))
ok "Build selesai dalam ${BUILD_DURATION}s"

# ─── Output Summary ───────────────────────────────────────────────────────────
BUILD_OUTPUT=$(python3 -c "
import json
print(json.dumps({
  'image':  '${DOCKER_ORG}/${DOCKER_REPO}',
  'tag':    '${IMAGE_TAG}',
  'branch': '${BRANCH}',
  'mode':   '${MODE_STR}'
}, indent=2))
")

echo
if [[ "$PUSH" == "true" ]]; then
  ok "Image pushed successfully!"
else
  ok "Image loaded locally successfully!"
  warn "Attestations (SBOM/Provenance) skipped for local build (not supported by local daemon)."
fi
echo
echo "$BUILD_OUTPUT"
