import enum ProjectDescription.Environment

/// Build environment resolved at `tuist generate` time from the `TUIST_ENVIRONMENT` env-var.
/// One environment is baked into the generated project; switching means regenerating.
///
/// Default is `.testing` (see ADR 0001): daily `tuist generate && Run` produces a sandboxed TEST
/// build (`.test` bundle ID, `Template TEST` on the home screen, recolored `AppIcon-test`) that
/// installs alongside a production build. The production archive path **must** prefix
/// `TUIST_ENVIRONMENT=Production tuist generate` — without it the generated workspace bakes in
/// `.test` identifiers.
public enum Environment: String, Sendable {
	/// Reads `TUIST_ENVIRONMENT`; any unset or unrecognized value falls back to `.testing` so a
	/// typo (`TUIST_ENVIRONMENT=Prod`) can never silently produce a production build — it degrades
	/// safely to the sandboxed default instead.
	public static var current: Self {
		.init(
			rawValue: ProjectDescription.Environment.environment
				.getString(default: Self.testing.rawValue)
		) ?? .testing
	}

	case testing = "Testing"
	case production = "Production"

	var isDebug: Bool {
		self == .testing
	}

	/// Swift active-compilation conditions injected project-wide (orthogonal to the `DEBUG`/`RELEASE`
	/// axis, which Tuist keeps supplying per configuration). Runtime code branches on `#if TEST`.
	var swiftConditions: [String] {
		switch self {
		case .testing:
			["TEST"]
		case .production:
			["PROD"]
		}
	}
}

extension Environment: CustomStringConvertible {
	public var description: String { rawValue }
}
