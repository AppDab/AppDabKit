import BagbutikTestFlightModels
import Foundation

public struct BetaGroupSummary: Codable, Equatable, Sendable {
    public let betaGroupID: String
    public let name: String
    public let isInternalGroup: Bool?
    public let hasAccessToAllBuilds: Bool?
    public let feedbackEnabled: Bool?
    public let iosBuildsAvailableForAppleSiliconMac: Bool?
    public let iosBuildsAvailableForAppleVision: Bool?
    public let publicLinkEnabled: Bool?
    public let publicLinkLimit: Int?
    public let publicLinkLimitEnabled: Bool?
    public let publicLink: String?

    public init(betaGroupID: String, name: String, isInternalGroup: Bool? = nil, hasAccessToAllBuilds: Bool? = nil, feedbackEnabled: Bool? = nil, iosBuildsAvailableForAppleSiliconMac: Bool? = nil, iosBuildsAvailableForAppleVision: Bool? = nil, publicLinkEnabled: Bool? = nil, publicLinkLimit: Int? = nil, publicLinkLimitEnabled: Bool? = nil, publicLink: String? = nil) {
        self.betaGroupID = betaGroupID
        self.name = name
        self.isInternalGroup = isInternalGroup
        self.hasAccessToAllBuilds = hasAccessToAllBuilds
        self.feedbackEnabled = feedbackEnabled
        self.iosBuildsAvailableForAppleSiliconMac = iosBuildsAvailableForAppleSiliconMac
        self.iosBuildsAvailableForAppleVision = iosBuildsAvailableForAppleVision
        self.publicLinkEnabled = publicLinkEnabled
        self.publicLinkLimit = publicLinkLimit
        self.publicLinkLimitEnabled = publicLinkLimitEnabled
        self.publicLink = publicLink
    }

    init(_ group: BetaGroup) {
        self.init(betaGroupID: group.id, name: group.attributes?.name ?? group.id,
                  isInternalGroup: group.attributes?.isInternalGroup,
                  hasAccessToAllBuilds: group.attributes?.hasAccessToAllBuilds,
                  feedbackEnabled: group.attributes?.feedbackEnabled,
                  iosBuildsAvailableForAppleSiliconMac: group.attributes?.iosBuildsAvailableForAppleSiliconMac,
                  iosBuildsAvailableForAppleVision: group.attributes?.iosBuildsAvailableForAppleVision,
                  publicLinkEnabled: group.attributes?.publicLinkEnabled,
                  publicLinkLimit: group.attributes?.publicLinkLimit,
                  publicLinkLimitEnabled: group.attributes?.publicLinkLimitEnabled,
                  publicLink: group.attributes?.publicLink)
    }
}

public struct BetaGroupList: Codable, Equatable, Sendable {
    public let appID: String
    public let betaGroups: [BetaGroupSummary]
    public let pagination: PaginationMetadata

    public init(appID: String, betaGroups: [BetaGroupSummary], pagination: PaginationMetadata) {
        self.appID = appID
        self.betaGroups = betaGroups
        self.pagination = pagination
    }
}

public struct BetaGroupBuildMembership: Codable, Equatable, Sendable {
    public let betaGroup: BetaGroupSummary
    public let buildID: String
    public let isMember: Bool

    public init(betaGroup: BetaGroupSummary, buildID: String, isMember: Bool) {
        self.betaGroup = betaGroup
        self.buildID = buildID
        self.isMember = isMember
    }
}

public struct BetaGroupChanges: Codable, Equatable, Sendable {
    public let name: String?
    public let feedbackEnabled: Bool?
    public let iosBuildsAvailableForAppleSiliconMac: Bool?
    public let iosBuildsAvailableForAppleVision: Bool?
    public let publicLinkEnabled: Bool?
    public let publicLinkLimit: Int?
    public let publicLinkLimitEnabled: Bool?

    public init(name: String? = nil, feedbackEnabled: Bool? = nil, iosBuildsAvailableForAppleSiliconMac: Bool? = nil, iosBuildsAvailableForAppleVision: Bool? = nil, publicLinkEnabled: Bool? = nil, publicLinkLimit: Int? = nil, publicLinkLimitEnabled: Bool? = nil) {
        self.name = name
        self.feedbackEnabled = feedbackEnabled
        self.iosBuildsAvailableForAppleSiliconMac = iosBuildsAvailableForAppleSiliconMac
        self.iosBuildsAvailableForAppleVision = iosBuildsAvailableForAppleVision
        self.publicLinkEnabled = publicLinkEnabled
        self.publicLinkLimit = publicLinkLimit
        self.publicLinkLimitEnabled = publicLinkLimitEnabled
    }

    public var isEmpty: Bool {
        name == nil && feedbackEnabled == nil && iosBuildsAvailableForAppleSiliconMac == nil && iosBuildsAvailableForAppleVision == nil && publicLinkEnabled == nil && publicLinkLimit == nil && publicLinkLimitEnabled == nil
    }

    public func isApplied(to group: BetaGroupSummary) -> Bool {
        (name == nil || group.name == name) &&
        (feedbackEnabled == nil || group.feedbackEnabled == feedbackEnabled) &&
        (iosBuildsAvailableForAppleSiliconMac == nil || group.iosBuildsAvailableForAppleSiliconMac == iosBuildsAvailableForAppleSiliconMac) &&
        (iosBuildsAvailableForAppleVision == nil || group.iosBuildsAvailableForAppleVision == iosBuildsAvailableForAppleVision) &&
        (publicLinkEnabled == nil || group.publicLinkEnabled == publicLinkEnabled) &&
        (publicLinkLimit == nil || group.publicLinkLimit == publicLinkLimit) &&
        (publicLinkLimitEnabled == nil || group.publicLinkLimitEnabled == publicLinkLimitEnabled)
    }
}
