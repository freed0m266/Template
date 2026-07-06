import ProjectDescription

/// Signing settings bundle. With `CODE_SIGN_STYLE = Automatic`, Xcode resolves the concrete
/// certificate/profile per configuration (development for Run, distribution for Archive); these
/// values are the automatic-signing preferences, not a manual override.
public struct CodeSigning {
	public let developmentTeam: TeamID
	public let identity: String
	public let provisioningSpecifier: String

	public var settingsDictionary: SettingsDictionary {
		[
			"DEVELOPMENT_TEAM": .string(developmentTeam.description),
			"CODE_SIGN_IDENTITY": .string(identity),
			"PROVISIONING_PROFILE_SPECIFIER": .string(provisioningSpecifier),
		]
	}
}
