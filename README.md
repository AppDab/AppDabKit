# AppDabKit
Foundational services and tools for shipping apps faster.

See [Adding an Automation Action](Documentation/AddingAutomationAction.md) for the shared typed action contract.

## Screenshots and app previews

`AppDabServices.VersionMediaServing` manages screenshots and app previews for existing App Store version localizations, using Apple's Asset Library APIs internally. `LiveServices.versionMediaService` supplies the live implementation. Shared automation includes list, get, upload, download, remove, and reorder actions for each media type.

Upload, download, removal, and ordering use the existing preview and confirmation flow. An upload preview binds the operation to the file's SHA256 fingerprint. Upload transfers all requested file ranges, marks the asset uploaded, and creates a version placement. Processing is asynchronous unless the caller requests a bounded wait. Removal deletes only the placement; reusable assets are retained.

The service follows all asset and placement relationship pages and verifies display order against the localization's placements. Results expose processing state, diagnostics, valid placement groups, and Apple's media specifications without exposing signed transfer URLs.
