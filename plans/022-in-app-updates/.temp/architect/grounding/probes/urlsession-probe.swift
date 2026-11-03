// Probe: what URLSession sends and does, against urlsession-server.py on 127.0.0.1:<port>.
// Claims tested:
//  (a) the headers an ephemeral session sends by default (User-Agent, Accept-Language, cookies);
//  (b) whether a per-request User-Agent and Accept-Language override the defaults;
//  (c) whether timeoutIntervalForRequest fails a download that stops making progress (idle timer),
//      and does NOT fail one that keeps trickling bytes slower than the timeout in total;
//  (d) whether a file fetched with download(for:) carries a com.apple.quarantine attribute;
//  (e) whether redirects are followed and with which headers.
// Usage: swift urlsession-probe.swift <port>. Writes nothing outside the system temp directory, and
// deletes what download(for:) leaves there.
import Foundation

let port = CommandLine.arguments[1]
func url(_ path: String) -> URL { URL(string: "http://127.0.0.1:\(port)\(path)")! }

func session(timeout: TimeInterval = 60) -> URLSession {
    let c = URLSessionConfiguration.ephemeral
    c.timeoutIntervalForRequest = timeout
    return URLSession(configuration: c)
}

func run() async {
    print("== (a) ephemeral session, request with no headers set")
    _ = try? await session().data(for: URLRequest(url: url("/echo?a")))

    print("== (b) per-request User-Agent and Accept-Language set")
    var r = URLRequest(url: url("/echo?b"))
    r.setValue("TrackpadLauncher", forHTTPHeaderField: "User-Agent")
    r.setValue("en", forHTTPHeaderField: "Accept-Language")
    _ = try? await session().data(for: r)

    print("== (b2) httpAdditionalHeaders on the configuration")
    let c = URLSessionConfiguration.ephemeral
    c.httpAdditionalHeaders = ["User-Agent": "TrackpadLauncher", "Accept-Language": "en"]
    _ = try? await URLSession(configuration: c).data(for: URLRequest(url: url("/echo?b2")))

    print("== (e) redirect followed, with per-request headers")
    var rr = URLRequest(url: url("/redirect"))
    rr.setValue("TrackpadLauncher", forHTTPHeaderField: "User-Agent")
    _ = try? await session().data(for: rr)

    print("== (c) /stall with timeoutIntervalForRequest = 3")
    var t0 = Date()
    do { _ = try await session(timeout: 3).download(for: URLRequest(url: url("/stall"))); print("stall: no error") }
    catch { print("stall: error after", String(format: "%.1f", Date().timeIntervalSince(t0)), "s:", (error as NSError).domain, (error as NSError).code) }

    print("== (c2) /slow (1 byte/s for 6 s) with timeoutIntervalForRequest = 3")
    t0 = Date()
    do { let (u, _) = try await session(timeout: 3).download(for: URLRequest(url: url("/slow")))
        print("slow: finished after", String(format: "%.1f", Date().timeIntervalSince(t0)), "s"); try? FileManager.default.removeItem(at: u) }
    catch { print("slow: error after", String(format: "%.1f", Date().timeIntervalSince(t0)), "s:", (error as NSError).code) }

    print("== (d) download(for:) file attributes")
    do {
        let (u, _) = try await session().download(for: URLRequest(url: url("/file")))
        print("downloaded to", u.path)
        let names = try? FileManager.default.attributesOfItem(atPath: u.path)
        _ = names
        let size = listxattr(u.path, nil, 0, 0)
        if size > 0 {
            var buf = [CChar](repeating: 0, count: size)
            listxattr(u.path, &buf, size, 0)
            print("xattrs:", String(decoding: buf.map { UInt8(bitPattern: $0) }, as: UTF8.self).split(separator: "\0"))
        } else { print("xattrs: none") }
        try? FileManager.default.removeItem(at: u)
    } catch { print("download error", error) }
}

let done = DispatchSemaphore(value: 0)
Task { await run(); done.signal() }
done.wait()
