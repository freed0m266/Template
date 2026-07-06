# Tuist environments (Testing / Production) — default `.testing`, env-var switched at `tuist generate`

A single hardcoded bundle ID means everyday `tuist generate && Run` in Xcode installs a build **with
the exact bundle ID that will ship to the App Store**. Once the app is live, that dev build shares its
identity — and, for any app with an App Group / keychain group, its shared data — with the production
install a real user (or you) has on the device. The safest moment to separate the two is *before* the
first submission, when no user has been promised any bundle ID.

Decision: an `Environment` enum in `ProjectDescriptionHelpers` with cases `testing` and `production`,
resolved at **`tuist generate`** time from the env-var **`TUIST_ENVIRONMENT`**, with a **default of
`.testing`**. One environment is baked into each generated project; to switch, regenerate. Every
identifier that must differ between the two builds — bundle ID, home-screen display name, app icon
asset, and the Swift compilation conditions (`TEST` / `PROD`) — is derived from `AppSetup.current` and
takes a `.test` suffix in testing. Daily `tuist generate && Run` therefore installs `Template TEST`
(`…​.test` bundle ID, recolored `AppIcon-test`) *alongside* a production build without overwriting it.

The template ships the **slim** form of `AppSetup` (no App Group / keychain group — the app has no
extension). When a project adds a data-sharing extension, extend `AppSetup` with the corresponding
`.test`-suffixed identifiers and wire the entitlements there.

## Operational contract (the reason this is worth an ADR)

**Any `xcodebuild archive` (or fastlane lane) that produces a build destined for App Store Connect MUST
run `TUIST_ENVIRONMENT=Production tuist generate` first.** Without that prefix, `tuist generate` picks
the `.testing` default, the workspace bakes in `.test` bundle IDs, and archiving it produces a `.test`
build that will fail App Store Connect validation (or, worse, ship a labelled TEST build). The
`default: .testing` choice deliberately puts this one-time safety burden on the rarely-taken release
path, so that daily development can never *silently* touch production identity.

`ProjectDescription.Environment.environment.getString(...)` resolves at manifest evaluation, not at
`xcodebuild` time — the whole generated project is baked with one environment. Setting the env-var only
at `xcodebuild` time changes nothing. An unset or misspelled value (`TUIST_ENVIRONMENT=Prod`) falls
back to `.testing`, so a typo degrades safely rather than silently producing a production build.

## Considered alternatives

- **Default `.production`.** Attractive: `tuist generate && archive` ships with zero ceremony. Rejected:
  it also means every casual `tuist generate && Run` overwrites the production install — the exact
  accident this exists to prevent. The safeguard belongs on the release path, not the daily path.
- **Two schemes × four configurations** (`Debug-Test` / `Release-Test` / `Debug-Prod` / `Release-Prod`).
  Rejected: doubles the configuration surface for a two-environment split; `Debug`/`Release` is a
  legitimately orthogonal axis and folding environment into it forces spurious combinatorics.
- **Runtime environment (single build, branch on a debug flag).** Rejected: bundle ID (and any App Group
  / keychain group) must be baked into `Info.plist` / entitlements at build time — side-by-side install
  requires build-time separation, not a runtime branch.

## Consequences

- Signing (`DEVELOPMENT_TEAM`, `CODE_SIGN_STYLE`, …) and the Swift compilation conditions move out of
  `Project.swift`'s `base` settings into `AppSetup.projectConfigurations`.
- The template's `TeamID.placeholder` is empty — a fresh project has `DEVELOPMENT_TEAM = ""` and
  configures automatic signing when you fill it in.
- The `TEST` / `PROD` compilation conditions are injected project-wide but have **no runtime consumer**
  in the bare template — the environment axis is proven by the differing display name and icon. Add a
  runtime accessor (or inline `#if TEST`) the first time code genuinely needs to branch.
- Daily development installs a second app (`Template TEST`) on the device next to any production build.
