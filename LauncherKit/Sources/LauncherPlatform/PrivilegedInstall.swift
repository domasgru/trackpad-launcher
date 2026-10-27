import Foundation
import LauncherCore
import Security

/// The one privileged call, placed below the script so a test runs the real script. Real: `AuthorizationAdministrator`.
/// Test: runs the same command unprivileged.
protocol Administrator: Sendable {
    /// Asks for an administrator's name and password the way Finder does, then runs `/bin/sh -c script sh arguments…`
    /// as root. Blocks; called off the main actor.
    func run(script: String, arguments: [String]) -> AdministratorResult
}

enum AdministratorResult: Equatable, Sendable { case ran(exitStatus: Int32), cancelled, failed }

/// Swapping a staged copy into /Applications as root when this account cannot write there.
enum PrivilegedInstall {
    /// Takes the paths as "$1" (destination), "$2" (staged) and "$3" (aside, inside the staging folder), never
    /// interpolated: the old copy moves to the aside path, the staged copy moves in, and when that fails the old copy
    /// moves back and the exit is non-zero; then the aside copy is removed, a failure there ignored, and the exit is
    /// zero. So a status matches what /Applications holds. Only a kill between the two moves leaves /Applications
    /// without the app and the old copy in the staging folder, never inside /Applications.
    static let script = """
        destination="$1"; staged="$2"; aside="$3"
        moved=no
        if [ -e "$destination" ] || [ -L "$destination" ]; then
            /bin/mv -- "$destination" "$aside" || exit 1
            moved=yes
        fi
        if ! /bin/mv -- "$staged" "$destination"; then
            if [ "$moved" = yes ]; then /bin/mv -- "$aside" "$destination"; fi
            exit 1
        fi
        /bin/rm -rf -- "$aside"
        exit 0
        """

    static func swap(
        _ staged: URL, into destination: URL, asideIn folder: URL, by administrator: any Administrator
    ) -> InstallOutcome {
        let aside = folder.appending(path: "Replaced " + destination.lastPathComponent)
        let result = administrator.run(script: script, arguments: [destination.path, staged.path, aside.path])
        switch result {
        case .ran(exitStatus: 0): return .installed
        case .ran: return .failed(reason: Copy.applicationsFolderNotChanged)
        case .cancelled: return .cancelled
        case .failed: return .failed(reason: Copy.cannotWriteToApplications)
        }
    }
}

/// Authorization Services' execute right, as Finder asks for it. `AuthorizationExecuteWithPrivileges` is deprecated and
/// has no public Swift import, but is still exported: resolved with `dlsym`, no link flags.
struct AuthorizationAdministrator: Administrator {
    private typealias ExecuteWithPrivileges = @convention(c) (
        AuthorizationRef, UnsafePointer<CChar>, AuthorizationFlags, UnsafePointer<UnsafeMutablePointer<CChar>?>,
        UnsafeMutablePointer<UnsafeMutablePointer<FILE>?>?
    ) -> OSStatus

    func run(script: String, arguments: [String]) -> AdministratorResult {
        // RTLD_DEFAULT
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "AuthorizationExecuteWithPrivileges") else {
            return .failed
        }
        let execute = unsafeBitCast(symbol, to: ExecuteWithPrivileges.self)

        var created: AuthorizationRef?
        guard AuthorizationCreate(nil, nil, [], &created) == errAuthorizationSuccess, let authorization = created else {
            return .failed
        }
        defer { AuthorizationFree(authorization, []) }

        let granted = kAuthorizationRightExecute.withCString { name -> OSStatus in
            var item = AuthorizationItem(name: name, valueLength: 0, value: nil, flags: 0)
            return withUnsafeMutablePointer(to: &item) { items in
                var rights = AuthorizationRights(count: 1, items: items)
                return AuthorizationCopyRights(
                    authorization, &rights, nil, [.interactionAllowed, .extendRights, .preAuthorize], nil)
            }
        }
        if granted == errAuthorizationCanceled { return .cancelled }
        guard granted == errAuthorizationSuccess else { return .failed }

        let argv: [UnsafeMutablePointer<CChar>?] = (["-c", script, "sh"] + arguments).map { strdup($0) } + [nil]
        defer { argv.forEach { free($0) } }
        var pipe: UnsafeMutablePointer<FILE>?
        guard execute(authorization, "/bin/sh", [], argv, &pipe) == errAuthorizationSuccess else { return .failed }

        // The child's status is not returned: read the pipe to its end, then wait on the child.
        if let pipe {
            var buffer = [UInt8](repeating: 0, count: 256)
            while fread(&buffer, 1, buffer.count, pipe) > 0 {}
            fclose(pipe)
        }
        var status: Int32 = 0
        guard wait(&status) > 0, status & 0x7f == 0 else { return .failed }
        return .ran(exitStatus: (status >> 8) & 0xff)
    }
}
