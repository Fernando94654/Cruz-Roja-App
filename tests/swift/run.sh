#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_build_dir="$(mktemp -d "${TMPDIR:-/tmp}/cruzroja-swift-tests.XXXXXX")"
trap 'rm -rf "$test_build_dir"' EXIT
xcrun swiftc -parse-as-library -module-cache-path "$test_build_dir/cache" \
    CruzRoja/Core/Networking/*.swift \
    CruzRoja/Core/Speech/SpeechSynthesizing.swift \
    CruzRoja/Core/Speech/Dictating.swift \
    CruzRoja/Features/Learn/Models/*.swift \
    CruzRoja/Features/Learn/Services/*.swift \
    CruzRoja/Features/Learn/ViewModels/*.swift \
    CruzRoja/Features/Assistant/Models/*.swift \
    CruzRoja/Features/Assistant/Services/*.swift \
    CruzRoja/Features/Assistant/ViewModels/*.swift \
    tests/swift/LessonsChecks.swift -o "$test_build_dir/lessons-checks"
"$test_build_dir/lessons-checks"
