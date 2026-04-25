import ProjectDescription

extension TargetScript {
	/// Runs SwiftLint via Mint as a post-build step.
	public static var swiftlint: TargetScript {
		.post(
			path: "BuildPhases/Swiftlint.sh",
			name: "SwiftLint",
			basedOnDependencyAnalysis: false
		)
	}
	
	/// Set app versions to Info.plist
	static var setBundleVersion: TargetScript {
		.post(
			path: "BuildPhases/SetBundleVersion.sh",
			name: "Set app versions",
			basedOnDependencyAnalysis: false
		)
	}
}
