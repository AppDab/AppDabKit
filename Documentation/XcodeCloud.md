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

`StartXcodeCloudBuildAction` is a directly executable write. It starts a build without preview or confirmation and remains classified as `.write` because it triggers remote work. The registry exposes direct execution support so consumers can select the appropriate execution behavior. Workflow and source reference validation occurs before starting the build: disabled or locked workflows, deleted references, and references in another repository are rejected. Branch selection uses the branch at execution time; it does not pin a commit SHA.

Each successful invocation queues a new build. Direct execution does not provide idempotency keys or replayable mutation receipts. If a response is lost, the build may already have started; inspect Xcode Cloud before invoking the action again. The action does not automatically retry failed starts.

Call the typed action through `Executor.execute` or submit an action request in `.execute` mode. Preview, commit, and reconciliation modes are unsupported for this action.
