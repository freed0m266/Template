import ProjectDescription
import ProjectDescriptionHelpers

let features: [Feature] = [
	example
]
let appTargets: [Target] = features.flatMap(\.allTargets)

let setup = AppSetup.current

let project = Project(
	name: "Template",
	organizationName: "Freedom Martin, s.r.o.",
	options: .options(
		developmentRegion: "en"
	),
	settings: .settings(
		base: [
			"SWIFT_VERSION": "6.0",
			"IPHONEOS_DEPLOYMENT_TARGET": "26.0",
			"TARGETED_DEVICE_FAMILY": "1"
		],
		// Signing (`DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE`, …) and the environment's Swift
		// compilation conditions live in `AppSetup.projectConfigurations` — see ADR 0001.
		configurations: setup.projectConfigurations
	),
	targets: [
		app,
		core,
		design,
		resources,
		testing
	]
	+ appTargets,
	schemes: [
		.scheme(
			name: "Template",
			buildAction: .buildAction(
				targets: ["Template"]
			),
			runAction: .runAction(
				executable: .executable("Template")
			),
			archiveAction: .archiveAction(
				configuration: "Release"
			),
			profileAction: .profileAction(
				configuration: "Release", executable: .executable("Template")
			)
		)
	]
)
