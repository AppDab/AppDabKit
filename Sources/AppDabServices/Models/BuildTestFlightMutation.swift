public enum BuildTestFlightMutation: Sendable {
    case addIndividualTesters([String])
    case removeIndividualTesters([String])
    case addBetaGroups([String])
    case removeBetaGroups([String])
    case submitForBetaReview(autoNotifyEnabled: Bool)
    case expire
}
