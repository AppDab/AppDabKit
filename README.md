# AppDabKit
Foundational services and tools for shipping apps faster.

See [Adding an Automation Action](Documentation/AddingAutomationAction.md) for the shared typed action contract.

## Formatting

Install SwiftFormat with `brew install swiftformat`, then enable the commit hook once with `git config core.hooksPath .githooks`. The hook formats staged Swift files before each commit. Run `swiftformat Sources Tests Package.swift` to format the whole package, or add `--lint` to check it without changing files. Pull requests run the same lint check.
