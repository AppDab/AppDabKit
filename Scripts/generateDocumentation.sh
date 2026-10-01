#!/bin/bash
set -euo pipefail

output_path="${1:-.build/documentation/AppDabKit.doccarchive}"
output_parent="$(dirname "$output_path")"
swift_package_options=()

if [[ "${SWIFT_PACKAGE_DISABLE_SANDBOX:-false}" == "true" ]]; then
    swift_package_options+=(--disable-sandbox)
fi

mkdir -p "$output_parent"

swift package "${swift_package_options[@]}" --allow-writing-to-directory "$output_parent" \
    generate-documentation \
    --target AppDabLocales \
    --target AppDabAutomation \
    --target AppDabServices \
    --target AppDabBagbutikExtensions \
    --enable-experimental-combined-documentation \
    --include-extended-types \
    --disable-indexing \
    --transform-for-static-hosting \
    --output-path "$output_path"

if [[ ! -f "$output_path/index.html" ]]; then
    echo "DocC did not produce a static hosting index at $output_path/index.html" >&2
    exit 1
fi
