// A throwaway Ed25519 update key for Scripts/update-e2e.sh, written to the folder named by the first argument as
// ed.key (private half) and ed.pub (public half), both base64 of the raw bytes, the format Sparkle's tools read.
// Sparkle's generate_keys keeps keys in the login keychain; this leaves the keychain alone.
import CryptoKit
import Foundation

let folder = CommandLine.arguments[1]
let key = Curve25519.Signing.PrivateKey()
try key.rawRepresentation.base64EncodedString().write(toFile: "\(folder)/ed.key", atomically: true, encoding: .utf8)
try key.publicKey.rawRepresentation.base64EncodedString().write(
    toFile: "\(folder)/ed.pub", atomically: true, encoding: .utf8)
