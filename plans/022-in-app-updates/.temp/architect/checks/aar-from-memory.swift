// Check (after fan-out): can the AppleArchive framework extract an archive held in memory (Data), with no file for
// the archive itself, through a custom byte stream; and does its selection hook see every entry's path before it is
// written, and can `.cancel` from the hook abort the extraction? Candidate 1's in-memory download and entry filter
// rest on this.
// Usage: aar-from-memory <archive.aar> <destination folder> [<path suffix that the hook refuses with .cancel>]
import AppleArchive
import Foundation
import System

final class MemoryStream: ArchiveByteStreamProtocol {
    let data: Data
    var offset = 0
    init(_ data: Data) { self.data = data }
    func read(into buffer: UnsafeMutableRawBufferPointer) throws -> Int {
        let n = try read(into: buffer, atOffset: Int64(offset))
        offset += n
        return n
    }
    func read(into buffer: UnsafeMutableRawBufferPointer, atOffset at: Int64) throws -> Int {
        let start = Int(at)
        let n = min(buffer.count, data.count - start)
        guard n > 0 else { return 0 }
        data.withUnsafeBytes { src in buffer.copyMemory(from: UnsafeRawBufferPointer(rebasing: src[start..<start + n])) }
        return n
    }
    func write(from buffer: UnsafeRawBufferPointer) throws -> Int { throw Errno.badFileDescriptor }
    func write(from buffer: UnsafeRawBufferPointer, atOffset offset: Int64) throws -> Int { throw Errno.badFileDescriptor }
    func seek(toOffset: Int64, relativeTo: FileDescriptor.SeekOrigin) throws -> Int64 { throw Errno.illegalSeek }
    func cancel() {}
    func close() throws {}
}

let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let destination = FilePath(CommandLine.arguments[2])
let refuse = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : nil
var begins = 0
var firstPaths: [String] = []
guard let raw = ArchiveByteStream.customStream(instance: MemoryStream(data)),
      let decompressed = ArchiveByteStream.decompressionStream(readingFrom: raw),
      let decoded = ArchiveStream.decodeStream(readingFrom: decompressed),
      let extract = ArchiveStream.extractStream(
          extractingTo: destination,
          selectUsing: { message, path, _ in
              guard message == .extractBegin else { return .ok }
              begins += 1
              if firstPaths.count < 3 { firstPaths.append(path.string) }
              if let refuse, path.string.hasSuffix(refuse) { return .cancel }
              return .ok
          }, flags: [.ignoreOperationNotPermitted])
else { print("could not open streams"); exit(1) }
do {
    let n = try ArchiveStream.process(readingFrom: decoded, writingTo: extract)
    print("extracted entries from memory:", n, "extractBegin messages:", begins, "first paths:", firstPaths)
} catch { print("extract stopped:", error, "after extractBegin messages:", begins) }
try? extract.close(); try? decoded.close(); try? decompressed.close(); try? raw.close()
