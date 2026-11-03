# Development logs: Debug builds get their own bundle identifier

## Specify
- (none logged)

## Plan
- The strategy claimed the pure tests prove the release-lists-Debug direction, which they do not → reworded: that half rests on `others()` being one flat map over the whole family and on the slice's by-hand R2 step; the decision now states the flat map.
- The R1 hand check could not tell fixed from unfixed: the release's TCC entries still hold an old Debug build's requirement, so its row would show on but refused either way → the check starts with `tccutil reset` of Accessibility and ScreenCapture for the release identifier and covers both permissions; Further Notes carry the reset as the developer's one-off recovery.
- The release-guard acceptance criterion was "read the comparison", which cannot fail → run `release.sh --archive-only` on `make run`'s Debug product and expect a failure naming the identifier; the match is whole-line as the Team ID check's; the script's usage text follows; the rationale names the update's genuineness check instead of "stranding grants".
- The port's doc comment on `others()` ("with this bundle identifier") would become false → the port is untouched but for that comment.
- T3 (a foreign identifier containing "debug") and the family's order were over-specified → T3 dropped, the family is a set, T4 renumbered to T3.
- The R3 grep is already true on main and cannot fail → replaced by a `git diff main --stat` check listing the files the change may touch.
- Nothing checked the Debug product itself → `make run`'s product's `CFBundleIdentifier` is read.
- "The identifiers live only in the project spec" contradicted the release guard → reworded to the project spec and the release command's guard.
- The glossary's "a release copy opened by hand stops it" was too broad (a release outside /Applications shows only the move dialog) → "the installed release opened by hand stops it".
- The architecture's sentence about the adapter listing both identifiers was implementation detail → dropped; the Shape bullet's "stops every other running copy" gained "Debug or release".
- The perf build keeping the release identifier, and so the shared TCC entry, sat only in Further Notes → stated as a non-goal.
- The README did not mention the second entry → one line added after the animation tuner's.

## Implement
- Review: T3 looped over the two identifiers and T1/T2 were two tests differing only in input (swift-testing-pro: prefer parameterized tests) → T3 is parameterized over `com.apple.finder.debug` and `com.apple.finder`, T1 and T2 are one parameterized test over R1's two literals.
- Review: the release guard's `grep -qx "Identifier=$BUNDLE_ID"` read the identifier as a regex, so the match was not exact → `grep -qxF`.
- Review, not fixed: keeping the release identifier in `base` with only a Debug override (the plan chose two per-configuration values, prototyped); a `BundleID` type in the adapter (the strings never cross the port); failing the identifier earlier in a full release (the plan places the guard in the archive check).
