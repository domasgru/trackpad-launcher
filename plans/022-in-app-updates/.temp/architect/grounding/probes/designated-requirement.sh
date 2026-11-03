#!/bin/sh
# Probe: what a Developer ID app's designated requirement (the identity TCC stores with a grant) contains.
# Claim tested: the designated requirement names the bundle identifier and the Developer ID team, and
# nothing version- or build-specific (no cdhash, no version), so a later version signed by the same team
# with the same identifier satisfies a grant recorded for an earlier one.
# Also lists the TCC-relevant Info.plist facts. Reads only.
for app in /Applications/Shottr.app /Applications/Ghostty.app; do
  echo "== $app"
  codesign -d -r- "$app" 2>&1 | grep -i designated
  codesign -dv "$app" 2>&1 | grep -E '^(Identifier|TeamIdentifier|CDHash)='
done
