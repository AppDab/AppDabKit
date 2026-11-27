extension Schema {
    static let testFlightBuildOutput = object(properties: [
        "id": outputString, "buildNumber": outputString, "version": outputString, "platform": outputString,
        "iconURL": outputString, "externalState": outputString, "processingState": outputString,
    ], required: ["id"])

    static let testFlightBuildDetailOutput = object(properties: [
        "appID": outputString, "build": testFlightBuildOutput, "internalState": outputString,
        "uploadedDate": outputDate, "expirationDate": outputDate,
        "localizations": array(items: object(properties: [
            "id": outputString, "locale": outputString, "whatToTest": outputString,
        ], required: ["id"])),
        "bundles": array(items: object(properties: [
            "id": outputString, "bundleID": outputString, "bundleType": outputString, "sdkBuild": outputString,
            "platformBuild": outputString, "fileName": outputString, "minimumOSVersion": outputString,
            "hasOnDemandResources": outputBoolean, "includesSymbols": outputBoolean, "hasSiriKit": outputBoolean,
            "entitlements": .object(["type": .string("object")]),
        ], required: ["id", "entitlements"])),
    ], required: ["appID", "build", "localizations", "bundles"])
}
