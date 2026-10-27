#!/usr/bin/env bash
# Download the latest pinned Mihomo release for Linux or macOS.
# Usage: ./scripts/download_mihomo.sh

set -euo pipefail

CORE_DIR="core"
MIHOMO_VERSION="v1.19.33"
mkdir -p "$CORE_DIR"
CORE_EXE="$CORE_DIR/mihomo"

case "$OSTYPE" in
  linux-gnu*)
    PLATFORM="linux"
    case "$(uname -m)" in
      x86_64|amd64) ARCH="amd64" ;;
      aarch64|arm64) ARCH="arm64" ;;
      *) echo "Unsupported Linux architecture: $(uname -m)" >&2; exit 1 ;;
    esac
    ASSET="mihomo-linux-${ARCH}-${MIHOMO_VERSION}.gz"
    ;;
  darwin*)
    PLATFORM="darwin"
    case "$(uname -m)" in
      x86_64|amd64) ARCH="amd64" ;;
      arm64|aarch64) ARCH="arm64" ;;
      *) echo "Unsupported macOS architecture: $(uname -m)" >&2; exit 1 ;;
    esac
    ASSET="mihomo-darwin-${ARCH}-${MIHOMO_VERSION}.gz"
    ;;
  *)
    echo "Unsupported platform: $OSTYPE" >&2
    exit 1
    ;;
esac

CORE_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/${ASSET}"
TEMP_GZ="$(mktemp)"
trap 'rm -f "$TEMP_GZ"' EXIT

echo "Downloading Mihomo ${MIHOMO_VERSION} (${PLATFORM}/${ARCH})..."
curl --fail --location --retry 3 --output "$TEMP_GZ" "$CORE_URL"
gzip -dc "$TEMP_GZ" > "$CORE_EXE"
chmod +x "$CORE_EXE"

"$CORE_EXE" -v
echo "Mihomo downloaded successfully to $CORE_EXE"
