#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MINIMUM_TEST_COUNT="${DROPOFF_MIN_TEST_COUNT:-68}"
LIST_OUTPUT="$(mktemp -t dropoff-test-list.XXXXXX)"
trap 'rm -f "$LIST_OUTPUT"' EXIT

cd "$ROOT"
TEST_OPTIONS=(--disable-xctest --enable-swift-testing)
DEVELOPER_DIR="$(/usr/bin/xcode-select -p)"
if [[ "$DEVELOPER_DIR" == */CommandLineTools ]]; then
    FRAMEWORKS="$DEVELOPER_DIR/Library/Developer/Frameworks"
    LIBRARIES="$DEVELOPER_DIR/Library/Developer/usr/lib"
    TEST_OPTIONS+=(
        -Xswiftc -F -Xswiftc "$FRAMEWORKS"
        -Xlinker -rpath -Xlinker "$FRAMEWORKS"
        -Xlinker -rpath -Xlinker "$LIBRARIES"
    )
fi

if ! swift test "${TEST_OPTIONS[@]}" list >"$LIST_OUTPUT"; then
    echo "error: Swift Testing discovery failed." >&2
    echo "Install/select full Xcode with a Swift Testing runtime, then retry." >&2
    exit 1
fi

DISCOVERED_TEST_COUNT="$({
    /usr/bin/awk '
        /^DropOffTests[.\/][[:alnum:]_]/ { count += 1 }
        END { print count + 0 }
    ' "$LIST_OUTPUT"
})"
if (( DISCOVERED_TEST_COUNT < MINIMUM_TEST_COUNT )); then
    echo "error: discovered $DISCOVERED_TEST_COUNT Swift tests; expected at least $MINIMUM_TEST_COUNT." >&2
    echo "Update the Command Line Tools or select full Xcode, then retry." >&2
    exit 1
fi

echo "Discovered $DISCOVERED_TEST_COUNT Swift tests (minimum: $MINIMUM_TEST_COUNT)."
swift test "${TEST_OPTIONS[@]}"
