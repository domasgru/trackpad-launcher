// Probe: does a process started from this shell have the Accessibility permission?
// Every other AX probe depends on the answer.
import ApplicationServices

print("AXIsProcessTrusted:", AXIsProcessTrusted())
