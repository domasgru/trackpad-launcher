import Testing

/// Every suite that launches real apps or reads the system's running apps and frontmost app lives in this one
/// serialized parent. Swift Testing runs top-level suites in parallel and `.serialized` only orders the tests inside a
/// suite, so without the parent a probe launched by one suite shows up in another suite's read of the workspace.
@Suite(.serialized) enum RealAppTests {}
