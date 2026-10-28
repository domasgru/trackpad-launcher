import LauncherCore
import ServiceManagement

/// This app's Open at Login entry. Registration failing (unsigned build, user-disabled item) leaves the app running
/// without a login item.
@MainActor public final class SystemLoginItem: LoginItem {
    public init() {}

    public var isOn: Bool { SMAppService.mainApp.status == .enabled }

    @discardableResult public func register() -> Bool {
        do {
            try SMAppService.mainApp.register()
            return true
        } catch {
            return (error as NSError).code == kSMErrorAlreadyRegistered
        }
    }

    /// `kSMErrorJobNotFound` (never registered) is the no-op case.
    public func unregister() { try? SMAppService.mainApp.unregister() }
}
