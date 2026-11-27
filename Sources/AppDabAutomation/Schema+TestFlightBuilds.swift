extension Schema {
    static let testFlightBuildDetailOutput = object(properties: [
        "appID": outputString,
        "localizations": array(items: object(properties: [
            "id": outputString, "locale": outputString, "whatToTest": outputString,
        ], required: ["id"])),
        "bundles": array(items: object(properties: [
            "id": outputString, "bundleID": outputString, "bundleType": outputString, "sdkBuild": outputString,
            "platformBuild": outputString, "fileName": outputString, "minimumOSVersion": outputString,
            "hasOnDemandResources": outputBoolean, "includesSymbols": outputBoolean, "hasSiriKit": outputBoolean,
            "entitlements": .object(["type": .string("object")]),
        ], required: ["id", "entitlements"])),
    ], required: ["localizations", "bundles"])
}
