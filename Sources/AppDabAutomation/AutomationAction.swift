import AppDabServices

public protocol AutomationAction: Sendable {
    associatedtype Input: AutomationActionInput
    associatedtype Output: Codable, Equatable, Sendable

    static var descriptor: AutomationActionDescriptor { get }
    static var supportsDirectWriteExecution: Bool { get }

    init()

    func perform(input: Input, dataProvider: any AutomationDataProviding) async throws -> Output
    func summary(for output: Output) -> String
    func data(for output: Output) throws -> JSONValue
}

public extension AutomationAction {
    static var supportsDirectWriteExecution: Bool {
        false
    }
}
