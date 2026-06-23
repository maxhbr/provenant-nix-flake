#!/usr/bin/env bash
# update-srcInfo.sh - Fetch provenant release info and create per-tag JSON files
#
# Usage:
#   ./update-srcInfo.sh              # update to latest release
#   ./update-srcInfo.sh v0.1.14       # update to a specific tag

set -euo pipefail

REPO="mstykow/provenant"
JSON_DIR="jsons"

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

# ── Skip if JSON already exists ──────────────────────────────────────────
if [ -f "$JSON_FILE" ]; then
  echo "JSON for tag ${TAG} already exists: ${JSON_FILE}"
  echo "Delete it manually if you want to re-fetch, then re-run."
  exit 0
fi

echo "Creating ${JSON_FILE} for tag: ${TAG} (version: ${VERSION})"

# ── Fetch SHA256 hashes from release assets ───────────────────────────────

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

# ── Write per-tag JSON ───────────────────────────────────────────────────
echo "$TMP_JSON" | jq --sort-keys > "$JSON_FILE"

echo "Done. Created ${JSON_FILE}"
echo ""
echo "⚠  Remember to:"
echo "   1. Add the new version to the 'versions' attribute in flake.nix"
echo "   2. Update 'latest' in flake.nix if this is the newest version"
