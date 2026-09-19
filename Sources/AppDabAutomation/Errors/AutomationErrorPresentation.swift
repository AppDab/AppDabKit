public enum AutomationErrorPresentation {
    public static func present(_ error: Error) -> AutomationPresentedError {
        if let executionError = error as? AutomationExecutionError {
            return .init(
                code: executionError.code,
                message: executionError.errorDescription ?? "The automation action failed."
            )
        }
        let actionError = if let actionError = error as? AutomationActionError {
            actionError
        } else {
            AutomationActionError.upstream(error.localizedDescription)
        }
        return .init(
            code: actionError.code,
            message: actionError.errorDescription ?? "The automation action failed."
        )
    }
}
