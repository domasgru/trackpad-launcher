import CardContract
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("card-contract: \(message)\n".utf8))
    exit(1)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 5, arguments[1] == "--team", arguments[3] == "--identifier" else {
    fail("usage: card-contract <archive> --team <team> --identifier <identifier>")
}

if let reason = refusal(ofArchive: URL(fileURLWithPath: arguments[0]), team: arguments[2], identifier: arguments[4]) {
    fail(reason)
}
