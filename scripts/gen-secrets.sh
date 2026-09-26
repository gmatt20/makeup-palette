#!/usr/bin/env bash
# Generate Config/Secrets.xcconfig from .env so build settings pick up secrets.
# Run from the repo root: scripts/gen-secrets.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  echo "No .env found. Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig instead." >&2
  exit 1
fi

key="$(grep -E '^REVENUECAT_APPLE_API_KEY=' .env | head -1 | sed -E 's/^REVENUECAT_APPLE_API_KEY=//; s/^"//; s/"$//' | tr -d '[:space:]')"

mkdir -p Config
{
  echo "// Auto-generated from .env — DO NOT COMMIT (git-ignored)."
  echo "// Regenerate with: scripts/gen-secrets.sh"
  echo "REVENUECAT_APPLE_API_KEY = ${key}"
} > Config/Secrets.xcconfig

echo "Wrote Config/Secrets.xcconfig"
