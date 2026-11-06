// Prints whether this process may use the Accessibility API, and so whether it can click.
import ApplicationServices

print("AXIsProcessTrusted:", AXIsProcessTrusted())
print("CGPreflightPostEventAccess:", CGPreflightPostEventAccess())
print("CGPreflightScreenCaptureAccess:", CGPreflightScreenCaptureAccess())
