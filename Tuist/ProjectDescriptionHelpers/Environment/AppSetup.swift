import struct ProjectDescription.Configuration
import struct ProjectDescription.SettingsDictionary

/// Per-environment identifiers and build settings, derived from `Environment.current`. Every value
/// that must differ between the production build and the daily TEST build lives here — bundle ID,
/// display name, app icon asset, signing, and the Swift compilation conditions — so `Project.swift`
/// and the target manifests stay environment-agnostic.
///
/// This is the **slim** variant: it deliberately carries no App Group / keychain access
/// group / extension bundle ID (the app has no extension yet). When a project adds an app extension
/// that shares data, re-add `appGroupIdentifier` / `keychainAccessGroup` computed properties here and
/// wire the entitlements in the relevant target manifests.
public struct AppSetup: Sendable {
	public static var current: Self {
		.init(environment: .current)
	}

	public let environment: Environment

	/// Shared reverse-DNS prefix. The production bundle ID is exactly this; TEST appends `.test`.
	/// Also used verbatim as the (environment-agnostic) prefix for framework/test target bundle IDs.
	public var moduleBundleIDPrefix: String {
		"com.freedommartin.template"
	}

	/// App bundle ID. `com.freedommartin.template` in production, `.test`-suffixed in testing so both
	/// builds install side by side without overwriting each other.
	public var bundleID: String {
		moduleBundleIDPrefix + environmentSuffix
	}

	/// Home-screen display name.
	public var appName: String {
		switch environment {
		case .testing:
			"Template TEST"
		case .production:
			"Template"
		}
	}

	/// App icon asset name fed to `ASSETCATALOG_COMPILER_APPICON_NAME`. TEST uses a recolored variant
	/// (`AppIcon-test`) so the two installs are distinguishable at a glance on the home screen.
	public var appIconName: String {
		switch environment {
		case .testing:
			"AppIcon-test"
		case .production:
			"AppIcon"
		}
	}

	public var teamID: TeamID { .placeholder }

	public var codeSigning: CodeSigning {
		.init(
			developmentTeam: teamID,
			identity: "Apple Development",
			provisioningSpecifier: "" // empty → Xcode selects the profile automatically
		)
	}

	public var projectConfigurations: [ProjectDescription.Configuration] {
		[
			.debug(name: "Debug", settings: settings),
			.release(name: "Release", settings: settings),
		]
	}

	/// The `.test` (testing) / `""` (production) tail appended to the bundle ID.
	private var environmentSuffix: String {
		switch environment {
		case .testing:
			".test"
		case .production:
			""
		}
	}

	/// Project-level settings applied to both configurations: signing (relocated out of
	/// `Project.swift`'s `base`) plus the environment's Swift compilation conditions. Tuist's
	/// recommended per-target defaults re-add `$(inherited) DEBUG`, so every target ends up with both
	/// the environment condition (`TEST`/`PROD`) *and* `DEBUG`/`RELEASE`.
	private var settings: SettingsDictionary {
		codeSigning.settingsDictionary
			.merging([
				"CODE_SIGN_STYLE": "Automatic",
				"DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
				"CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION": "YES",
			]) { _, new in new }
			.swiftActiveCompilationConditions(environment.swiftConditions)
	}
}

extension AppSetup: CustomStringConvertible {
	public var description: String { environment.rawValue }
}
