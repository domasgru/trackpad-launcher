// Probe: when a background thread creates `Task { @MainActor in … }` jobs one after another (the hop the hardware
// adapter uses for fired gestures), do they run on the main actor in creation order? A swipe would deliver
// began / moved(travel) / ended as ~100 Hz of such hops from one frame thread, so order matters. Compared with
// `DispatchQueue.main.async`, which is documented FIFO. Shows false if any trial runs out of order.
import Dispatch
import Foundation
import Synchronization

let trials = 5
let count = 5000
final class Log: Sendable {
    let seen = Mutex<[Int]>([])
}

@MainActor func record(_ log: Log, _ i: Int) { log.seen.withLock { $0.append(i) } }

func runTrial(_ label: String, enqueue: @escaping @Sendable (Log, Int) -> Void) {
    let log = Log()
    let done = DispatchSemaphore(value: 0)
    let producer = Thread {
        for i in 0..<count { enqueue(log, i) }
        done.signal()
    }
    producer.qualityOfService = .userInteractive
    producer.start()
    done.wait()
    // Drain main until all arrived (bounded).
    let deadline = Date(timeIntervalSinceNow: 10)
    while log.seen.withLock({ $0.count }) < count, Date() < deadline {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
    }
    let seen = log.seen.withLock { $0 }
    let inOrder = seen == Array(0..<count)
    var firstBad = -1
    for (i, v) in seen.enumerated() where v != i { firstBad = i; break }
    print("\(label): received=\(seen.count)/\(count) inOrder=\(inOrder)" + (firstBad >= 0 ? " firstOutOfOrderAt=\(firstBad) value=\(seen[firstBad])" : ""))
}

for t in 1...trials {
    runTrial("trial \(t) Task{@MainActor}") { log, i in
        Task { @MainActor in record(log, i) }
    }
}
for t in 1...trials {
    runTrial("trial \(t) DispatchQueue.main.async") { log, i in
        DispatchQueue.main.async { MainActor.assumeIsolated { record(log, i) } }
    }
}
print("done")
