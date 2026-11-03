import Foundation
import Testing

/// Runs blocking `work` on a thread of its own and awaits the result, so a test that has to block never holds one of
/// the cooperative pool's few threads. Expectations stay outside `work`: Swift Testing cannot attribute them from a
/// bare thread. nil, with an issue recorded, when `work` outlasts `limit`.
func onItsOwnThread<T: Sendable>(
    _ what: String, within limit: Duration = .seconds(50), _ work: @escaping @Sendable () throws -> T
) async throws -> T? {
    let result: Result<T, any Error>? = await awaiting(what, within: limit) {
        (done: @escaping @Sendable (Result<T, any Error>) -> Void) in
        Thread.detachNewThread { done(Result { try work() }) }
    }
    return try result?.get()
}
