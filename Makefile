# The project's commands, like a web project's `npm run …`. Run `make` (or `make help`) to list them.
# Each target calls a script in Scripts/; the logic lives there, not here.

DEV_APP := build/dev/Build/Products/Debug/Trackpad Launcher.app
export DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer

.DEFAULT_GOAL := help
.PHONY: help test project run release release-patch release-minor release-major

help: ## List the commands
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-15s %s\n", $$1, $$2}'

test: ## Run every test
	Scripts/test.sh

project: ## Regenerate TrackpadLauncher.xcodeproj from project.yml
	xcodegen generate

run: project ## Build the development app and open it, replacing a running one
	xcodebuild build -project TrackpadLauncher.xcodeproj -scheme TrackpadLauncher -configuration Debug \
		-derivedDataPath build/dev -quiet
	@# Opening the same bundle again would only bring the old process to the front, with the old code.
	@pkill -f "$(CURDIR)/$(DEV_APP)/Contents/MacOS/Trackpad Launcher" && sleep 1 || true
	open "$(DEV_APP)"

release: ## Release the version already in Config/Version.xcconfig (the first release, or a retry)
	Scripts/release.sh

release-patch: ## Release a fix: 1.2.3 → 1.2.4
	Scripts/release.sh patch

release-minor: ## Release new features: 1.2.3 → 1.3.0
	Scripts/release.sh minor

release-major: ## Release big changes: 1.2.3 → 2.0.0
	Scripts/release.sh major
