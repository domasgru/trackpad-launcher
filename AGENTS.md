# Trackpad Launcher

`docs/architecture.md` holds the core decisions, and `make` lists the project's commands.

- **Quick gate**: `make test`, the per-change check. It builds and tests the `LauncherKit` package only.
- **Full gate**: `make gate`: the quick gate, then a build of the app target, without opening it. The final line says "gate: all green" only when both pass.
