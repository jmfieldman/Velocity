# Close any currently-open project in Xcode before regenerating the .xcodeproj file, and re-open.
# If the script fails, the project is not open and we can simply regenerate the project.
# This is the default target if a user types 'make' without arguments.	
project:
	@test $(shell osascript bin/kill-xcode.applescript "$(xcodeproj_path)") && ($(MAKE) xcodegen && sleep 1 && open -g "$(xcodeproj_path)") || $(MAKE) xcodegen

# The actual invocation of `xcodegen`, followed by project sanitization to optimize incremental
# build performance.
xcodegen:	
	@mint run xcodegen
	@mint run velocity sanitize-xcodegen-project \
		--xcodeproj-path $(xcodeproj_file) \
		--modules-yml-path project-modules.yml \
		--project-yml-paths project.yml \
		--verbose

# Used to manually run the Swift formatter. This is typically invoked by githooks, so is not
# necessary to run manually.
format:
	@mint run swiftformat --config .swiftformat .

# This command should be run any time the dependencies.yml file is updated. It makes sure
# The client has the latest dependency versions, and generates project-dependencies.yml
pulldeps:
	@mint run velocity pull-dependencies --verbose
	@mint run velocity generate-xcodegen-deps \
		--dependency-output-path local \
		--verbose

# This performs work needed when the internal module graph is updated.
# 1. Calls generate-inject to update the run-time injection code
# 2. Calls generate-xcodegen-modules to update project-modules.yml
modules:
	@mint run velocity generate-inject \
		--modules-path Modules \
		--output-file Modules/Injection/Injection/Injection.swift \
		--inject-function-name registerInjections \
		--verbose
	@mint run velocity generate-xcodegen-modules \
		--regen-imports \
		--regen-info-plists \
		--root-path Modules \
		--platforms iOS \
		--verbose

# This is a relatively simple example of how dynamic leaf modules work.
# The strings module contains resources, so should be compiled as a dynamic
# framework, and may not rely on any internal static frameworks.
#
# The yonaskolb/Stringly library itself is useful for smaller personal apps
# but does not lend itself well to apps that require web-based string admin
# or OTA update features.
#
# This block also represents a personal preference of using `Z` as the prefix
# for localized string keys so they are more visually distinct.
strings:
	@mint run stringly generate Modules/Strings/Strings/Strings.yml -d Modules/Strings/Strings -b Base
	@mint run stringly generate Modules/Strings/Strings/Strings.yml -d Modules/Strings/Strings -b en
	@echo "[Generating Strings]"	
	@sed -i '' 's/extension Strings /extension Z /g' Modules/Strings/Strings/Strings.swift
	@sed -i '' 's/public enum Strings /public enum Z /g' Modules/Strings/Strings/Strings.swift
	@sed -i '' 's/Strings.localized/Z.localized/g' Modules/Strings/Strings/Strings.swift
	@sed -i '' 's/public static var/public static let/g' Modules/Strings/Strings/Strings.swift

# Install all project dependencies and create the project file.
bootstrap:
	@brew install mint
	@mint bootstrap
	# Add this to normal projects (unnecessary in this demo) to install format-on-commit hooks.
	# @cp bin/githooks/pre-commit .git/hooks/.
	$(MAKE) pulldeps
	$(MAKE) modules
	$(MAKE) xcodegen

# Commands are not associated directly with files are declared in the .PHONY section
.PHONY: project \
		xcodegen \
		format \
		modules \
		strings \
		bootstrap

xcodeproj_file := "CoasterPal.xcodeproj"
xcodeproj_path := $(abspath $(xcodeproj_file))
