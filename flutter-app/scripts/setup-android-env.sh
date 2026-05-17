#!/usr/bin/env bash
# Source this to set Android SDK + Java env in the current shell.
# Layout assumed:
#   - Android Studio installed via `brew install --cask android-studio`
#     (provides JBR at /Applications/Android Studio.app/Contents/jbr/Contents/Home)
#   - Command-line tools installed via `brew install --cask android-commandlinetools`
#     (puts sdkmanager/avdmanager/adb at /opt/homebrew/share/android-commandlinetools)
#
# Usage:
#   source scripts/setup-android-env.sh
#   sdkmanager --list_installed
#   emulator -avd flutter_test
#
# Idempotent — safe to source repeatedly.

export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

# Prepend SDK tools to PATH if not already there.
for dir in \
    "$ANDROID_HOME/platform-tools" \
    "$ANDROID_HOME/emulator" \
    "$ANDROID_HOME/cmdline-tools/latest/bin" \
    "$JAVA_HOME/bin"; do
    case ":$PATH:" in
        *":$dir:"*) : ;;
        *) PATH="$dir:$PATH" ;;
    esac
done
export PATH

if [ -t 1 ]; then
    echo "Android env set:"
    echo "  JAVA_HOME=$JAVA_HOME"
    echo "  ANDROID_HOME=$ANDROID_HOME"
    echo "  java: $(java -version 2>&1 | head -1)"
    echo "  sdkmanager: $(command -v sdkmanager)"
    echo "  adb: $(command -v adb)"
    echo "  emulator: $(command -v emulator)"
fi
