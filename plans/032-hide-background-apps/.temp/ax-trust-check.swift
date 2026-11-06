// Probe: does a script run from this shell hold the Accessibility permission? Needed to put a scratch app into full
// screen for the R13 probe. Reads only.
import ApplicationServices
print("AXIsProcessTrusted:", AXIsProcessTrusted())
