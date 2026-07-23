# Template

<!-- template-description -->
iOS app template with a modular SwiftUI architecture, managed with Tuist.

<!-- template-only:start -->
## Quick start

After cloning, bootstrap a fresh project in one command:

```bash
./setup.sh MyProjectName
```

This will:

1. Rename `Template` → `MyProjectName` across files, directories, and the project root.
2. Strip the template-only sections out of the docs (see `scripts/finalize_docs.sh`).
3. Run `tuist install` and `tuist generate`.
4. Remove bootstrap artefacts (the rename and doc-finalize scripts, the template's `.git`, and
   `setup.sh` itself).

Once it finishes, initialize fresh source control:

```bash
cd ../MyProjectName
git init && git add . && git commit -m "🎉 Create a project"
open MyProjectName.xcworkspace
```

`ProjectName` must start with a letter and contain only letters and digits (e.g. `Keybo`, `WidgetCoin`).
<!-- template-only:end -->

## Environments

Two Tuist environments select the bundle ID, home-screen display name, and app icon. They are resolved
at `tuist generate` time from the `TUIST_ENVIRONMENT` env-var:

- **Testing** (default) — a sandboxed `.test` build: `Template TEST` on the home screen, a recolored
  `AppIcon-test`, and a `.test`-suffixed bundle ID, so it installs *alongside* a production build.
  Everyday `tuist generate && Run` gives you this.
- **Production** — the shippable identifiers. **A production archive MUST regenerate with the env-var:**

  ```bash
  TUIST_ENVIRONMENT=Production tuist generate
  ```

  Without it, the workspace bakes in `.test` identifiers and any archive from it is a TEST build. See
  [ADR 0001](docs/adr/0001-tuist-environments-default-testing.md). The Apple team ID is a placeholder
  (`TeamID.placeholder`) — set it in `Tuist/ProjectDescriptionHelpers/TeamID.swift` for a real project.

## Requirements

- Xcode 26+
- iOS 26+
- [Tuist](https://tuist.io) — project generation
- [Mint](https://github.com/yonaskolb/Mint) — SwiftLint via build phase
- [Codex CLI](https://github.com/openai/codex) — the `/task` closing review runs `codex review --uncommitted` on the staged diff

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
├── tasks/                          # Implementation roadmap (numbered task specs) + dashboard
├── docs/adr/                       # Architecture Decision Records
├── scripts/                        # Helper scripts
│   ├── new_feature.sh              # Scaffold a new Features/<Name>/ from the feature template
│   ├── generate_dashboard.py       # Render a Kanban board of the task files
│   ├── clean_worktrees.sh          # Remove stale Claude Code worktrees
│   └── delete_snapshot_references.sh  # Delete snapshot reference PNGs (force re-record)
└── Tuist/                          # Build system configuration
    └── ProjectDescriptionHelpers/
        ├── Environment/            # Testing/Production env system (AppSetup, Environment)
        └── Targets/                # Per-target factories
```

## Architecture

The project follows **MVVM** with **UseCases** and a **Repository** layer:

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

`.claude/commands/task.md` defines a Claude slash command for working through a numbered task, mirrored
for Codex in `.codex/skills/task/SKILL.md`. The closing review is **cross-model**: driven from Claude it
runs Codex (`codex review --uncommitted`); driven from Codex it runs Claude (`claude -p`) — the reviewer
is always the other model.

- **`/task <number>`** — pick up the task, branch off `main`, implement it, run the closing review on the staged diff, then mark it Done.
- **`/task <number> --skip-review`** — same as above but skips the review step. Use for purely mechanical scaffolding tasks where review wouldn't catch anything substantive.

Run `python3 scripts/generate_dashboard.py` for a Kanban board of the task files (`--serve` for a live
board with drag-and-drop status changes written back into the `.md` files).

## Dependencies

- [SwiftyBeaver](https://github.com/SwiftyBeaver/SwiftyBeaver) — Logging
- [BaseKitX](https://github.com/freed0m266/BaseKitX) — Foundation utilities
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing) — Snapshot tests
