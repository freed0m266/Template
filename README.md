# Template

iOS app template with a modular SwiftUI architecture, managed with Tuist.

## Quick start

After cloning, bootstrap a fresh project in one command:

```bash
./setup.sh MyProjectName
```

This will:

1. Rename `Template` → `MyProjectName` across files, directories, and the project root.
2. Run `tuist install` and `tuist generate`.
3. Remove bootstrap artefacts (the rename script, the template's `.git`, and `setup.sh` itself).

Once it finishes, initialize fresh source control:

```bash
cd ../MyProjectName
git init && git add . && git commit -m "🎉 Create a project"
open MyProjectName.xcworkspace
```

`ProjectName` must start with a letter and contain only letters and digits (e.g. `Keybo`, `WidgetCoin`).

## Requirements

- Xcode 26+
- iOS 26+
- [Tuist](https://tuist.io) — project generation
- [Mint](https://github.com/yonaskolb/Mint) — SwiftLint via build phase
- [Codex CLI](https://github.com/openai/codex) (optional) — used by the `/task` Claude command for closing code review

```bash
# Install Tuist if you don't have it
curl -Ls https://install.tuist.io | bash

# Install build tools (SwiftLint)
mint bootstrap
```

## Project Structure

```
Template/
├── Template/                       # Main app target (entry point + ContentView)
│   ├── Sources/
│   │   ├── App/                    # @main + AppDelegate (logger setup)
│   │   └── Views/                  # ContentView (top-level screen)
│   └── Resources/                  # Asset catalog
├── TemplateCore/                   # Shared framework (DI, models, services)
│   └── Sources/
│       ├── Dependencies/           # AppDependency container
│       ├── Extensions/             # Foundation extensions
│       ├── Services/               # NetworkService and friends
│       └── Shared/                 # BaseViewModel, Logger
├── TemplateUI/                     # Design system (View+Extensions, Icon)
├── TemplateResources/              # Localization (L10n alias)
├── TemplateTesting/                # AssertSnapshot helper
├── Features/                       # Independent feature frameworks
│   └── Example/
│       ├── Sources/                # View, ViewModel, Dependencies
│       ├── Testing/                # Mock ViewModel (DEBUG)
│       └── Tests/                  # Snapshot tests
├── tasks/                          # Implementation roadmap (numbered task specs)
├── scripts/                        # Helper scripts
│   └── new_feature.sh              # Scaffold a new Features/<Name>/ from Example
├── setup.sh                        # One-shot bootstrap (deletes itself after running)
└── Tuist/                          # Build system configuration
    └── ProjectDescriptionHelpers/
```

## Architecture

The template follows **MVVM** with **UseCases** and a **Repository** layer:

```
View → ViewModel → UseCase → Repository → Service (API)
```

- Every ViewModel, UseCase, Repository, and Service is backed by a protocol
- Dependencies are injected via a global `AppDependency` container
- Each feature defines its own `*Dependencies` struct + `AppDependency` extension
- Views are generic over their ViewModel protocols

## Adding a Feature

Use the feature generator script:

```bash
./scripts/new_feature.sh FeatureName
tuist generate
```

## Tasks and the `/task` command

`tasks/` holds numbered task specs (see [`tasks/README.md`](tasks/README.md) for the convention).

`.claude/commands/task.md` defines a Claude slash command for working through a numbered task:

- **`/task <number>`** — pick up the task, branch off `main`, implement it, run Codex code review on the staged diff, then mark it Done.
- **`/task <number> --skip-review`** — same as above but skips the Codex review step. Use for purely mechanical scaffolding tasks where review wouldn't catch anything substantive.

## Dependencies

- [SwiftyBeaver](https://github.com/SwiftyBeaver/SwiftyBeaver) — Logging
- [BaseKitX](https://github.com/freed0m266/BaseKitX) — Foundation utilities
- [ACKategories](https://github.com/AckeeCZ/ACKategories) — Common helpers
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) — Snapshot tests
