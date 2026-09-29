import AppDabServices

extension Schema {
    static let outputString: JSONValue = .object(["type": .string("string")])
    static let outputInteger: JSONValue = .object(["type": .string("integer")])
    static let outputBoolean: JSONValue = .object(["type": .string("boolean")])
    static let outputDate: JSONValue = .object([
        "type": .string("string"),
        "format": .string("date-time")
    ])

    static func array(items: JSONValue) -> JSONValue {
        .object(["type": .string("array"), "items": items])
    }

    static let accountSummaryOutput = object(properties: [
        "accountID": outputString,
        "name": outputString
    ], required: ["accountID", "name"])

    static let accountIssueOutput = object(properties: [
        "message": outputString,
        "resolutionURL": outputString
    ], required: ["message"])

    static let appVersionOutput = object(properties: [
        "versionID": outputString,
        "platform": outputString,
        "state": outputString,
        "version": outputString,
        "createdDate": outputDate,
        "isFirstVersion": outputBoolean
    ], required: [
        "versionID", "platform", "state", "version", "createdDate", "isFirstVersion"
    ])

    static let buildSummaryOutput = object(properties: [
        "buildID": outputString,
        "version": outputString,
        "platform": outputString,
        "processingState": outputString,
        "uploadedDate": outputDate,
        "expirationDate": outputDate,
        "expired": outputBoolean
    ], required: ["buildID", "version"])

    static let betaGroupOutput = object(properties: [
        "betaGroupID": outputString, "name": outputString,
        "isInternalGroup": outputBoolean, "hasAccessToAllBuilds": outputBoolean,
        "feedbackEnabled": outputBoolean,
        "iosBuildsAvailableForAppleSiliconMac": outputBoolean,
        "iosBuildsAvailableForAppleVision": outputBoolean,
        "publicLinkEnabled": outputBoolean, "publicLinkLimit": outputInteger,
        "publicLinkLimitEnabled": outputBoolean, "publicLink": outputString
    ], required: ["betaGroupID", "name"])

    static let betaGroupBuildMembershipOutput = object(properties: [
        "betaGroup": betaGroupOutput, "buildID": outputString, "isMember": outputBoolean
    ], required: ["betaGroup", "buildID", "isMember"])

    static let appSummaryOutput = object(properties: [
        "appID": outputString,
        "name": outputString,
        "bundleID": outputString,
        "sku": outputString,
        "primaryLocale": outputString,
        "iconURL": outputString,
        "versions": array(items: appVersionOutput)
    ], required: ["appID", "name", "bundleID", "sku", "primaryLocale", "versions"])

    static let appDetailOutput = object(properties: [
        "appID": outputString,
        "name": outputString,
        "bundleID": outputString,
        "sku": outputString,
        "primaryLocale": outputString,
        "iconURL": outputString,
        "contentRightsDeclaration": outputString,
        "versions": array(items: appVersionOutput)
    ], required: ["appID", "name", "bundleID", "sku", "primaryLocale", "versions"])

    static let reviewResponseOutput = object(properties: [
        "responseID": outputString,
        "lastModifiedDate": outputDate,
        "responseBody": outputString,
        "state": outputString
    ], required: ["responseID", "lastModifiedDate", "responseBody", "state"])

    static let customerReviewOutput = object(properties: [
        "reviewID": outputString,
        "title": outputString,
        "body": outputString,
        "createdDate": outputDate,
        "rating": outputInteger,
        "reviewerNickname": outputString,
        "territory": outputString,
        "response": reviewResponseOutput
    ], required: [
        "reviewID", "title", "body", "createdDate", "rating", "reviewerNickname", "territory"
    ])
}
