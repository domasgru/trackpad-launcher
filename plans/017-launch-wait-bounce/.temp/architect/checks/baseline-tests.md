# Check: baseline test suite (after fan-out)

`Scripts/test.sh` (`swift test` in `LauncherKit`) on branch `feature/017-launch-wait-bounce` at 48ac9f5, 2026-10-19: 580 tests in 68 suites passed; the test run took 6.5 s after the build. The longest suites are the real-adapter ones (`SystemAppScannerTests` 6.5 s, `SystemPermissionsTests` 2.5 s); model suites finish within the same 2.5 s parallel window.
