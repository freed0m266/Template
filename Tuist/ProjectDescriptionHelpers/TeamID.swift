import Foundation

/// The Apple Developer team identifier, wrapped in a value type so signing settings read as
/// `.placeholder` rather than a bare string. `ExpressibleByStringInterpolation` lets the raw ID
/// be interpolated straight into a `SettingsDictionary` value.
///
/// The template ships **without** a real team: `.placeholder` is an empty string, so a freshly
/// generated project has `DEVELOPMENT_TEAM = ""` and automatic signing simply stays unconfigured
/// until you fill it in. Replace `.placeholder` (or add a named case, e.g. `.myOrg = "ABCDE12345"`)
/// when you start a real project.
public struct TeamID: ExpressibleByStringInterpolation, CustomStringConvertible, Sendable {
	/// Empty team — automatic signing is left unconfigured. Set your team ID when starting a project.
	public static let placeholder: Self = ""

	public let description: String

	public init(stringLiteral value: String) {
		description = value
	}
}
