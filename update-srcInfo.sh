#!/usr/bin/env bash
# update-srcInfo.sh - Fetch provenant release info and create per-tag JSON files
#
# Usage:
#   ./update-srcInfo.sh              # update to latest release
#   ./update-srcInfo.sh v0.1.14       # update to a specific tag

set -euo pipefail

REPO="mstykow/provenant"
JSON_DIR="jsons"
INDEX_FILE="index.json"

mkdir -p "$JSON_DIR"

# ── Determine the target tag ──────────────────────────────────────────────
if [ $# -eq 0 ]; then
  TAG=$(curl -sL "https://api.github.com/repos/${REPO}/releases/latest" \
    | jq -r '.tag_name // "unknown"')
  if [ "$TAG" = "unknown" ]; then
    echo "ERROR: Could not determine latest release tag from GitHub API"
    exit 1
  fi
elif [ $# -eq 1 ]; then
  TAG="$1"
else
  echo "Usage: $0 [TAG]"
  exit 1
fi

VERSION=$(echo "$TAG" | sed 's/^v//')  # strip leading 'v' from tag
JSON_FILE="${JSON_DIR}/${VERSION}.json"

# ── Skip fetching if JSON already exists ─────────────────────────────────
if [ -f "$JSON_FILE" ]; then
  echo "JSON for tag ${TAG} already exists: ${JSON_FILE}"
  echo "Re-generating index.json from existing files..."
else
  echo "Creating ${JSON_FILE} for tag: ${TAG} (version: ${VERSION})"

  # ── Fetch SHA256 hashes from release assets ─────────────────────────────

  entries=(
    "linux-x86_64  x86_64-linux"
    "linux-aarch64 aarch64-linux"
    "macos-x86_64  x86_64-darwin"
    "macos-aarch64 aarch64-darwin"
  )

  TMP_JSON=$(jq -n \
    --arg version "$VERSION" \
    '{version: $version, platforms: {}}')

  for entry in "${entries[@]}"; do
    read -r asset_suffix nix_platform <<< "$entry"

    sha_file="provenant-${asset_suffix}.tar.gz.sha256"

    # Fetch the sha256 from the release
    raw_sha=$(curl -sL \
      "https://github.com/${REPO}/releases/download/${TAG}/${sha_file}" | grep -oP '^[a-f0-9]+')

    # Convert hex sha256 to nix SRI format
    sri_hash=$(nix hash convert --hash-algo sha256 --to sri "$raw_sha")

    url="https://github.com/${REPO}/releases/download/${TAG}/provenant-${asset_suffix}.tar.gz"

    TMP_JSON=$(echo "$TMP_JSON" | jq \
      --arg platform "$nix_platform" \
      --arg url     "$url" \
      --arg hash    "$sri_hash" \
      '. as $root | {version: .version, platforms: (.platforms + {("\($platform)"): {url: $url, hash: $hash}})}')

    echo "  ✓ ${nix_platform}: ${sri_hash}"
  done

  # ── Write per-tag JSON ─────────────────────────────────────────────────
  echo "$TMP_JSON" | jq --sort-keys > "$JSON_FILE"
  echo "Created ${JSON_FILE}"
fi

# ── Regenerate index.json ────────────────────────────────────────────────
echo "Regenerating ${INDEX_FILE}..."

# Collect all version JSONs and determine the latest (highest semver)
VERSIONS_JSON=$(jq -n '{versions: {}}')
for f in "${JSON_DIR}"/*.json; do
  v=$(jq -r '.version' "$f")
  rel="jsons/$(basename "$f")"
  VERSIONS_JSON=$(echo "$VERSIONS_JSON" | jq \
    --arg v "$v" --arg r "$rel" \
    '{versions: (.versions + {($v): $r})}')
done

# Determine latest: prefer the GitHub latest tag if its JSON exists,
# otherwise pick the highest version from existing JSONs
LATEST_VERSION=""
if [ -f "$JSON_FILE" ]; then
  # The tag we just fetched/verified is the latest
  LATEST_VERSION="$VERSION"
else
  # Fallback: pick highest version from existing files
  LATEST_VERSION=$(echo "$VERSIONS_JSON" | jq -r '.versions | keys | sort_by(split(".") | map(tonumber? // 0)) | last')
fi

echo "$VERSIONS_JSON" | jq --arg latest "$LATEST_VERSION" \
  '. + {latest: $latest}' | jq --sort-keys > "$INDEX_FILE"

echo "Done. Updated ${INDEX_FILE} (latest: ${LATEST_VERSION})"
