import AppDabServices

extension Schema {
    static let xcodeCloudWorkflowOutput = object(properties: [
        "workflowID": outputString, "name": outputString, "repositoryID": outputString,
        "isEnabled": outputBoolean, "isLockedForEditing": outputBoolean, "lastModifiedDate": outputDate,
    ], required: ["workflowID", "name"])

    static let xcodeCloudGitReferenceOutput = object(properties: [
        "gitReferenceID": outputString, "name": outputString, "canonicalName": outputString,
        "kind": outputString, "repositoryID": outputString, "isDeleted": outputBoolean,
    ], required: ["gitReferenceID", "name"])

    static let xcodeCloudBuildRunOutput = object(properties: [
        "buildRunID": outputString, "number": outputInteger, "workflowID": outputString,
        "sourceBranchOrTagID": outputString, "executionProgress": outputString,
        "completionStatus": outputString, "createdDate": outputDate,
        "startedDate": outputDate, "finishedDate": outputDate,
    ], required: ["buildRunID"])
}
