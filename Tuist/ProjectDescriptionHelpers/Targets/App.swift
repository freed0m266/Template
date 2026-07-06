import ProjectDescription

private let targetName = "Template"
private let setup = AppSetup.current

/// Reverse-DNS prefix for framework and test target bundle IDs. Environment-agnostic on purpose:
/// embedded frameworks don't install separately, so they keep a stable ID across TEST/PROD. Only the
/// app target takes the `.test` suffix (see `AppSetup`), via `setup.bundleID`.
let appBundleId = setup.moduleBundleIDPrefix

public let app: Target = .target(
	name: targetName,
	destinations: [.iPhone],
	product: .app,
	bundleId: setup.bundleID,
	infoPlist: .extendingDefault(with: [
		"CFBundleDisplayName": .string(setup.appName),
		"UILaunchScreen": [
			"UIColorName": "BackgroundColor",
		],
		"UIUserInterfaceStyle": "Dark",
		"UIApplicationSceneManifest": [
			"UIApplicationSupportsMultipleScenes": false,
			"UISceneConfigurations": .dictionary([:]),
		],
	]),
	sources: ["\(targetName)/Sources/**"],
	resources: ["\(targetName)/Resources/**"],
	scripts: [
		.swiftlint,
		.setVersions
	],
	dependencies: [
		.target(core),
		.target(design),
		.target(example),
		.target(resources)
	],
	settings: .settings(
		base: [
			"ASSETCATALOG_COMPILER_APPICON_NAME": .string(setup.appIconName),
		]
	)
)
