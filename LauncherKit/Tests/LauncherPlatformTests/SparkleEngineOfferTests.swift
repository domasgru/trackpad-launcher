import Foundation
import LauncherCore
import Testing

@testable import LauncherPlatform

@MainActor @Suite struct SparkleEngineOfferTests {
    struct Row: Sendable, CustomTestStringConvertible {
        let stage: UpdateOffer.Stage
        /// What the model answers; nil is a question nobody listens to.
        let answer: Bool?
        let reply: UpdateOffer.Reply
        let asked: Int
        var testDescription: String { "\(stage) answer=\(answer.map(String.init) ?? "unset")" }
    }

    nonisolated static let rows: [Row] = [
        Row(stage: .notDownloaded, answer: true, reply: .install, asked: 1),
        Row(stage: .notDownloaded, answer: false, reply: .dismiss, asked: 1),
        Row(stage: .notDownloaded, answer: nil, reply: .dismiss, asked: 0),
        Row(stage: .downloaded, answer: true, reply: .install, asked: 1),
        Row(stage: .downloaded, answer: false, reply: .dismiss, asked: 1),
        Row(stage: .downloaded, answer: nil, reply: .dismiss, asked: 0),
        Row(stage: .installing, answer: true, reply: .skip, asked: 0),
        Row(stage: .installing, answer: false, reply: .skip, asked: 0),
        Row(stage: .installing, answer: nil, reply: .skip, asked: 0),
    ]

    @Test(arguments: rows)
    func theOfferIsAnsweredFromTheModelsOneQuestion(row: Row) {
        let model = Model(answer: row.answer)

        var question: (@MainActor (AppVersion) -> Bool)?
        if row.answer != nil { question = { model.ask($0) } }

        let reply = UpdateOffer.reply(for: row.stage, version: AppVersion("1.1.23"), asking: question)

        #expect(reply == row.reply)
        #expect(model.questions.count == row.asked)
        #expect(model.questions.allSatisfy { $0 == AppVersion("1.1.23") })
    }

    private final class Model {
        let answer: Bool?
        private(set) var questions: [AppVersion] = []

        init(answer: Bool?) { self.answer = answer }

        func ask(_ version: AppVersion) -> Bool {
            questions.append(version)
            return answer ?? false
        }
    }
}
