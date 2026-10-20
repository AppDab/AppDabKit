# Xcode Cloud automation

The shared service and typed actions support starting workflow builds using Apple's [Start a build endpoint](https://developer.apple.com/documentation/appstoreconnectapi/post-v1-cibuildruns).

| Action | Input | Result |
| --- | --- | --- |
| `list_xcode_cloud_workflows` | `accountID`, `appID`, optional `cursor` and `limit` | Workflows with repository IDs and pagination |
| `get_xcode_cloud_workflow` | `accountID`, `workflowID` | Workflow configuration summary |
| `list_xcode_cloud_git_references` | `accountID`, `repositoryID`, optional `cursor` and `limit` | Branch and tag reference IDs with pagination |
| `start_xcode_cloud_build` | `accountID`, `workflowID`, optional `sourceBranchOrTagID` and `clean` | Queued build run |
| `get_xcode_cloud_build` | `accountID`, `buildRunID` | Build progress and completion status |

The source reference is an SCM resource ID, not a branch name. An omitted source uses the API default. An omitted `clean` leaves the workflow default unchanged; explicit `false` is preserved. Build run IDs identify Xcode Cloud runs and are distinct from App Store Connect build IDs.

`StartXcodeCloudBuildAction` is a guarded write. Preview reads the workflow and optional source reference without starting a build. Commit checks the workflow summary, modification date, and source reference again before starting it. Disabled or locked workflows, deleted references, and references in another repository are rejected. Branch selection uses the branch at execution time; it does not pin a commit SHA.

A successful commit persists a replayable receipt, including the returned run ID. If the response is lost, reconciliation remains unresolved: Apple provides no client request ID to distinguish this start from another caller's start. Never infer success from a similar recent build or automatically repeat an uncertain start.

Adapters should call the typed actions through `Executor`. CLI commands live in AppDabCLI; native App Intents and the descriptor driven MCP server live in AppDabApp. All three must resolve the version of AppDabKit containing these actions. Merge the kit changes first, then update the CLI dependency resolution, then update both AppDabKit and AppDabCLI pins in AppDabApp's SwiftPM and Xcode resolution files.
