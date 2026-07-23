# Template

<!-- template-description -->
iOS app template with a modular SwiftUI architecture, managed with Tuist. Clone it, run `./setup.sh
<ProjectName>`, and you have a signed-and-generatable modular app skeleton to build a real product on.

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
  - `template-description` — the marker and the paragraph below it become a one-line TODO naming the
    new project. Each of README / AGENTS / CLAUDE carries one.

`setup.sh` prints every surviving mention of "template" at the end of a bootstrap, so a missed one
shows up while there is still someone watching.
<!-- template-only:end -->

## Important Files

- `README.md` — high-level overview and project structure.
- `tasks/README.md` and numbered `tasks/*.md` — the roadmap and scope source of truth.
- `Project.swift` and `Tuist/ProjectDescriptionHelpers/Targets/**` — define the generated targets.
- `Tuist/ProjectDescriptionHelpers/Environment/**` — the build-environment system (see Build below).
- `docs/adr/**` — architecture decision records (why non-obvious choices were made).

## Targets

- `Template`: host app. `@main` entry point, `AppDelegate` (logger setup), and top-level views.
- `TemplateCore`: shared framework — `AppDependency` (DI container), `BaseViewModel`, `Logger`,
  Foundation extensions, services.
- `TemplateUI`: design system — `Icon`, view extensions, reusable components.
- `TemplateResources`: localized strings and the generated `L10n` alias.
- `TemplateTesting`: snapshot helpers (`AssertSnapshot`).
- `Features/*`: independent feature frameworks.

## Build And Generation

- Regenerate the Xcode project after target/resource/package changes:

```bash
tuist generate
```

- **Two Tuist environments** select the bundle ID, home-screen display name, and app icon. The default
  is `Testing` — a sandboxed `.test` build (`Template TEST`, recolored `AppIcon-test`) that installs
  alongside a production build. **A production archive MUST regenerate with the env-var first:**

```bash
TUIST_ENVIRONMENT=Production tuist generate
```

  Without that prefix, `tuist generate` bakes `.test` identifiers into the workspace and any archive
  from it is a TEST build. The environment is resolved at generate time, not at `xcodebuild` time.
  See [ADR 0001](docs/adr/0001-tuist-environments-default-testing.md).

- Build the app:

```bash
xcodebuild -workspace Template.xcworkspace -scheme Template -destination 'generic/platform=iOS Simulator' build
```

- Run focused test schemes when touching a target, using an installed iPhone simulator:

```bash
xcodebuild test -project Template.xcodeproj -scheme <Feature>_Tests -destination 'platform=iOS Simulator,name=<available iPhone>'
```

- SwiftLint runs through a build phase via Mint. Keep code lint-clean instead of bypassing it.

## Architecture

MVVM with UseCases and a Repository layer:

```
View → ViewModel → UseCase → Repository → Service (API)
```

- Every ViewModel, UseCase, Repository, and Service is backed by a protocol (protocol-first).
- Dependencies are injected via the global `AppDependency` container
  (`nonisolated(unsafe) let dependencies`).
- Each feature defines its own `*Dependencies` struct + an `AppDependency` extension providing them.
- Views are generic over their ViewModel protocol.

## Feature Pattern

Feature modules follow MVVM with protocol-first view models:

- `@MainActor public protocol <Name>ViewModeling: Observable`.
- Concrete view models use `@Observable`, inherit `BaseViewModel`, and are `internal` unless a public
  surface is required.
- Views are generic over the protocol, e.g. `struct FeatureView<ViewModel: FeatureViewModeling>: View`.
- Views hold state with `@State private var viewModel`; use `@Bindable` when bindings are needed.
- Factory functions are public and main-actor isolated, e.g. `public func featureVM() -> some FeatureViewModeling`.
- Mocks live in `Features/<Name>/Testing/`, wrapped in `#if DEBUG`, and power previews/snapshots.

Preferred layout:

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

Use `./scripts/new_feature.sh FeatureName` to scaffold a new feature from the isolated
`scripts/templates/Feature` template, then run
`tuist generate`.

## Swift Style

- Follow the existing tab-indented Swift style and `// MARK: -` organization.
- Prefer small, explicit types over broad abstractions. Add protocols where the architecture needs
  testability or module boundaries, not as decoration.
- Public APIs are for cross-target use. Keep implementations `internal` by default.
- Mark view-model protocols and implementations `@MainActor`.
- Use `execute(...)` for UseCase entry points.
- Prefer localized strings through `L10n` for user-facing host-app text.
- Keep comments concise and useful — explain non-obvious decisions, not the obvious.

## Tests And Snapshots

- For pure logic changes, add or update the target's unit tests.
- For UI changes, add/update the matching `Features/<Name>/Tests/*Snapshots.swift`.
- `TemplateTesting/AssertSnapshot` is the generic snapshot helper.
- Do not silently accept snapshot churn. Verify the visual change matches the task before recording.
- `scripts/delete_snapshot_references.sh` deletes all reference PNGs (to force a clean re-record).

## Task Workflow

- Numbered task files in `tasks/` define scope, non-goals, done criteria, risks, and references.
  Treat them as binding when implementing a task.
- If a task says something is out of scope, do not implement it opportunistically.
- `/task <number>` (see `.claude/commands/task.md`, mirrored for Codex in `.codex/skills/task/`)
  picks up a task, branches off `main`, implements it, runs a cross-model closing review on the
  staged diff (Codex when driven from Claude; Claude when driven from Codex), then marks the task
  Done. Pass `--skip-review` for mechanical scaffolding.
- `python3 scripts/generate_dashboard.py` renders a Kanban board of the task files.

## Git Hygiene

- The worktree may contain user changes. Never revert unrelated edits.
- Keep commits grouped by intent. Prefer short gitmoji-prefixed subjects.
- Do not commit unless the user explicitly asks.
- `scripts/clean_worktrees.sh` removes stale Claude Code worktrees under `.claude/worktrees/`.
