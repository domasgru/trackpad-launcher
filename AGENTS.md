# Trackpad Launcher

`docs/architecture.md` holds the core decisions, and `make` lists the project's commands.

- **Gate**: `make test`. It is both the quick gate and the full gate. It builds and tests the `LauncherKit` package only: the app target is built by `make run`, which also opens it.
