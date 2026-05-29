#!/usr/bin/env bash
# Build a Mod-Portal-ready release zip for mts-expanse, without running the test
# suite (so it needs neither Factorio nor the benchmarks). Produces
#   <OUT_DIR>/<mod>_<version>.zip
# with a single top-level <mod>_<version>/ folder, matching the packaging that
# scripts/test.sh does at the end of a full run. scripts/publish-mod-portal.sh
# uploads the resulting zip.
#
# Env overrides:
#   OUT_DIR    where to write the zip (default: the repo's parent directory)
#   WORK_DIR   staging directory (default: /tmp/mts-expanse-build)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MOD_NAME="$(python3 -c 'import json; print(json.load(open("info.json"))["name"])' < /dev/null)"
VERSION="$(python3 -c 'import json; print(json.load(open("info.json"))["version"])' < /dev/null)"
PACKAGE_NAME="${MOD_NAME}_${VERSION}"

OUT_DIR="${OUT_DIR:-$ROOT/..}"
WORK_DIR="${WORK_DIR:-/tmp/mts-expanse-build}"
ZIP_PATH="$(cd "$OUT_DIR" 2>/dev/null && pwd || echo "$OUT_DIR")/${PACKAGE_NAME}.zip"
STAGE="$WORK_DIR/$PACKAGE_NAME"

mkdir -p "$WORK_DIR" "$OUT_DIR"
rm -rf "$STAGE" "$ZIP_PATH"

# Same exclusions as test.sh: no VCS metadata, no nested zips, no dev-only scripts.
rsync -a --exclude '.git' --exclude '*.zip' --exclude 'scripts/' "$ROOT/" "$STAGE/"
(cd "$WORK_DIR" && zip -qr "$ZIP_PATH" "$PACKAGE_NAME")

# The Mod Portal rejects executable/helper files; fail early if any slipped in.
if unzip -Z1 "$ZIP_PATH" | grep -Eiq '\.(exe|bat|ps1|sh|py)$'; then
    echo "Error: release zip contains executable/helper files the Mod Portal rejects:" >&2
    unzip -Z1 "$ZIP_PATH" | grep -Ei '\.(exe|bat|ps1|sh|py)$' >&2
    exit 1
fi

echo "Built $ZIP_PATH"
ls -lh "$ZIP_PATH"
