#!/bin/bash
set -euo pipefail

output_path="${1:-.build/documentation/AppDabKit.doccarchive}"
output_parent="$(dirname "$output_path")"
hosting_base_path="${DOCC_HOSTING_BASE_PATH#/}"
hosting_base_path="${hosting_base_path%/}"
mkdir -p "$output_parent"

generate_documentation() {
    if [[ "${SWIFT_PACKAGE_DISABLE_SANDBOX:-false}" == "true" ]]; then
        swift package --disable-sandbox "$@"
    else
        swift package "$@"
    fi
}

docc_options=(
    --target AppDabLocales \
    --target AppDabAutomation \
    --target AppDabServices \
    --target AppDabBagbutikExtensions \
    --enable-experimental-combined-documentation \
    --include-extended-types \
    --disable-indexing \
    --transform-for-static-hosting \
    --output-path "$output_path"
)

if [[ -n "$hosting_base_path" ]]; then
    docc_options+=(--hosting-base-path "$hosting_base_path")
fi

generate_documentation --allow-writing-to-directory "$output_parent" \
    generate-documentation "${docc_options[@]}"

if [[ ! -f "$output_path/index.html" ]]; then
    echo "DocC did not produce a static hosting index at $output_path/index.html" >&2
    exit 1
fi

expected_base_url="/"
if [[ -n "$hosting_base_path" ]]; then
    expected_base_url="/$hosting_base_path/"
fi

if ! grep -Fq "var baseUrl = \"$expected_base_url\"" "$output_path/index.html"; then
    echo "DocC archive does not use the expected hosting base path $expected_base_url" >&2
    exit 1
fi

for module in appdablocales appdabautomation appdabservices appdabbagbutikextensions; do
    if [[ ! -f "$output_path/documentation/$module/index.html" ]]; then
        echo "DocC did not produce a landing page for $module" >&2
        exit 1
    fi
done

cp Documentation/index.html "$output_path/index.html"
