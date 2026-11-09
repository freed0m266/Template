# Template

<!-- template-description -->
iOS app template with a modular SwiftUI architecture, managed with Tuist. Clone it, run `./setup.sh
<ProjectName>`, and you have a signed-and-generatable modular app skeleton to build a real product on.

This file is the whole project guide. It is loaded into every session automatically — do not re-read
it, and do not go looking for a second guide. `AGENTS.md` is a symlink to this file so Codex reads the
same text.

<!-- template-only:start -->
## Writing Docs In This Repo

Everything here is inherited verbatim by every project generated from it, so prose has to survive
`setup.sh`. Two rules:

- **Never write "the template" in a sentence that should survive.** `rename_project.sh` leaves the
  English word alone (it only rewrites dotted/slashed identifiers like `com.acme.template`), so such a
  sentence reaches the new project claiming the project is a template. Write rename-neutral prose
  instead — "the project follows MVVM", not "the template follows MVVM". Referring to the *feature*
  template under `scripts/templates/` is fine: it still exists after bootstrap.
- **Wrap bootstrap-only passages in markers.** `scripts/finalize_docs.sh` strips them once the rename
  is done, so nothing describing `setup.sh` or the clone step is left behind. Two HTML comments, both
  invisible in rendered Markdown — see the raw source of this very section for the exact spelling:
  - `template-only:start` … `template-only:end` — the block and its markers are deleted, along with
    any blank lines trailing it. Use it for whole sections, like README's "Quick start".
  - `template-description` — the marker and the paragraph *directly below it, up to the first blank
    line*, become a one-line TODO naming the new project. Text after that blank line survives.
    `README.md` and this file each carry one.

`setup.sh` prints every surviving mention of "template" at the end of a bootstrap, so a missed one
shows up while there is still someone watching.

Both bootstrap scripts read `ROOT_DIR` from their own location, and `setup.sh` moves them to the repo
root before running them — that is why they operate on the whole project and not on `scripts/`.
Their `find` uses `-type f`, so a symlinked `AGENTS.md` is skipped rather than replaced by a regular
file: the rename and finalize passes reach this file's content exactly once.
<!-- template-only:end -->

## When to read what

Everything else is read on demand. Each trigger below is an observable event, not a topic:

| Trigger | Read |
| --- | --- |
| About to deviate from a rule below, or a rule here looks arbitrary | [docs/adr/](docs/adr/) — the *why* behind non-obvious decisions |
| The user names a task number without invoking `/task` | `tasks/<NN>-*.md` — Scope and Mimo scope are binding |

Never trust a directory listing written in prose — including in `README.md`. Run `ls`.

## Where code goes

- `Template` — `@main`, `AppDelegate` (logger setup), top-level views. The only place a route maps to
  a view.
- `TemplateCore` — `AppDependency`, `BaseViewModel`, `Logger`, Foundation extensions, `NetworkService`.
  Anything two features would otherwise duplicate.
- `TemplateUI` — the design system. A reusable visual component belongs here, never in a feature.
- `TemplateResources` — `Localizable.strings` and the generated `L10n` alias.
- `TemplateTesting` — `AssertSnapshot` and other test helpers.
- `Features/<Name>` — one screen's worth of feature framework. Features never import each other.

## Build and generation

Regenerate the Xcode project after target, resource, or package changes:

```bash
tuist generate
```

Two Tuist environments select the bundle ID, home-screen display name, and app icon. The default is
`Testing` — a sandboxed `.test` build (`Template TEST`, recolored `AppIcon-test`) that installs
alongside a production build. **A production archive MUST regenerate with the env-var first:**

```bash
TUIST_ENVIRONMENT=Production tuist generate
```

Without that prefix, `tuist generate` bakes `.test` identifiers into the workspace and any archive from
it is a TEST build. The environment resolves at generate time, not at `xcodebuild` time. See
[ADR 0001](docs/adr/0001-tuist-environments-default-testing.md).

Build the app:

```bash
xcodebuild -workspace Template.xcworkspace -scheme Template -destination 'generic/platform=iOS Simulator' build
```

Run focused test schemes through the **workspace**, not the project — the `.xcodeproj` alone does not
link the SPM package projects (SwiftyBeaver, SnapshotTesting), so a `-project` run fails with
`Unable to find module dependency`:

```bash
xcodebuild test -workspace Template.xcworkspace -scheme <Feature>_Tests -destination 'platform=iOS Simulator,name=<available iPhone>'
```

SwiftLint runs through a build phase via Mint. Keep code lint-clean instead of bypassing it.

## Architecture

```
View → ViewModel → UseCase → Repository → Service (API)
```

- Every ViewModel, UseCase, Repository, and Service is backed by a protocol (protocol-first).
- Protocols are named `<Name>...ing` — `ExampleViewModeling`, `ExampleUseCasing`.
- Dependencies are injected via the global `AppDependency` container
  (`nonisolated(unsafe) let dependencies`).
- Shared framework types are `public`; implementations stay `internal` unless a public surface is
  required.
- Prefer small, explicit types over broad abstractions. Add a protocol where the architecture needs
  testability or a module boundary, not as decoration.

## Dependency wiring

Every UseCase gets a factory method on `AppDependency`, declared in the feature's own
`<Feature>Dependencies.swift` (a feature's `*UseCasing` protocol is `internal`, so it cannot live in
the core framework). The `var <feature>: <Feature>Dependencies` computed property then wires everything
as a **flat list of factory calls** — never an inline
`ExampleUseCase(repository:calculator:)` construction inside the `.init(...)`. One shape at every
wiring site.

## Feature pattern

```text
Features/<Name>/
  Sources/
    <Name>View.swift
    <Name>ViewModel.swift
    <Name>Dependencies.swift   # only when the feature has real dependencies
  Testing/
    <Name>ViewModelMock.swift
  Tests/
    <Name>Snapshots.swift
```

- `@MainActor public protocol <Name>ViewModeling: Observable`.
- Concrete view models use `@Observable`, inherit `BaseViewModel`, and are `internal` unless a public
  surface is required.
- Views are generic over the protocol: `struct FeatureView<ViewModel: FeatureViewModeling>: View`.
- Views hold state with `@State private var viewModel`; use `@Bindable` when bindings are needed.
- Factory functions are public and main-actor isolated: `public func featureVM() -> some FeatureViewModeling`.
- Mocks live in `Features/<Name>/Testing/`, wrapped in `#if DEBUG`, and power previews and snapshots.
- UseCase entry points are always `execute(...)`.

Scaffold a new feature with `./scripts/new_feature.sh FeatureName` — it copies the isolated
`scripts/templates/Feature` template — then run `tuist generate`.

## Views

- **A screen view's `init` takes the view model and nothing else.** No closure parameters
  (`onSelect:`, `onCreate:`) — navigation and actions are view-model methods, even when the body is
  still a `// TODO`. A closure in an init is a sign logic leaked into the view.
- Follow the existing tab-indented Swift style and `// MARK: -` organization.
- Keep comments concise — explain non-obvious decisions, not the obvious.

## Localization

Route user-facing host-app text through `L10n` rather than inline string literals.

## Tests and snapshots

- Pure logic change → add or update the target's unit tests. UI change → add or update the matching
  `Features/<Name>/Tests/*Snapshots.swift`. `AssertSnapshot` is the generic helper.
- Do not link `SnapshotTesting` directly from a test target — `TemplateTesting` already links it, and
  linking a static product twice makes `tuist generate` warn.
- Do not silently accept snapshot churn. Verify the visual change matches the task before recording.
  `scripts/delete_snapshot_references.sh` deletes all reference PNGs to force a clean re-record.

## Maintaining this file

**Two different agents read this file.** Claude Code loads it as `CLAUDE.md`; Codex loads the same
bytes as `AGENTS.md`, which is a symlink to it. Editing rules follow from that:

- Keep instructions agent-neutral. Do not phrase a rule around one agent's tools. Naming a Claude
  slash command is fine — say it is Claude-side and name the Codex counterpart.
- **Never let `AGENTS.md` become a regular file again.** `sed -i`, `perl -i`, and `>` redirection all
  replace a symlink with a copy; edit `CLAUDE.md` instead. If `ls -l AGENTS.md` stops printing
  `-> CLAUDE.md`, the two have silently diverged and the drift is back.
- When a new project convention is decided, write it **here** — not into memory, not into `README.md`.
- **Keep project-level overrides to a minimum.** Do not restate a slash command's own steps here, and
  do not add rules that already hold everywhere. A `## Task workflow` section is warranted only when the
  project genuinely departs from the task command's defaults — a different base branch, an extra gate.
- Normative statements only: never add directory trees, file listings, or "what currently exists"
  summaries. Those drift silently and then lie.
