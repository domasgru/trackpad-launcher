// Probe 1: what this machine and shell can settle.
// Prints the Accessibility trust of this process, the Screen Recording preflight (never prompts),
// whether TextEdit is already running (so a later probe can restore the machine), and the OS version.
// Build: swiftc -O -o probe-1-environment probe-1-environment.swift
import ApplicationServices
import AppKit

print("AXIsProcessTrusted:", AXIsProcessTrusted())
print("CGPreflightScreenCaptureAccess:", CGPreflightScreenCaptureAccess())
let textEdit = NSWorkspace.shared.runningApplications.filter { $0.bundleIdentifier == "com.apple.TextEdit" }
print("TextEdit running:", !textEdit.isEmpty)
print("macOS:", ProcessInfo.processInfo.operatingSystemVersionString)
