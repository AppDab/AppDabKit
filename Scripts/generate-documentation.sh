#!/bin/bash
set -euo pipefail

output_path="${1:-.build/documentation/AppDabKit.doccarchive}"
output_parent="$(dirname "$output_path")"
mkdir -p "$output_parent"

generate_documentation() {
    if [[ "${SWIFT_PACKAGE_DISABLE_SANDBOX:-false}" == "true" ]]; then
        swift package --disable-sandbox "$@"
    else
        swift package "$@"
    fi
}

generate_documentation --allow-writing-to-directory "$output_parent" \
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
