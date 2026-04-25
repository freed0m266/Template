import ProjectDescription
import ProjectDescriptionHelpers

let features: [Feature] = [
	example
]
let appTargets: [Target] = features.flatMap(\.allTargets)

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
			"TARGETED_DEVICE_FAMILY": "1",
			"DEVELOPMENT_TEAM": "", // Set Team ID when starting a new project.
			"CODE_SIGN_STYLE": "Automatic",
			"DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
			"CODE_SIGN_ALLOW_ENTITLEMENTS_MODIFICATION": "YES"
		],
		configurations: [
			.debug(name: "Debug"),
			.release(name: "Release"),
		]
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
				executable: .executable("Template"),
				arguments: .arguments(
					environmentVariables: [
						"OS_ACTIVITY_MODE": "disable",
					]
				)
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
