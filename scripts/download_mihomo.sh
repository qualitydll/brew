#!/bin/bash
# Script to download mihomo core for Linux/Mac
# Usage: ./scripts/download_mihomo.sh

CORE_DIR="core"
MIHOMO_VERSION="v1.19.33"

# Detect platform
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    PLATFORM="linux"
    ARCH="amd64"
    CORE_NAME="mihomo-linux-${ARCH}"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    PLATFORM="darwin"
    ARCH="universal"
    CORE_NAME="mihomo-${PLATFORM}-${ARCH}"
else
    echo "Unsupported platform: $OSTYPE"
    exit 1
fi

CORE_URL="https://github.com/MetaCubeX/mihomo/releases/download/${MIHOMO_VERSION}/${CORE_NAME}-${MIHOMO_VERSION}.zip"
CORE_ZIP="${CORE_DIR}/mihomo.zip"
CORE_EXE="${CORE_DIR}/mihomo"

# Create core directory if it doesn't exist
mkdir -p "$CORE_DIR"

echo "Downloading mihomo ${MIHOMO_VERSION} for ${PLATFORM}..."
curl -L -o "$CORE_ZIP" "$CORE_URL"

echo "Extracting..."
unzip -o "$CORE_ZIP" -d "$CORE_DIR"

# Find and rename the binary
if [[ "$PLATFORM" == "linux" ]]; then
    TEMP="${CORE_DIR}/mihomo-linux-${ARCH}"
else
    TEMP="${CORE_DIR}/mihomo-${PLATFORM}-${ARCH}"
fi

if [ -f "$TEMP" ]; then
    mv "$TEMP" "$CORE_EXE"
    chmod +x "$CORE_EXE"
    echo "mihomo downloaded successfully to $CORE_EXE"
else
    echo "Failed to download mihomo"
    exit 1
fi

# Cleanup
rm "$CORE_ZIP"
