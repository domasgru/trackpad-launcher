// A throwaway EdDSA key for the spike, written to the spike's own folder.
// Sparkle's generate_keys stores keys in the login keychain; this leaves it untouched.
import CryptoKit
import Foundation

let dir = CommandLine.arguments[1]
let key = Curve25519.Signing.PrivateKey()
try key.rawRepresentation.base64EncodedString().write(toFile: "\(dir)/ed.key", atomically: true, encoding: .utf8)
try key.publicKey.rawRepresentation.base64EncodedString().write(toFile: "\(dir)/ed.pub", atomically: true, encoding: .utf8)
print("public", key.publicKey.rawRepresentation.base64EncodedString())
