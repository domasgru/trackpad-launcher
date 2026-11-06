# Adds to the check copy of the spike: the veto's second layer alone, a zero URLCache,
# and a server that answers the feed the way raw.githubusercontent.com does.
import sys

here = sys.argv[1]

path = f"{here}/SpikeHost.swift"
text = open(path).read()
text = text.replace(
    '''            case "failquit":
                let parent = Bundle.main.bundleURL.deletingLastPathComponent().path''',
    '''            case "discardquit":
                // The veto's second layer alone: the installer job keeps running, the extracted bundle goes.
                let extracted = extractedApp().map { URL(fileURLWithPath: $0).deletingLastPathComponent() }
                let gone = extracted.map { (try? FileManager.default.removeItem(at: $0)) != nil } ?? false
                log("removed the extracted folder: \\(gone)")
                submitRelauncher()
                log("ending this process")
                exit(0)
            case "failquit":
                let parent = Bundle.main.bundleURL.deletingLastPathComponent().path''',
)
text = text.replace(
    '''        if FileManager.default.fileExists(atPath: "\\(runDir)/no-cookies") {''',
    '''        if FileManager.default.fileExists(atPath: "\\(runDir)/no-cache") {
            URLCache.shared = URLCache(memoryCapacity: 0, diskCapacity: 0)
            log("URLCache.shared at zero")
        }
        if FileManager.default.fileExists(atPath: "\\(runDir)/no-cookies") {''',
)
open(path, "w").write(text)

path = f"{here}/server.py"
text = open(path).read()
text = text.replace(
    '''    def end_headers(self):
        self.send_header("Set-Cookie", "probe=abc123; Max-Age=31536000; Path=/")
        super().end_headers()
''',
    '''    def guess_type(self, path):
        # What raw.githubusercontent.com sends for a committed file.
        if path.endswith(".xml"):
            return "text/plain; charset=utf-8"
        return super().guess_type(path)

    def end_headers(self):
        self.send_header("Cache-Control", "max-age=300")
        self.send_header("ETag", '"probe-etag"')
        super().end_headers()
''',
)
open(path, "w").write(text)
print("patched")
