#!/usr/bin/env bash
# Sync this slim kube-scheduler tree from a kubernetes/kubernetes release tag.
# Usage: ./scripts/sync-from-kubernetes.sh v1.37.1
set -euo pipefail

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  echo "usage: $0 <kubernetes-tag>   e.g. v1.37.1" >&2
  exit 2
fi
if [[ ! "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "tag must look like vX.Y.Z, got: $TAG" >&2
  exit 2
fi

MINOR="${TAG#v}"
MINOR="${MINOR%.*}"          # 1.37
BRANCH="release-${MINOR}"    # release-1.37

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ks-sync.XXXXXX")"
cleanup() { rm -rf "$WORK"; }
trap cleanup EXIT

echo "==> fetching kubernetes ${TAG}"
# Prefer module cache / proxy content for that version
MODULE_DIR="$(go env GOPATH)/pkg/mod/k8s.io/kubernetes@${TAG}"
if [[ ! -d "$MODULE_DIR" ]]; then
  echo "==> downloading module k8s.io/kubernetes@${TAG}"
  GOWORK=off go mod download "k8s.io/kubernetes@${TAG}"
  MODULE_DIR="$(go env GOPATH)/pkg/mod/k8s.io/kubernetes@${TAG}"
fi
if [[ ! -d "$MODULE_DIR" ]]; then
  echo "module dir not found: $MODULE_DIR" >&2
  exit 1
fi

SRC="$WORK/src"
mkdir -p "$SRC"
# module cache is often read-only; copy first
cp -R "$MODULE_DIR"/. "$SRC"/
chmod -R u+w "$SRC"

echo "==> resolving kubernetes-internal packages for scheduler"
cd "$SRC"
GOWORK=off GOFLAGS=-mod=mod go list -deps -f '{{.ImportPath}}' \
  ./pkg/scheduler/... ./cmd/kube-scheduler/... 2>/dev/null \
  | grep '^k8s.io/kubernetes/' \
  | grep -v '^k8s.io/kubernetes/test/' \
  | sort -u > "$WORK/pkgs.txt"

{
  echo 'k8s.io/kubernetes/pkg/scheduler'
  echo 'k8s.io/kubernetes/cmd/kube-scheduler'
  cat "$WORK/pkgs.txt"
} | sort -u > "$WORK/copy.txt"

STAGE="$WORK/stage"
mkdir -p "$STAGE"
while IFS= read -r pkg; do
  rel="${pkg#k8s.io/kubernetes/}"
  if [[ -d "$SRC/$rel" ]]; then
    mkdir -p "$STAGE/$rel"
    rsync -a --delete \
      --include='*/' \
      --include='*.go' \
      --include='*.yaml' \
      --include='*.yml' \
      --include='*.json' \
      --include='*.proto' \
      --exclude='*' \
      "$SRC/$rel/" "$STAGE/$rel/" || cp -R "$SRC/$rel"/. "$STAGE/$rel"/
  fi
done < "$WORK/copy.txt"

cp "$SRC/go.mod" "$STAGE/go.mod"
cp "$SRC/go.sum" "$STAGE/go.sum" 2>/dev/null || true

python3 - <<'PY' "$STAGE/go.mod" "$TAG"
import re, sys
from pathlib import Path
path = Path(sys.argv[1])
tag = sys.argv[2]  # v1.37.1
minor = tag[1:].rsplit(".", 1)[0]  # 1.37
pub = f"v{minor}.1" if tag.count(".") == 2 else tag
# Prefer exact patch for published staging modules: v1.37.1
pub = tag  # k8s.io/api etc use v0.37.1 — map below

text = path.read_text()
out = []
in_replace = False
for line in text.splitlines(True):
    if line.startswith("replace ("):
        in_replace = True
        continue
    if in_replace:
        if line.strip() == ")":
            in_replace = False
        continue
    if line.startswith("replace "):
        continue
    out.append(line)
text = "".join(out)

# k8s staging modules are v0.0.0 in monorepo go.mod → published v0.X.Y
patch = tag[1:]  # 1.37.1
api_ver = "v0." + patch  # v0.37.1
text = re.sub(r"(k8s\.io/[a-z0-9./-]+) v0\.0\.0\b(?!-)", rf"\1 {api_ver}", text)
# Do NOT rewrite pseudo-versions like v0.0.0-2026...
path.write_text(text)
print(f"rewrote staging deps to {api_ver}")
PY

# Preserve repo meta files
mkdir -p "$STAGE/scripts" "$STAGE/.github/workflows"
cp "$ROOT/scripts/sync-from-kubernetes.sh" "$STAGE/scripts/"
cp "$ROOT/.github/workflows/sync-k8s-release.yml" "$STAGE/.github/workflows/" 2>/dev/null || true
cp "$ROOT/.gitignore" "$STAGE/.gitignore" 2>/dev/null || true

# Preserve bilingual READMEs and refresh the "current version" line
if [[ -f "$ROOT/README.md" ]]; then
  sed -E "s/Kubernetes \`v[0-9.]+\` \(branch \`release-[0-9.]+\`\)/Kubernetes \`${TAG}\` (branch \`${BRANCH}\`)/" \
    "$ROOT/README.md" > "$STAGE/README.md"
else
  echo "# kube-scheduler (from kubernetes ${TAG})" > "$STAGE/README.md"
fi
if [[ -f "$ROOT/README.zh-CN.md" ]]; then
  sed -E "s/Kubernetes \`v[0-9.]+\`（分支 \`release-[0-9.]+\`）/Kubernetes \`${TAG}\`（分支 \`${BRANCH}\`）/" \
    "$ROOT/README.zh-CN.md" > "$STAGE/README.zh-CN.md"
fi

echo "==> replacing working tree (keeping .git)"
rsync -a --delete \
  --exclude '.git/' \
  "$STAGE"/ "$ROOT"/

cd "$ROOT"
chmod +x scripts/sync-from-kubernetes.sh
echo "==> synced to ${TAG} (branch should be ${BRANCH})"
echo "NEXT_BRANCH=${BRANCH}"
echo "NEXT_TAG=${TAG}"
