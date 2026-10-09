// Does `Observations` emit when an @Observable property is assigned a value equal to the current one?
import Foundation
import Observation

@MainActor @Observable final class Model {
    var list: [String] = ["a"]
}

@MainActor func run() async {
    let model = Model()
    var emissions: [[String]] = []
    let watcher = Task { @MainActor in
        for await value in Observations({ model.list }) {
            emissions.append(value)
            if emissions.count == 3 { break }
        }
    }
    await Task.yield()
    try? await Task.sleep(for: .milliseconds(100))
    model.list = ["a"]  // equal value
    try? await Task.sleep(for: .milliseconds(100))
    model.list = ["a"]  // equal value again
    try? await Task.sleep(for: .milliseconds(100))
    model.list = ["b"]
    for _ in 0..<20 { await Task.yield() }
    watcher.cancel()
    print("emissions:", emissions)
}

Task { @MainActor in
    await run()
    exit(0)
}
RunLoop.main.run()
