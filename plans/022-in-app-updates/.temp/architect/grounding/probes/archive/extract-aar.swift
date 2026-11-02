// Helper for archive.sh: extract an Apple Archive (.aar) in-process with the AppleArchive framework.
// Usage: extract-aar <archive.aar> <destination folder>
import AppleArchive
import Foundation
import System

let source = FilePath(CommandLine.arguments[1])
let destination = FilePath(CommandLine.arguments[2])
guard let file = ArchiveByteStream.fileStream(path: source, mode: .readOnly, options: [],
                                              permissions: FilePermissions(rawValue: 0o644)),
      let decompressed = ArchiveByteStream.decompressionStream(readingFrom: file),
      let decoded = ArchiveStream.decodeStream(readingFrom: decompressed),
      let extract = ArchiveStream.extractStream(extractingTo: destination, flags: [.ignoreOperationNotPermitted])
else { print("could not open streams"); exit(1) }
do {
    let count = try ArchiveStream.process(readingFrom: decoded, writingTo: extract)
    print("extracted entries:", count)
} catch { print("extract failed:", error); exit(1) }
try? extract.close(); try? decoded.close(); try? decompressed.close(); try? file.close()
