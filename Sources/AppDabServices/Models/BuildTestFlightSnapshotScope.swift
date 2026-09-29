public enum BuildTestFlightSnapshotScope: Codable, Equatable, Sendable {
    case build
    case individualTester(String)
    case betaGroup(String)
}
