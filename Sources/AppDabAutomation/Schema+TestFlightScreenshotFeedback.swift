extension Schema {
    static let testFlightScreenshotFeedbackOutput = object(properties: [
        "id": outputString, "comment": outputString, "createdDate": outputDate,
        "buildID": outputString, "buildNumber": outputString, "version": outputString,
        "deviceModel": outputString, "osVersion": outputString,
        "attachments": array(items: object(properties: [
            "url": outputString, "width": outputInteger, "height": outputInteger,
        ], required: [])),
    ], required: ["id", "attachments"])
}
