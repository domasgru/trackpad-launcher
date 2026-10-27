import LauncherCore
import ServiceManagement

/// This app's Open at Login entry. Registration failing (unsigned build, user-disabled item) leaves the app running
/// without a login item.
@MainActor public final class SystemLoginItem: LoginItem {
    public init() {}

    @discardableResult public func register() -> Bool {
        do {
            try SMAppService.mainApp.register()
            return true
        } catch {
            return (error as NSError).code == kSMErrorAlreadyRegistered
        }
    }
}
