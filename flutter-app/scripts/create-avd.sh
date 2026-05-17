#!/usr/bin/env bash
# Creates an Android Virtual Device suitable for Flutter smoke-testing.
#
# Idempotent: skips if an AVD with the target name already exists.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./setup-android-env.sh
source "$SCRIPT_DIR/setup-android-env.sh" >/dev/null

AVD_NAME="${1:-flutter_test}"
DEVICE_PROFILE="${2:-pixel_7}"
SYSTEM_IMAGE="system-images;android-34;google_apis;arm64-v8a"

if avdmanager list avd 2>/dev/null | grep -q "Name: $AVD_NAME"; then
    echo "[create-avd] AVD '$AVD_NAME' already exists — leaving it alone."
    exit 0
fi

if ! sdkmanager --list_installed 2>/dev/null | grep -q "$SYSTEM_IMAGE"; then
    echo "[create-avd] System image '$SYSTEM_IMAGE' not installed yet."
    echo "[create-avd] Run: yes | sdkmanager --licenses && sdkmanager '$SYSTEM_IMAGE'"
    exit 1
fi

echo "[create-avd] Creating AVD '$AVD_NAME' (device: $DEVICE_PROFILE, image: $SYSTEM_IMAGE)"
echo no | avdmanager create avd \
    --name "$AVD_NAME" \
    --device "$DEVICE_PROFILE" \
    --package "$SYSTEM_IMAGE" \
    --force

echo "[create-avd] Done. Boot it with: emulator -avd $AVD_NAME"
