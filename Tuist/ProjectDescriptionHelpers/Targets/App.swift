import ProjectDescription

let appBundleId = "com.freedommartin.template"

private let targetName = "Template"

public let app: Target = .target(
	name: targetName,
	destinations: [.iPhone],
	product: .app,
	bundleId: appBundleId,
	infoPlist: .extendingDefault(with: [
		"CFBundleDisplayName": .string(targetName),
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
		.setBundleVersion
	],
	dependencies: [
		.target(core),
		.target(design),
		.target(example),
		.target(resources)
	],
	settings: .settings(
		base: [
			"ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
		]
	)
)
